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

  Future<int> makeWallet(String name, String kind) =>
      db.createWallet(accountId: 1, name: name, kind: kind);

  Future<int> foodId() async {
    final cats = await db.select(db.categories).get();
    return cats.firstWhere((c) => c.name == 'Food').id;
  }

  Future<Wallet> getWallet(int id) => db.getWalletById(id).then((w) => w!);

  Future<Transaction> getTx(int id) =>
      (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();

  group('addPlanWithPurchase', () {
    test(
      'creates the plan and its purchase expense, wallet owes total',
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

        final plan = await (db.select(
          db.installmentPlans,
        )..where((p) => p.id.equals(planId))).getSingle();
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
      },
    );
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
    test('removes purchase + payments and restores both balances', () async {
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
      expect(paylaterRepayments(txs, {paylaterId, otherPaylaterId}), 7000000);
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
    }) => InstallmentPlan(
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
        plan(
          id: 1,
          walletId: 7,
          total: 9000000,
          monthly: 3000000,
          count: 3,
          paid: 0,
        ),
        plan(
          id: 2,
          walletId: 7,
          total: 6000000,
          monthly: 3000000,
          count: 2,
          paid: 0,
        ),
      ];
      expect(singlePayablePlan(plans, 7), isNull);
    });

    test('plans on other wallets are ignored', () {
      final plans = [
        plan(
          id: 1,
          walletId: 7,
          total: 18000000,
          monthly: 6000000,
          count: 3,
          paid: 1,
        ),
        plan(
          id: 2,
          walletId: 9,
          total: 6000000,
          monthly: 3000000,
          count: 2,
          paid: 0,
        ),
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

    test('installments above the total stay payable to the end', () {
      // Monthly × count (150000) exceeds the purchase total (100000)
      // — the rated-plan shape, where the monthly amount carries the
      // fee. The obligation is the installments' sum, so one 50000
      // installment remains payable. (Keying off the total instead
      // used to strand such plans with money still to pay.)
      final p = plan(
        id: 1,
        walletId: 7,
        total: 100000,
        monthly: 50000,
        count: 3,
        paid: 2,
      );
      expect(installmentDueAmount(p), 50000);
      expect(singlePayablePlan([p], 7)?.id, 1);
    });

    test('last installment settles the remaining in full', () {
      final p = plan(
        id: 1,
        walletId: 7,
        total: 100000,
        monthly: 40000,
        count: 3,
        paid: 2,
      );
      // Obligation is 3 × 40000 = 120000 (the rated shape again), so
      // the final installment is a full monthly amount, not the
      // 20000 the principal-only math used to cap it at.
      expect(installmentDueAmount(p), 40000);
      expect(singlePayablePlan([p], 7)?.id, 1);
    });
  });

  group('nextInstallmentDueDate', () {
    InstallmentPlan datedPlan({
      required DateTime created,
      required int paid,
      required int count,
    }) => InstallmentPlan(
      id: 1,
      walletId: 7,
      name: 'Plan',
      totalAmount: 18000000,
      installmentAmount: 6000000,
      totalCount: count,
      paidCount: paid,
      createdAt: created,
    );

    test('first installment due the month after creation, on due day', () {
      final p = datedPlan(created: DateTime(2026, 10, 27), paid: 0, count: 3);
      expect(nextInstallmentDueDate(p, 11), DateTime(2026, 11, 11));
    });

    test('each payment rolls the date one month forward', () {
      final created = DateTime(2026, 10, 27);
      expect(
        nextInstallmentDueDate(
          datedPlan(created: created, paid: 1, count: 3),
          11,
        ),
        DateTime(2026, 12, 11),
      );
      expect(
        nextInstallmentDueDate(
          datedPlan(created: created, paid: 2, count: 3),
          11,
        ),
        DateTime(2027, 1, 11),
      );
    });

    test('complete plan → null', () {
      final p = datedPlan(created: DateTime(2026, 10, 27), paid: 3, count: 3);
      expect(nextInstallmentDueDate(p, 11), isNull);
    });

    test('day 31 clamps to short month end', () {
      final p = datedPlan(created: DateTime(2026, 1, 15), paid: 0, count: 3);
      expect(nextInstallmentDueDate(p, 31), DateTime(2026, 2, 28));
    });

    test('no wallet due day → creation day', () {
      final p = datedPlan(created: DateTime(2026, 10, 27), paid: 0, count: 3);
      expect(nextInstallmentDueDate(p, null), DateTime(2026, 11, 27));
    });

    test('year rollover', () {
      final p = datedPlan(created: DateTime(2026, 12, 10), paid: 0, count: 3);
      expect(nextInstallmentDueDate(p, 11), DateTime(2027, 1, 11));
    });
  });

  group('dueInstallmentGroup', () {
    Wallet wallet({int? dueDay = 2, int? statementDay}) => Wallet(
      id: 7,
      accountId: 1,
      name: 'TikTok Paylater',
      kind: 'paylater',
      balance: -954786,
      initialAmount: 0,
      colorHex: '#000000',
      sortOrder: 0,
      dueDay: dueDay,
      statementDay: statementDay,
    );

    InstallmentPlan p({
      required int id,
      required int monthly,
      required int count,
      int paid = 0,
      required DateTime created,
    }) => InstallmentPlan(
      id: id,
      walletId: 7,
      name: 'Plan $id',
      totalAmount: monthly * count,
      installmentAmount: monthly,
      totalCount: count,
      paidCount: paid,
      createdAt: created,
    );

    test('two plans due the same day group together', () {
      // The reported screenshot's shape: a 2x plan and a 1x plan,
      // both with their next installment due 02 Dec.
      final neos = p(
        id: 1,
        monthly: 284343,
        count: 2,
        created: DateTime(2026, 11, 6),
      );
      final ensure = p(
        id: 2,
        monthly: 386100,
        count: 1,
        created: DateTime(2026, 11, 6),
      );
      final g = dueInstallmentGroup([neos, ensure], wallet());
      expect(g, isNotNull);
      expect(g!.plans.map((e) => e.id), containsAll([1, 2]));
      expect(g.amount, 670443);
      expect(g.dueDate, DateTime(2026, 12, 2));
    });

    test('only the earliest due date groups', () {
      // Created a month earlier and never paid: its first installment
      // (02 Nov, overdue) is the next thing due — the December plan
      // is not part of this payment.
      final early = p(
        id: 1,
        monthly: 100000,
        count: 3,
        created: DateTime(2026, 10, 6),
      );
      final later = p(
        id: 2,
        monthly: 200000,
        count: 2,
        created: DateTime(2026, 11, 6),
      );
      final g = dueInstallmentGroup([early, later], wallet());
      expect(g!.plans.map((e) => e.id), [1]);
      expect(g.amount, 100000);
      expect(g.dueDate, DateTime(2026, 11, 2));
    });

    test('completed plans are ignored', () {
      final done = p(
        id: 1,
        monthly: 386100,
        count: 1,
        paid: 1,
        created: DateTime(2026, 11, 6),
      );
      final open = p(
        id: 2,
        monthly: 284343,
        count: 2,
        created: DateTime(2026, 11, 6),
      );
      final g = dueInstallmentGroup([done, open], wallet());
      expect(g!.plans.map((e) => e.id), [2]);
      expect(g.amount, 284343);
    });

    test('no due day or no payable plans → null', () {
      final open = p(
        id: 1,
        monthly: 100000,
        count: 2,
        created: DateTime(2026, 11, 6),
      );
      expect(dueInstallmentGroup([open], wallet(dueDay: null)), isNull);
      final done = p(
        id: 2,
        monthly: 100000,
        count: 2,
        paid: 2,
        created: DateTime(2026, 11, 6),
      );
      expect(dueInstallmentGroup([done], wallet()), isNull);
    });
  });
}
