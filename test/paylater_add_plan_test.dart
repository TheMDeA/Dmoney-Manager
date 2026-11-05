import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/utils/paylater.dart';
import 'package:dmoney_manager/data/database/app_database.dart';
import 'package:dmoney_manager/features/categories/category_picker_section.dart';
import 'package:dmoney_manager/features/wallets/paylater_dashboard_screen.dart';
import 'package:dmoney_manager/state/providers.dart';

/// The manual Add Plan sheet used to make you type the installment
/// count into a text field — with a minimum of 2 — while the
/// add-transaction flow offers tenor chips (1x/3x/6x/12x) with a live
/// quote. The sheet now uses the same chips and quote, plus a Custom
/// chip for any other count, so a 1-installment plan ("buy now, pay in
/// full next month") can be made from the Paylater menu too. These
/// tests drive the real sheet.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    // The dashboard's cards nest ListTiles in decorated boxes, which
    // trips a debug-only framework assertion in tests. Drain those —
    // and only those; anything else is a real failure. (When several
    // errors pend, takeException also yields a "Multiple exceptions"
    // aggregate marker — a terminator, not an error.)
    while (true) {
      final ex = tester.takeException();
      if (ex == null) break;
      final s = ex.toString();
      if (s.contains('Multiple exceptions')) continue;
      expect(s, contains('ListTile'),
          reason: 'unexpected exception while pumping the dashboard');
    }
  }

  Future<(AppDatabase, int)> pumpDashboard(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
    await initializeDateFormatting();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final walletId = await db.createWallet(
      accountId: 1,
      name: 'ShopeePayLater',
      kind: 'paylater',
      initialAmount: 0,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PaylaterDashboardScreen(),
        ),
      ),
    );
    await settle(tester);
    // Open the Add plan sheet from the plans section.
    await tester.ensureVisible(find.text('Add plan'));
    await tester.tap(find.text('Add plan'));
    await settle(tester);
    return (db, walletId);
  }

  Future<void> pickFirstCategory(WidgetTester tester, AppDatabase db) async {
    // The first expense category in DB order is always one of the
    // picker's quick tiles (they show the first three in that order).
    final cat = await tester.runAsync(
      () => (db.select(db.categories)
            ..where((c) => c.kind.equals('expense'))
            ..limit(1))
          .getSingle(),
    );
    final tile = find.descendant(
      of: find.byType(CategoryPickerSection),
      matching: find.text(cat!.name),
    );
    await tester.ensureVisible(tile);
    await settle(tester);
    await tester.tap(tile);
    await settle(tester);
  }

  Future<void> submit(WidgetTester tester) async {
    // The sheet's own action button (the second 'Add plan').
    await tester.tap(find.text('Add plan').last);
    await settle(tester);
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('add plan sheet accepts a single installment', (tester) async {
    final (db, walletId) = await pumpDashboard(tester);

    // Name and total amount, then pick the tenor with the chips —
    // tap 3x and back to 1x to prove the selection drives the plan.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Test');
    await tester.enterText(fields.at(1), '50000');
    await tester.ensureVisible(find.text('3x'));
    await tester.tap(find.text('3x'));
    await settle(tester);
    await tester.tap(find.text('1x'));
    await settle(tester);
    // The live quote line, same as the add-transaction flow shows.
    expect(find.textContaining('/mo'), findsOneWidget);

    await pickFirstCategory(tester, db);
    await submit(tester);

    final plans = await tester.runAsync(() => db.plansForWallet(walletId));
    expect(plans, hasLength(1));
    final plan = plans!.single;
    expect(plan.totalCount, 1);
    expect(plan.paidCount, 0);
    expect(plan.installmentAmount, 50000);
    expect(installmentDueAmount(plan), 50000);
    // A 1-installment plan falls due next month on the due day.
    final due = nextInstallmentDueDate(plan, 11)!;
    final now = DateTime.now();
    expect(due.year, now.month == 12 ? now.year + 1 : now.year);
    expect(due.month, now.month == 12 ? 1 : now.month + 1);
    expect(due.day, 11);

    // The purchase was recorded against the paylater wallet.
    final wallet = await tester.runAsync(() => db.getWalletById(walletId));
    expect(wallet!.balance, -50000);

    await teardown(tester);
  });

  testWidgets('add plan sheet accepts a custom installment count',
      (tester) async {
    final (db, walletId) = await pumpDashboard(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Custom plan');
    await tester.enterText(fields.at(1), '50000');
    // The Custom chip reveals a count field; 5x on Rp 50.000 quotes
    // Rp 10.000/mo (no rate set on the test wallet).
    await tester.ensureVisible(find.text('Custom'));
    await tester.tap(find.text('Custom'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(2), '5');
    await settle(tester);
    expect(find.textContaining('10.000/mo'), findsOneWidget);

    await pickFirstCategory(tester, db);
    await submit(tester);

    final plans = await tester.runAsync(() => db.plansForWallet(walletId));
    expect(plans, hasLength(1));
    final plan = plans!.single;
    expect(plan.totalCount, 5);
    expect(plan.paidCount, 0);
    expect(plan.installmentAmount, 10000);

    final wallet = await tester.runAsync(() => db.getWalletById(walletId));
    expect(wallet!.balance, -50000);

    await teardown(tester);
  });
}
