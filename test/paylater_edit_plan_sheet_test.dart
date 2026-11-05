import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/data/database/app_database.dart';
import 'package:dmoney_manager/features/wallets/paylater_dashboard_screen.dart';
import 'package:dmoney_manager/state/providers.dart';

/// The Edit plan sheet (pencil on the plan card): name and tenor
/// edits save with the monthly amount recomputed by the usual quote
/// math while the purchase stays untouched; a plan with no linked
/// purchase shows its total read-only (with the reason) but still
/// accepts other edits.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    // The dashboard's cards nest ListTiles in decorated boxes, which
    // trips a debug-only framework assertion in tests. Drain those —
    // and only those; anything else is a real failure.
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
    return (db, walletId);
  }

  testWidgets('edit name and tenor recomputes the monthly amount',
      (tester) async {
    final (db, walletId) = await pumpDashboard(tester);
    final categoryId = await tester.runAsync(
      () => db.into(db.categories).insert(
            CategoriesCompanion.insert(name: 'Gadget', kind: 'expense'),
          ),
    );
    final planId = await tester.runAsync(
      () => db.addPlanWithPurchase(
        walletId: walletId,
        name: 'Phone',
        totalAmount: 300000,
        installmentAmount: 100000,
        totalCount: 3,
        categoryId: categoryId!,
      ),
    );
    await settle(tester);

    await tester.ensureVisible(find.byIcon(Icons.edit_outlined));
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await settle(tester);
    expect(find.text('Edit installment plan'), findsOneWidget);

    // Chip first, while nothing has focus: the sheet's content
    // scrolls on the small test surface, and an off-viewport chip's
    // rect can sit under the footer button — ensureVisible brings
    // it into the viewport (real hit-testing on device respects
    // the clip; this is a test-surface quirk). Typing first would
    // let the focus-driven scroll move it back out.
    await tester.ensureVisible(find.text('6x'));
    await settle(tester);
    await tester.tap(find.text('6x'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Phone X');
    await tester.tap(find.text('Save'));
    await settle(tester);

    final plan = await tester.runAsync(
      () => db
          .plansForWallet(walletId)
          .then((ps) => ps.firstWhere((p) => p.id == planId)),
    );
    expect(plan!.name, 'Phone X');
    expect(plan.totalCount, 6);
    expect(plan.installmentAmount, 50000);
    expect(plan.totalAmount, 300000);
    final purchase = await tester.runAsync(
      () => db
          .planTransactions(planId!)
          .then((ts) => ts.singleWhere((t) => t.kind == 'expense')),
    );
    expect(purchase!.amount, 300000);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('plan without a purchase: total read-only, name saves',
      (tester) async {
    final (db, walletId) = await pumpDashboard(tester);
    final planId = await tester.runAsync(
      () => db.addInstallmentPlan(
        walletId: walletId,
        name: 'Legacy',
        totalAmount: 200000,
        installmentAmount: 100000,
        totalCount: 2,
      ),
    );
    await settle(tester);

    await tester.ensureVisible(find.byIcon(Icons.edit_outlined));
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await settle(tester);
    expect(
      find.text(
          "No purchase is linked to this plan, so its total can't be changed."),
      findsOneWidget,
    );
    final totalField =
        tester.widget<TextField>(find.byType(TextField).at(1));
    expect(totalField.enabled, isFalse);

    await tester.enterText(find.byType(TextField).first, 'Legacy renamed');
    await tester.tap(find.text('Save'));
    await settle(tester);

    final plan = await tester.runAsync(
      () => db
          .plansForWallet(walletId)
          .then((ps) => ps.firstWhere((p) => p.id == planId)),
    );
    expect(plan!.name, 'Legacy renamed');
    expect(plan.totalAmount, 200000);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
