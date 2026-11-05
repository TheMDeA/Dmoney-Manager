import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dmoney_manager/data/database/app_database.dart';

/// editInstallmentPlan: the total is the linked purchase's amount,
/// so changing it must write through to the purchase expense and the
/// wallet balance; the start date moves the purchase's date too;
/// paidCount is only touched when explicitly provided (the counter
/// repair); a plan with no linked purchase refuses a total change
/// instead of drifting from the ledger.
void main() {
  late AppDatabase db;
  late int walletId;
  late int categoryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    walletId = await db.createWallet(
      accountId: 1,
      name: 'SPayLater',
      kind: 'paylater',
      initialAmount: 0,
    );
    categoryId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'Gadget', kind: 'expense'),
        );
  });
  tearDown(() => db.close());

  Future<InstallmentPlan> getPlan(int id) async =>
      (await db.plansForWallet(walletId)).firstWhere((p) => p.id == id);

  Future<int> balance() async => (await db.getWalletById(walletId))!.balance;

  Future<int> addLinkedPlan() => db.addPlanWithPurchase(
        walletId: walletId,
        name: 'Phone',
        totalAmount: 300000,
        installmentAmount: 100000,
        totalCount: 3,
        categoryId: categoryId,
      );

  test('total change writes through to purchase and balance', () async {
    final planId = await addLinkedPlan();
    expect(await balance(), -300000);
    final plan = await getPlan(planId);
    await db.editInstallmentPlan(
      planId: planId,
      name: 'Phone X',
      totalAmount: 450000,
      installmentAmount: 150000,
      totalCount: 3,
      createdAt: plan.createdAt,
    );
    final after = await getPlan(planId);
    expect(after.name, 'Phone X');
    expect(after.totalAmount, 450000);
    expect(after.installmentAmount, 150000);
    final purchase = (await db.planTransactions(planId))
        .singleWhere((t) => t.kind == 'expense');
    expect(purchase.amount, 450000);
    expect(await balance(), -450000);
  });

  test('start date moves the purchase date too', () async {
    final planId = await addLinkedPlan();
    final plan = await getPlan(planId);
    await db.editInstallmentPlan(
      planId: planId,
      name: 'Phone',
      totalAmount: 300000,
      installmentAmount: 100000,
      totalCount: 3,
      createdAt: DateTime(
          2026, 9, 14, plan.createdAt.hour, plan.createdAt.minute),
    );
    final after = await getPlan(planId);
    expect(
      DateTime(after.createdAt.year, after.createdAt.month,
          after.createdAt.day),
      DateTime(2026, 9, 14),
    );
    final purchase = (await db.planTransactions(planId))
        .singleWhere((t) => t.kind == 'expense');
    expect(
      DateTime(purchase.date.year, purchase.date.month, purchase.date.day),
      DateTime(2026, 9, 14),
    );
  });

  test('paidCount is written only when provided', () async {
    final planId = await addLinkedPlan();
    await db.markInstallmentPaid(planId);
    expect((await getPlan(planId)).paidCount, 1);
    final plan = await getPlan(planId);
    await db.editInstallmentPlan(
      planId: planId,
      name: 'Phone',
      totalAmount: 300000,
      installmentAmount: 100000,
      totalCount: 3,
      createdAt: plan.createdAt,
    );
    expect((await getPlan(planId)).paidCount, 1);
    await db.editInstallmentPlan(
      planId: planId,
      name: 'Phone',
      totalAmount: 300000,
      installmentAmount: 100000,
      totalCount: 3,
      createdAt: plan.createdAt,
      paidCount: 0,
    );
    expect((await getPlan(planId)).paidCount, 0);
  });

  test('unlinked plan: total change throws, other edits fine', () async {
    final planId = await db.addInstallmentPlan(
      walletId: walletId,
      name: 'Old',
      totalAmount: 200000,
      installmentAmount: 100000,
      totalCount: 2,
    );
    final plan = await getPlan(planId);
    await expectLater(
      db.editInstallmentPlan(
        planId: planId,
        name: 'Old',
        totalAmount: 250000,
        installmentAmount: 125000,
        totalCount: 2,
        createdAt: plan.createdAt,
      ),
      throwsA(isA<StateError>()),
    );
    await db.editInstallmentPlan(
      planId: planId,
      name: 'Old renamed',
      totalAmount: 200000,
      installmentAmount: 100000,
      totalCount: 2,
      createdAt: plan.createdAt,
    );
    expect((await getPlan(planId)).name, 'Old renamed');
  });

  test('counter guards reject impossible paid/total combinations',
      () async {
    final planId = await addLinkedPlan();
    await db.markInstallmentPaid(planId);
    await db.markInstallmentPaid(planId);
    final plan = await getPlan(planId);
    expect(plan.paidCount, 2);
    // Shrinking the plan below what is already paid is refused.
    await expectLater(
      db.editInstallmentPlan(
        planId: planId,
        name: 'Phone',
        totalAmount: 300000,
        installmentAmount: 100000,
        totalCount: 1,
        createdAt: plan.createdAt,
      ),
      throwsArgumentError,
    );
    // A counter sync above the plan's count is refused too.
    await expectLater(
      db.editInstallmentPlan(
        planId: planId,
        name: 'Phone',
        totalAmount: 300000,
        installmentAmount: 100000,
        totalCount: 3,
        createdAt: plan.createdAt,
        paidCount: 4,
      ),
      throwsArgumentError,
    );
  });

  test('addInstallmentPlan stores an explicit createdAt', () async {
    // The add sheet passes the purchase's picked date so a backdated
    // purchase anchors its schedule to the purchase, not to today.
    final backdated = DateTime(2026, 10, 10, 14, 30);
    final planId = await db.addInstallmentPlan(
      walletId: walletId,
      name: 'Backdated',
      totalAmount: 120000,
      installmentAmount: 120000,
      totalCount: 1,
      createdAt: backdated,
    );
    final plan = await getPlan(planId);
    expect(plan.createdAt, backdated);
  });
}
