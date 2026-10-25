import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/utils/paylater.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// Paylater feature: liabilities stay out of asset totals, installment
/// plans track progress, the tenor quote never invents a rate, and the
/// freeze gate only blocks genuinely new paylater expenses.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
  });

  tearDown(() => db.close());

  Future<int> makeWallet(
    int accountId,
    String name,
    String kind, {
    int initialAmount = 0,
    int? creditLimit,
    int? dueDay,
    double? rate,
  }) =>
      db.createWallet(
        accountId: accountId,
        name: name,
        kind: kind,
        initialAmount: initialAmount,
        creditLimit: creditLimit,
        dueDay: dueDay,
        interestRateMonthly: rate,
      );

  Future<int> makeAccount() => db.addAccount(
        AccountsCompanion.insert(
          name: 'Personal',
          kind: 'personal',
          colorHex: const Value('#FF0000'),
        ),
      );

  group('combined balance', () {
    test('excludes paylater wallets but still includes credit wallets',
        () async {
      final account = await makeAccount();
      await makeWallet(account, 'Bank', 'bank', initialAmount: 100000);
      // Owed: stored negative, like every other wallet's balance math.
      await makeWallet(account, 'PayLater', 'paylater',
          initialAmount: -50000);
      await makeWallet(account, 'Card', 'credit', initialAmount: -20000);
      final wallets =
          await (db.select(db.wallets)).get();
      expect(combinedBalance(wallets), 80000);
      expect(paylaterWallets(wallets).map((w) => w.name), ['PayLater']);
      expect(totalPaylaterOutstanding(wallets), 50000);
    });

    test('positive paylater balance counts as zero outstanding', () {
      expect(outstandingFromBalance(1000), 0);
      expect(outstandingFromBalance(0), 0);
      expect(outstandingFromBalance(-670443), 670443);
    });
  });

  group('due dates', () {
    test('next due date skips to next month once the day has passed', () {
      expect(
        nextDueDate(dueDay: 15, from: DateTime(2026, 10, 26)),
        DateTime(2026, 11, 15),
      );
      expect(
        nextDueDate(dueDay: 28, from: DateTime(2026, 10, 26)),
        DateTime(2026, 10, 28),
      );
      // Due today counts as due today, not next month.
      expect(
        nextDueDate(dueDay: 26, from: DateTime(2026, 10, 26)),
        DateTime(2026, 10, 26),
      );
    });

    test('day 31 clamps to the last day of short months', () {
      expect(
        nextDueDate(dueDay: 31, from: DateTime(2026, 2, 15)),
        DateTime(2026, 2, 28),
      );
    });

    test('next due picks the earliest due wallet with money owed', () async {
      final account = await makeAccount();
      await makeWallet(account, 'Later', 'paylater',
          initialAmount: -10000, dueDay: 20);
      await makeWallet(account, 'Sooner', 'paylater',
          initialAmount: -20000, dueDay: 5);
      // No due day set: never eligible, however much is owed.
      await makeWallet(account, 'NoDay', 'paylater', initialAmount: -99999);
      // Nothing owed: never eligible, however soon the day.
      await makeWallet(account, 'PaidOff', 'paylater',
          initialAmount: 0, dueDay: 1);
      final wallets = await (db.select(db.wallets)).get();
      final next = nextPaylaterDue(wallets, DateTime(2026, 10, 26));
      expect(next, isNotNull);
      expect(next!.wallet.name, 'Sooner');
      expect(next.dueDate, DateTime(2026, 11, 5));
    });

    test('due this cycle only counts wallets due in the current month',
        () async {
      final account = await makeAccount();
      await makeWallet(account, 'ThisMonth', 'paylater',
          initialAmount: -30000, dueDay: 28);
      await makeWallet(account, 'NextMonth', 'paylater',
          initialAmount: -70000, dueDay: 5);
      final wallets = await (db.select(db.wallets)).get();
      expect(dueThisCycle(wallets, DateTime(2026, 10, 26)), 30000);
    });
  });

  group('installment plans', () {
    test('progress and remaining advance one installment at a time',
        () async {
      final account = await makeAccount();
      final walletId = await makeWallet(account, 'PayLater', 'paylater');
      final planId = await db.addInstallmentPlan(
        walletId: walletId,
        name: 'Phone',
        totalAmount: 1200000,
        installmentAmount: 400000,
        totalCount: 3,
      );
      Future<InstallmentPlan> fetch() =>
          (db.select(db.installmentPlans)
                ..where((p) => p.id.equals(planId)))
              .getSingle();

      var plan = await fetch();
      expect(planRemaining(plan), 1200000);
      expect(planProgress(plan), 0);

      await db.markInstallmentPaid(planId);
      plan = await fetch();
      expect(plan.paidCount, 1);
      expect(planRemaining(plan), 800000);
      expect(planProgress(plan), closeTo(1 / 3, 0.001));

      // Paying past the end caps at totalCount, never below zero left.
      await db.markInstallmentPaid(planId);
      await db.markInstallmentPaid(planId);
      await db.markInstallmentPaid(planId);
      plan = await fetch();
      expect(plan.paidCount, 3);
      expect(planRemaining(plan), 0);
      expect(planProgress(plan), 1);
    });
  });

  group('tenor calculator', () {
    test('flat monthly fee on the full principal', () {
      final quote =
          calcTenor(principal: 1200000, tenor: 3, monthlyRatePercent: 2.5);
      expect(quote.monthlyAmount, 430000);
      expect(quote.totalInterest, 90000);
      expect(quote.totalPayable, 1290000);
    });

    test('single payment still carries one month of fee', () {
      final quote =
          calcTenor(principal: 100000, tenor: 1, monthlyRatePercent: 2.0);
      expect(quote.monthlyAmount, 102000);
      expect(quote.totalInterest, 2000);
    });

    test('unset rate shows the plain split and never invents interest',
        () {
      final quote = calcTenor(principal: 1200000, tenor: 3);
      expect(quote.monthlyAmount, 400000);
      expect(quote.totalInterest, isNull);
      expect(quote.totalPayable, 1200000);
    });
  });

  group('freeze gate', () {
    test('blocks only new expenses on paylater wallets while frozen', () {
      expect(
        isPaylaterSpendBlocked(
          frozen: true,
          walletKind: 'paylater',
          isNewExpense: true,
        ),
        isTrue,
      );
      expect(
        isPaylaterSpendBlocked(
          frozen: true,
          walletKind: 'paylater',
          isNewExpense: false,
        ),
        isFalse,
      );
      expect(
        isPaylaterSpendBlocked(
          frozen: true,
          walletKind: 'bank',
          isNewExpense: true,
        ),
        isFalse,
      );
      expect(
        isPaylaterSpendBlocked(
          frozen: false,
          walletKind: 'paylater',
          isNewExpense: true,
        ),
        isFalse,
      );
    });

    test('freeze preference round-trips and defaults to off', () async {
      expect(AppPrefs.paylaterFrozen, isFalse);
      await AppPrefs.setPaylaterFrozen(true);
      expect(AppPrefs.paylaterFrozen, isTrue);
      await AppPrefs.setPaylaterFrozen(false);
      expect(AppPrefs.paylaterFrozen, isFalse);
    });
  });

  group('paylater wallet fields', () {
    test('limit, due day and rate round-trip through create and edit',
        () async {
      final account = await makeAccount();
      final id = await makeWallet(
        account,
        'PayLater',
        'paylater',
        initialAmount: -670443,
        creditLimit: 2000000,
        dueDay: 5,
        rate: 2.5,
      );
      var wallet = await db.getWalletById(id);
      expect(wallet?.creditLimit, 2000000);
      expect(wallet?.dueDay, 5);
      expect(wallet?.interestRateMonthly, 2.5);
      expect(paylaterOutstanding(wallet!), 670443);

      await db.updateWallet(
        id: id,
        name: 'PayLater',
        kind: 'paylater',
        creditLimit: const Value(3000000),
        statementDay: const Value(20),
        dueDay: const Value(10),
        interestRateMonthly: const Value(null),
      );
      wallet = await db.getWalletById(id);
      expect(wallet?.creditLimit, 3000000);
      expect(wallet?.statementDay, 20);
      expect(wallet?.dueDay, 10);
      expect(wallet?.interestRateMonthly, isNull);
    });
  });
}
