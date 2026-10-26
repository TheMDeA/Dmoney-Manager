import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/utils/paylater.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// Paylater fixes (2.7.1): income can no longer land on a paylater
/// wallet, transfers that would overpay are computed for a warning,
/// installment payments are real transfers (not just a counter bump),
/// paylater balances display as owed/overpaid, and paylater wallets
/// stay out of the Wallets screen stack.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
  });

  tearDown(() => db.close());

  Future<int> makeAccount() => db.addAccount(
    AccountsCompanion.insert(
      name: 'Personal',
      kind: 'personal',
      colorHex: const Value('#FF0000'),
    ),
  );

  Future<int> makeWallet(
    int accountId,
    String name,
    String kind, {
    int initialAmount = 0,
  }) => db.createWallet(
    accountId: accountId,
    name: name,
    kind: kind,
    initialAmount: initialAmount,
  );

  Future<InstallmentPlan> getPlan(int id) =>
      (db.select(db.installmentPlans)..where((p) => p.id.equals(id)))
          .getSingle();

  group('income gate', () {
    test('blocks income on paylater wallets only', () {
      expect(
        isIncomeToPaylaterBlocked(walletKind: 'paylater', kind: 'income'),
        isTrue,
      );
      expect(
        isIncomeToPaylaterBlocked(walletKind: 'paylater', kind: 'expense'),
        isFalse,
      );
      expect(
        isIncomeToPaylaterBlocked(walletKind: 'bank', kind: 'income'),
        isFalse,
      );
      expect(
        isIncomeToPaylaterBlocked(walletKind: 'credit', kind: 'income'),
        isFalse,
      );
    });
  });

  group('overpay computation', () {
    test('transfer exceeding owed reports the excess', () {
      // Owes 500.000, pays 600.000 -> over by 100.000.
      expect(paylaterTransferOverpay(-500000, 600000), 100000);
    });

    test('exact payment and partial payment report zero overpay', () {
      expect(paylaterTransferOverpay(-500000, 500000), 0);
      expect(paylaterTransferOverpay(-500000, 200000), 0);
    });

    test('already-positive balance grows the overpay total', () {
      expect(paylaterTransferOverpay(100000, 50000), 150000);
      expect(paylaterTransferOverpay(0, 100000), 100000);
    });
  });

  group('installment payment flow', () {
    test('records a transfer, bumps paidCount, reduces remaining', () async {
      final account = await makeAccount();
      final payer = await makeWallet(account, 'Bank', 'bank',
          initialAmount: 1000000);
      final pl = await makeWallet(account, 'PayLater', 'paylater',
          initialAmount: -500000);
      final planId = await db.addInstallmentPlan(
        walletId: pl,
        name: 'Susu',
        totalAmount: 500000,
        installmentAmount: 100000,
        totalCount: 5,
      );
      var plan = await getPlan(planId);
      // Mirrors _payInstallment's DB steps: capped amount, transfer, bump.
      final amount = installmentDueAmount(plan);
      expect(amount, 100000);
      await db.addTransfer(
        fromWalletId: payer,
        toWalletId: pl,
        amount: amount,
        note: 'Installment payment: Susu',
      );
      await db.markInstallmentPaid(planId);
      plan = await getPlan(planId);
      expect(plan.paidCount, 1);
      expect(planRemaining(plan), 400000);
      final transfers =
          await (db.select(db.transactions)
                ..where((t) => t.kind.equals('transfer')))
              .get();
      expect(transfers.length, 1);
      expect(transfers.first.amount, 100000);
      expect(transfers.first.note, 'Installment payment: Susu');
      expect(transfers.first.toWalletId, pl);
      final wallets = await (db.select(db.wallets)).get();
      expect(
        wallets.firstWhere((w) => w.id == pl).balance,
        -400000,
      );
      expect(
        wallets.firstWhere((w) => w.id == payer).balance,
        900000,
      );
    });

    test('installment amount caps at plan remaining', () async {
      final account = await makeAccount();
      final pl = await makeWallet(account, 'PayLater', 'paylater');
      final planId = await db.addInstallmentPlan(
        walletId: pl,
        name: 'Partial',
        totalAmount: 450000,
        installmentAmount: 100000,
        totalCount: 5,
      );
      for (var i = 0; i < 4; i++) {
        await db.markInstallmentPaid(planId);
      }
      final plan = await getPlan(planId);
      expect(planRemaining(plan), 50000);
      expect(installmentDueAmount(plan), 50000);
    });
  });

  group('owed display', () {
    test('negative balance shows owed, positive shows overpaid', () async {
      final account = await makeAccount();
      final owed = await makeWallet(account, 'Owed', 'paylater',
          initialAmount: -200000);
      final overpaid = await makeWallet(account, 'Over', 'paylater',
          initialAmount: 5005000);
      final settled = await makeWallet(account, 'Zero', 'paylater');
      final wallets = await (db.select(db.wallets)).get();
      expect(
        paylaterBalanceLabel(wallets.firstWhere((w) => w.id == owed)),
        'Rp 200.000',
      );
      expect(
        paylaterBalanceLabel(wallets.firstWhere((w) => w.id == overpaid)),
        'Overpaid Rp 5.005.000',
      );
      expect(
        paylaterBalanceLabel(wallets.firstWhere((w) => w.id == settled)),
        'Rp 0',
      );
    });
  });

  group('stack filter', () {
    test('excludes paylater wallets, keeps everything else', () async {
      final account = await makeAccount();
      await makeWallet(account, 'Bank', 'bank', initialAmount: 100000);
      await makeWallet(account, 'PayLater', 'paylater');
      await makeWallet(account, 'Card', 'credit', initialAmount: -20000);
      final wallets = await (db.select(db.wallets)).get();
      expect(
        stackWallets(wallets).map((w) => w.name),
        ['Bank', 'Card'],
      );
    });
  });
}
