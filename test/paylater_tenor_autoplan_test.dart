import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/utils/paylater.dart';
import 'package:dmoney_manager/core/widgets/amount_field.dart';
import 'package:dmoney_manager/data/database/app_database.dart';
import 'package:dmoney_manager/features/transactions/add_transaction_sheet.dart';
import 'package:dmoney_manager/state/providers.dart';

/// Tenor auto-plan: saving a new paylater expense from the add sheet
/// creates an installment plan — including the default 1x, a 1-of-1
/// "pay next month" plan. Edits, income, and non-paylater wallets never
/// create plans.
void main() {
  group('autoPlanParams', () {
    test('1x unrated creates a 1-of-1 plan from the note', () {
      final plan = autoPlanParams(
        isNew: true,
        transactionKind: 'expense',
        walletKind: 'paylater',
        amount: 500000,
        tenor: 1,
        monthlyRatePercent: null,
        note: 'Susu',
        categoryName: 'Food',
      );
      expect(plan, isNotNull);
      expect(plan!.name, 'Susu');
      expect(plan.totalAmount, 500000);
      expect(plan.installmentAmount, 500000);
      expect(plan.totalCount, 1);
    });

    test('3x rated uses the quoted monthly (base + fee)', () {
      // Hand-computed, not via calcTenor, so the test isn't circular:
      // 300000 / 3 = 100000 base + 2% of 300000 = 6000 fee.
      final plan = autoPlanParams(
        isNew: true,
        transactionKind: 'expense',
        walletKind: 'paylater',
        amount: 300000,
        tenor: 3,
        monthlyRatePercent: 2.0,
        note: 'Laptop',
        categoryName: 'Shopping',
      );
      expect(plan, isNotNull);
      expect(plan!.installmentAmount, 106000);
      expect(plan.totalAmount, 300000);
      expect(plan.totalCount, 3);
    });

    test('6x unrated splits the principal evenly', () {
      final plan = autoPlanParams(
        isNew: true,
        transactionKind: 'expense',
        walletKind: 'paylater',
        amount: 600000,
        tenor: 6,
        monthlyRatePercent: null,
        note: 'Shoes',
        categoryName: 'Shopping',
      );
      expect(plan, isNotNull);
      expect(plan!.installmentAmount, 100000);
      expect(plan.totalCount, 6);
    });

    test('name falls back to category, then to a default', () {
      final fromCategory = autoPlanParams(
        isNew: true,
        transactionKind: 'expense',
        walletKind: 'paylater',
        amount: 100000,
        tenor: 1,
        monthlyRatePercent: null,
        note: '   ',
        categoryName: 'Food',
      );
      expect(fromCategory!.name, 'Food');
      final fallback = autoPlanParams(
        isNew: true,
        transactionKind: 'expense',
        walletKind: 'paylater',
        amount: 100000,
        tenor: 1,
        monthlyRatePercent: null,
        note: '',
        categoryName: null,
      );
      expect(fallback!.name, 'Paylater installment');
    });

    test('edits, income, non-paylater, and bad amounts create nothing', () {
      void check({
        required bool isNew,
        required String kind,
        required String walletKind,
        required int amount,
        required int tenor,
      }) {
        expect(
          autoPlanParams(
            isNew: isNew,
            transactionKind: kind,
            walletKind: walletKind,
            amount: amount,
            tenor: tenor,
            monthlyRatePercent: null,
            note: 'X',
            categoryName: 'Food',
          ),
          isNull,
        );
      }

      check(
        isNew: false,
        kind: 'expense',
        walletKind: 'paylater',
        amount: 100000,
        tenor: 1,
      );
      check(
        isNew: true,
        kind: 'income',
        walletKind: 'paylater',
        amount: 100000,
        tenor: 1,
      );
      check(
        isNew: true,
        kind: 'expense',
        walletKind: 'bank',
        amount: 100000,
        tenor: 3,
      );
      check(
        isNew: true,
        kind: 'expense',
        walletKind: 'paylater',
        amount: 0,
        tenor: 1,
      );
      check(
        isNew: true,
        kind: 'expense',
        walletKind: 'paylater',
        amount: 100000,
        tenor: 0,
      );
    });
  });

  group('add sheet auto-plan', () {
    Future<AppDatabase> openDb() async {
      SharedPreferences.setMockInitialValues({});
      await AppPrefs.init();
      await initializeDateFormatting();
      return AppDatabase.forTesting(NativeDatabase.memory());
    }

    Future<int> makeWallet(
      AppDatabase db,
      String name,
      String kind, {
      double? rate,
    }) =>
        db.createWallet(
          accountId: 1,
          name: name,
          kind: kind,
          interestRateMonthly: rate,
        );

    Future<int> foodId(AppDatabase db) async {
      final cats = await db.select(db.categories).get();
      return cats.firstWhere((c) => c.name == 'Food').id;
    }

    Future<void> pumpSheet(
      WidgetTester tester,
      AppDatabase db, {
      int? walletId,
      TransactionWithDetails? existing,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: Scaffold(
              body: AddTransactionSheet(
                initialKind: 'expense',
                initialWalletId: walletId,
                existing: existing,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> fillAndSave(
      WidgetTester tester, {
      required String desc,
      required String amount,
      String? tenorChip,
      String saveLabel = 'Save',
    }) async {
      final descField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'What was this for?',
      );
      await tester.enterText(descField, desc);
      await tester.pump();
      final amountField = find.descendant(
        of: find.byType(AmountField),
        matching: find.byType(TextField),
      );
      await tester.enterText(amountField, amount);
      await tester.pump();
      // The quick-pick grid only shows 3 categories, so go through the
      // full list to pick Food deterministically.
      await tester.ensureVisible(find.text('All'));
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Food'));
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      if (tenorChip != null) {
        await tester.ensureVisible(find.text(tenorChip));
        await tester.tap(find.text(tenorChip));
        await tester.pump();
      }
      await tester.tap(find.text(saveLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
    }

    Future<void> disposeTrap(WidgetTester tester) async {
      // Drift schedules a zero-duration cleanup timer when a
      // StreamBuilder is disposed; drain it so it can't leak into the
      // next test.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('default tenor saves a 1-of-1 plan', (tester) async {
      final db = await openDb();
      final paylaterId = await makeWallet(db, 'ShopeePay', 'paylater');
      await pumpSheet(tester, db, walletId: paylaterId);
      expect(tester.takeException(), isNull);

      await fillAndSave(tester, desc: 'Susu test', amount: '500000');

      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(1));
      expect(txs.first.kind, 'expense');
      expect(txs.first.amount, 500000);
      final plans = await db.select(db.installmentPlans).get();
      expect(plans, hasLength(1));
      expect(plans.first.name, 'Susu test');
      expect(plans.first.walletId, paylaterId);
      expect(plans.first.totalAmount, 500000);
      expect(plans.first.installmentAmount, 500000);
      expect(plans.first.totalCount, 1);
      expect(plans.first.paidCount, 0);
      await disposeTrap(tester);
    });

    testWidgets('3x on a rated wallet saves the quoted monthly',
        (tester) async {
      final db = await openDb();
      final paylaterId =
          await makeWallet(db, 'ShopeePay', 'paylater', rate: 2.0);
      await pumpSheet(tester, db, walletId: paylaterId);
      expect(tester.takeException(), isNull);

      await fillAndSave(
        tester,
        desc: 'Laptop',
        amount: '300000',
        tenorChip: '3x',
      );

      final plans = await db.select(db.installmentPlans).get();
      expect(plans, hasLength(1));
      expect(plans.first.name, 'Laptop');
      expect(plans.first.totalAmount, 300000);
      // Hand-computed: 300000 / 3 + 2% of 300000 = 106000.
      expect(plans.first.installmentAmount, 106000);
      expect(plans.first.totalCount, 3);
      expect(plans.first.paidCount, 0);
      await disposeTrap(tester);
    });

    testWidgets('non-paylater expense saves no plan', (tester) async {
      final db = await openDb();
      final bankId = await makeWallet(db, 'Jago', 'bank');
      await makeWallet(db, 'ShopeePay', 'paylater');
      await pumpSheet(tester, db, walletId: bankId);
      expect(tester.takeException(), isNull);

      await fillAndSave(tester, desc: 'Groceries', amount: '200000');

      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(1));
      expect(await db.select(db.installmentPlans).get(), isEmpty);
      await disposeTrap(tester);
    });

    testWidgets('editing a paylater expense saves no plan', (tester) async {
      final db = await openDb();
      final paylaterId = await makeWallet(db, 'ShopeePay', 'paylater');
      final food = await foodId(db);
      final txId = await db.addTransaction(
        TransactionsCompanion.insert(
          walletId: paylaterId,
          categoryId: food,
          kind: 'expense',
          amount: 100000,
          note: const Value('Old desc'),
          memo: const Value(''),
          date: DateTime.now(),
        ),
      );
      final existing = await db.getTransactionDetailById(txId);
      expect(existing, isNotNull);
      await pumpSheet(tester, db, existing: existing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Save changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      expect(await db.select(db.installmentPlans).get(), isEmpty);
      await disposeTrap(tester);
    });
  });
}
