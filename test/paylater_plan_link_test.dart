import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/utils/paylater.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// Paylater plan linking: every plan is backed by its purchase expense,
/// installment payments carry the plan id, deleting a plan removes its
/// transactions and restores balances, and repayments are countable
/// separately from spending.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
  });

  tearDown(() => db.close());

  Future<int> makeWallet(String name, String kind) => db.createWallet(
    accountId: 1,
    name: name,
    kind: kind,
  );

  Future<int> foodId() async {
    final cats = await db.select(db.categories).get();
    return cats.firstWhere((c) => c.name == 'Food').id;
  }

  Future<Wallet> getWallet(int id) => db.getWalletById(id).then((w) => w!);

  Future<Transaction> getTx(int id) =>
      (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();

  group('addPlanWithPurchase', () {
    test('creates the plan and its purchase expense, wallet owes total',
        () async {
      final paylaterId = await makeWallet('Shopeepaylater', 'paylater');
      final planId = await db.addPlanWithPurchase(
        walletId: paylaterId,
        name: 'Iphone',
        totalAmount: 15000000,
        installmentAmount: 5000000,
        totalCount: 3,
        categoryId: await foodId(),
      );

      final plan = await (db.select(db.installmentPlans)
            ..where((p) => p.id.equals(planId)))
          .getSingle();
      expect(plan.name, 'Iphone');
      expect(plan.totalAmount, 15000000);

      final linked = await db.planTransactions(planId);
      expect(linked, hasLength(1));
      expect(linked.first.kind, 'expense');
      expect(linked.first.amount, 15000000);
      expect(linked.first.note, 'Iphone');

      // The purchase is what makes the plan visible to every figure.
      expect((await getWallet(paylaterId)).balance, -15000000);
      expect(paylaterOutstanding(await getWallet(paylaterId)), 15000000);
    });
  });

  group('installment payment linking', () {
    test('transfer carries planId and shows in plan history', () async {
      final paylaterId = await makeWallet('Shopeepaylater', 'paylater');
      final payerId = await makeWallet('Jago', 'bank');
      final planId = await db.addPlanWithPurchase(
        walletId: paylaterId,
        name: 'Iphone',
        totalAmount: 15000000,
        installmentAmount: 5000000,
        totalCount: 3,
        categoryId: await foodId(),
      );

      final txId = await db.addTransfer(
        fromWalletId: payerId,
        toWalletId: paylaterId,
        amount: 5000000,
        note: 'Installment payment: Iphone',
        planId: planId,
      );
      await db.markInstallmentPaid(planId);

      expect((await getTx(txId)).planId, planId);
      final history = await db.planTransactions(planId);
      expect(history, hasLength(2));
      expect(history.map((t) => t.kind), containsAll(['expense', 'transfer']));
      // One payment down: owed drops by exactly the payment.
      expect((await getWallet(paylaterId)).balance, -10000000);
    });

    test('setTransactionPlan links an existing transaction', () async {
      final paylaterId = await makeWallet('Shopeepaylater', 'paylater');
      final planId = await db.addInstallmentPlan(
        walletId: paylaterId,
        name: 'Manual',
        totalAmount: 900000,
        installmentAmount: 300000,
        totalCount: 3,
      );
      final txId = await db.addTransaction(
        TransactionsCompanion.insert(
          walletId: paylaterId,
          categoryId: await foodId(),
          kind: 'expense',
          amount: 900000,
          note: const Value('Manual'),
          date: DateTime.now(),
        ),
      );
      expect((await getTx(txId)).planId, isNull);
      await db.setTransactionPlan(txId, planId);
      expect((await getTx(txId)).planId, planId);
      expect(await db.planTransactions(planId), hasLength(1));
    });
  });

  group('deleteInstallmentPlan cascade', () {
    test('removes purchase + payments and restores both balances',
        () async {
      final paylaterId = await makeWallet('Shopeepaylater', 'paylater');
      final payerId = await makeWallet('Jago', 'bank');
      // Seed the payer so its balance has something to restore to.
      await db.addTransaction(
        TransactionsCompanion.insert(
          walletId: payerId,
          categoryId: await foodId(),
          kind: 'income',
          amount: 20000000,
          note: const Value('Salary'),
          date: DateTime.now(),
        ),
      );
      final planId = await db.addPlanWithPurchase(
        walletId: paylaterId,
        name: 'Iphone',
        totalAmount: 15000000,
        installmentAmount: 5000000,
        totalCount: 3,
        categoryId: await foodId(),
      );
      await db.addTransfer(
        fromWalletId: payerId,
        toWalletId: paylaterId,
        amount: 5000000,
        note: 'Installment payment: Iphone',
        planId: planId,
      );
      await db.addTransfer(
        fromWalletId: payerId,
        toWalletId: paylaterId,
        amount: 5000000,
        note: 'Installment payment: Iphone',
        planId: planId,
      );
      expect((await getWallet(payerId)).balance, 10000000);
      expect((await getWallet(paylaterId)).balance, -5000000);

      await db.deleteInstallmentPlan(planId);

      expect(await db.planTransactions(planId), isEmpty);
      final plans = await db.select(db.installmentPlans).get();
      expect(plans.where((p) => p.id == planId), isEmpty);
      // Both wallets back to their pre-plan state.
      expect((await getWallet(payerId)).balance, 20000000);
      expect((await getWallet(paylaterId)).balance, 0);
    });

    test('plan with no linked transactions just deletes', () async {
      final paylaterId = await makeWallet('Shopeepaylater', 'paylater');
      final planId = await db.addInstallmentPlan(
        walletId: paylaterId,
        name: 'Legacy',
        totalAmount: 900000,
        installmentAmount: 300000,
        totalCount: 3,
      );
      await db.deleteInstallmentPlan(planId);
      expect(await db.select(db.installmentPlans).get(), isEmpty);
    });
  });

  group('paylaterRepayments', () {
    test('sums only transfers into paylater wallets', () async {
      final paylaterId = await makeWallet('Shopeepaylater', 'paylater');
      final otherPaylaterId = await makeWallet('Kredivo', 'paylater');
      final payerId = await makeWallet('Jago', 'bank');
      final txs = <Transaction>[
        Transaction(
          id: 1,
          walletId: payerId,
          categoryId: 1,
          kind: 'transfer',
          amount: 5000000,
          note: 'Installment payment',
          memo: '',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          toWalletId: paylaterId,
        ),
        Transaction(
          id: 2,
          walletId: payerId,
          categoryId: 1,
          kind: 'transfer',
          amount: 2000000,
          note: 'Installment payment',
          memo: '',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          toWalletId: otherPaylaterId,
        ),
        // Transfer between two non-paylater wallets: not a repayment.
        Transaction(
          id: 3,
          walletId: payerId,
          categoryId: 1,
          kind: 'transfer',
          amount: 1000000,
          note: 'Move',
          memo: '',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          toWalletId: payerId,
        ),
        // A purchase on the paylater wallet is spending, not repayment.
        Transaction(
          id: 4,
          walletId: paylaterId,
          categoryId: 1,
          kind: 'expense',
          amount: 15000000,
          note: 'Iphone',
          memo: '',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      ];
      expect(
        paylaterRepayments(txs, {paylaterId, otherPaylaterId}),
        7000000,
      );
    });
  });

  group('singlePayablePlan', () {
    InstallmentPlan plan({
      required int id,
      required int walletId,
      required int total,
      required int monthly,
      required int count,
      required int paid,
    }) =>
        InstallmentPlan(
          id: id,
          walletId: walletId,
          name: 'Plan $id',
          totalAmount: total,
          installmentAmount: monthly,
          totalCount: count,
          paidCount: paid,
          createdAt: DateTime.now(),
        );

    test('single plan with money left → returned', () {
      final p = plan(
        id: 1,
        walletId: 7,
        total: 18000000,
        monthly: 6000000,
        count: 3,
        paid: 0,
      );
      expect(singlePayablePlan([p], 7)?.id, 1);
    });

    test('two plans on the wallet → null (no attribution)', () {
      final plans = [
        plan(id: 1, walletId: 7, total: 9000000, monthly: 3000000, count: 3, paid: 0),
        plan(id: 2, walletId: 7, total: 6000000, monthly: 3000000, count: 2, paid: 0),
      ];
      expect(singlePayablePlan(plans, 7), isNull);
    });

    test('plans on other wallets are ignored', () {
      final plans = [
        plan(id: 1, walletId: 7, total: 18000000, monthly: 6000000, count: 3, paid: 1),
        plan(id: 2, walletId: 9, total: 6000000, monthly: 3000000, count: 2, paid: 0),
      ];
      expect(singlePayablePlan(plans, 7)?.id, 1);
    });

    test('complete plan → null', () {
      final p = plan(
        id: 1,
        walletId: 7,
        total: 9000000,
        monthly: 3000000,
        count: 3,
        paid: 3,
      );
      expect(singlePayablePlan([p], 7), isNull);
    });

    test('rounding leftover with nothing left → null', () {
      // 2 × 50000 already covers the 100000 total; the counter has one
      // installment left but there is no money left to pay.
      final p = plan(
        id: 1,
        walletId: 7,
        total: 100000,
        monthly: 50000,
        count: 3,
        paid: 2,
      );
      expect(singlePayablePlan([p], 7), isNull);
    });

    test('last installment capped by remaining still counts', () {
      final p = plan(
        id: 1,
        walletId: 7,
        total: 100000,
        monthly: 40000,
        count: 3,
        paid: 2,
      );
      expect(installmentDueAmount(p), 20000);
      expect(singlePayablePlan([p], 7)?.id, 1);
    });
  });
}
