import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/utils/paylater.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// Plan <-> transaction linkage: deleting or editing a plan's purchase
/// must move the plan with it, and deleting a payment must move the
/// paid counter. Before this fix, deleting a purchase left a payable
/// zombie plan, editing left the plan stale, and deleting a payment
/// left paidCount claiming money that was no longer paid.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
  });

  tearDown(() => db.close());

  Future<int> makeWallet(String name, String kind) =>
      db.createWallet(accountId: 1, name: name, kind: kind);

  Future<int> foodId() async {
    final cats = await db.select(db.categories).get();
    return cats.firstWhere((c) => c.name == 'Food').id;
  }

  Future<int> paylaterWallet() => makeWallet('Paylater', 'paylater');

  Future<int> fundedWallet() async {
    final id = await makeWallet('Bank', 'bank');
    await db.addTransaction(
      TransactionsCompanion.insert(
        walletId: id,
        categoryId: await foodId(),
        kind: 'income',
        amount: 5000000,
        note: const Value('Seed'),
        date: DateTime(2026, 11, 1),
      ),
    );
    return id;
  }

  Future<int> makePlanWithCategory(int walletId) async =>
      db.addPlanWithPurchase(
        walletId: walletId,
        name: 'Phone',
        totalAmount: 1200000,
        installmentAmount: 400000,
        totalCount: 3,
        categoryId: await foodId(),
      );

  Future<Transaction> purchaseOf(int planId) async {
    final linked = await db.planTransactions(planId);
    return linked.firstWhere((t) => t.kind == 'expense');
  }

  Future<List<Transaction>> paymentsOf(int planId) async {
    final linked = await db.planTransactions(planId);
    return linked.where((t) => t.kind == 'transfer').toList();
  }

  Future<int> payOnce(int planId, int fromWallet, int toWallet) async {
    final id = await db.addTransfer(
      fromWalletId: fromWallet,
      toWalletId: toWallet,
      amount: 400000,
      note: 'Installment payment: Phone',
      planId: planId,
    );
    await db.markInstallmentPaid(planId);
    return id;
  }

  Future<int> walletBalance(int id) async =>
      (await db.getWalletById(id))!.balance;

  test('deleting an unpaid plan purchase removes the plan too', () async {
    final walletId = await paylaterWallet();
    final planId = await makePlanWithCategory(walletId);
    final purchase = await purchaseOf(planId);
    expect(await walletBalance(walletId), -1200000);

    final deleted = await db.deleteTransaction(purchase.id);

    expect(deleted, isNotNull);
    expect(deleted!.id, planId);
    expect(await db.getInstallmentPlan(planId), isNull);
    expect(await walletBalance(walletId), 0);
    expect(
      (await db.planTransactions(planId)).isEmpty,
      isTrue,
    );
  });

  test('deleting a paid plan purchase is refused', () async {
    final walletId = await paylaterWallet();
    final fundingId = await fundedWallet();
    final planId = await makePlanWithCategory(walletId);
    await payOnce(planId, fundingId, walletId);
    final purchase = await purchaseOf(planId);
    expect((await db.getInstallmentPlan(planId))!.paidCount, 1);

    await expectLater(db.deleteTransaction(purchase.id), throwsStateError);

    expect(await db.getInstallmentPlan(planId), isNotNull);
    expect((await purchaseOf(planId)).id, purchase.id);
    expect(await walletBalance(walletId), -800000);
  });

  test('deleting a payment re-derives the paid counter', () async {
    final walletId = await paylaterWallet();
    final fundingId = await fundedWallet();
    final planId = await makePlanWithCategory(walletId);
    await payOnce(planId, fundingId, walletId);
    await payOnce(planId, fundingId, walletId);
    expect((await db.getInstallmentPlan(planId))!.paidCount, 2);
    expect(await walletBalance(walletId), -400000);

    final payment = (await paymentsOf(planId)).first;
    await db.deleteTransaction(payment.id);

    expect((await db.getInstallmentPlan(planId))!.paidCount, 1);
    expect(await walletBalance(walletId), -800000);
    expect(await walletBalance(fundingId), 4600000);
  });

  test('restoring a payment restores the paid counter', () async {
    final walletId = await paylaterWallet();
    final fundingId = await fundedWallet();
    final planId = await makePlanWithCategory(walletId);
    await payOnce(planId, fundingId, walletId);
    await payOnce(planId, fundingId, walletId);
    final payment = (await paymentsOf(planId)).first;
    await db.deleteTransaction(payment.id);
    expect((await db.getInstallmentPlan(planId))!.paidCount, 1);

    await db.restoreTransaction(payment, const []);

    expect((await db.getInstallmentPlan(planId))!.paidCount, 2);
    expect(await walletBalance(walletId), -400000);
  });

  test('undo round-trips an unpaid purchase delete with its plan', () async {
    final walletId = await paylaterWallet();
    final planId = await makePlanWithCategory(walletId);
    final purchase = await purchaseOf(planId);
    final deletedPlan = await db.deleteTransaction(purchase.id);
    expect(deletedPlan, isNotNull);

    await db.restoreInstallmentPlan(deletedPlan!);
    await db.restoreTransaction(purchase, const []);

    final restored = await db.getInstallmentPlan(planId);
    expect(restored, isNotNull);
    expect(restored!.totalAmount, 1200000);
    expect(restored.paidCount, 0);
    expect((await purchaseOf(planId)).id, purchase.id);
    expect(await walletBalance(walletId), -1200000);
  });

  test('deleteInstallmentPlan still removes a plan with payments', () async {
    final walletId = await paylaterWallet();
    final fundingId = await fundedWallet();
    final planId = await makePlanWithCategory(walletId);
    await payOnce(planId, fundingId, walletId);
    await payOnce(planId, fundingId, walletId);

    await db.deleteInstallmentPlan(planId);

    expect(await db.getInstallmentPlan(planId), isNull);
    expect((await db.planTransactions(planId)).isEmpty, isTrue);
    expect(await walletBalance(walletId), 0);
    expect(await walletBalance(fundingId), 5000000);
  });

  test('editInstallmentPlan can move a plan to another wallet', () async {
    final walletA = await paylaterWallet();
    final walletB = await makeWallet('Paylater 2', 'paylater');
    final planId = await makePlanWithCategory(walletA);

    await db.editInstallmentPlan(
      planId: planId,
      name: 'Phone',
      totalAmount: 1200000,
      installmentAmount: 400000,
      totalCount: 3,
      createdAt: DateTime(2026, 11, 1),
      walletId: walletB,
    );

    expect((await db.getInstallmentPlan(planId))!.walletId, walletB);
  });

  test('purchase edit composition syncs the plan', () async {
    final walletId = await paylaterWallet();
    final planId = await makePlanWithCategory(walletId);
    final purchase = await purchaseOf(planId);
    // The edit sheet's path: update the row, then sync the plan.
    final newDate = DateTime(2026, 11, 5, 10, 30);
    await db.updateTransaction(
      id: purchase.id,
      walletId: walletId,
      categoryId: purchase.categoryId,
      kind: 'expense',
      amount: 900000,
      note: purchase.note,
      memo: purchase.memo,
      date: newDate,
    );
    await db.editInstallmentPlan(
      planId: planId,
      name: 'Phone',
      totalAmount: 900000,
      installmentAmount: calcTenor(
        principal: 900000,
        tenor: 3,
        monthlyRatePercent: null,
      ).monthlyAmount,
      totalCount: 3,
      createdAt: newDate,
    );

    final plan = (await db.getInstallmentPlan(planId))!;
    expect(plan.totalAmount, 900000);
    expect(plan.installmentAmount, 300000);
    expect(plan.createdAt.day, 5);
    expect((await purchaseOf(planId)).amount, 900000);
    expect(await walletBalance(walletId), -900000);
  });
}
