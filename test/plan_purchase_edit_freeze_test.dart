import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/data/database/app_database.dart';
import 'package:dmoney_manager/features/transactions/add_transaction_sheet.dart';
import 'package:dmoney_manager/state/providers.dart';

/// Raising a plan purchase's amount in the add-sheet edit path is new
/// paylater spending, so the freeze gate applies — like it does to Add
/// Plan and the plan edit sheet. The purchase edit used to bypass the
/// freeze entirely.
void main() {
  // The sheet's internals nest ListTiles in DecoratedBoxes, which
  // trips a debug-only framework assertion in tests, and the success
  // snackbar holds a 4 s timer — pump past both and drain only the
  // ListTile noise; anything else is a real failure.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    while (true) {
      final ex = tester.takeException();
      if (ex == null) break;
      final msg = ex.toString();
      if (msg.contains('Multiple exceptions')) continue;
      expect(msg, contains('ListTile'),
          reason: 'unexpected exception while settling the sheet');
    }
  }

  testWidgets('raising a plan purchase while frozen asks to unfreeze',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
    await initializeDateFormatting();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final walletId = await db.createWallet(
      accountId: 1,
      name: 'SPayLater',
      kind: 'paylater',
      initialAmount: 0,
    );
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
    final purchase = await tester.runAsync(
      () => db
          .planTransactions(planId!)
          .then((ts) => ts.singleWhere((t) => t.kind == 'expense')),
    );
    final details = await tester.runAsync(
      () => db.getTransactionDetailById(purchase!.id),
    );
    await AppPrefs.setPaylaterFrozen(true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AddTransactionSheet(existing: details)),
        ),
      ),
    );
    await settle(tester);

    // Raise the amount: the first TextField is the amount entry.
    await tester.enterText(find.byType(TextField).first, '400000');
    await tester.tap(find.text('Save changes'));
    await settle(tester);

    // The freeze dialog appears; declining leaves everything untouched.
    expect(find.text('Paylater is frozen'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    final still = await tester.runAsync(
      () => db.getTransactionDetailById(purchase!.id),
    );
    expect(still!.transaction.amount, 300000);
    expect(AppPrefs.paylaterFrozen, isTrue);

    // Accepting unfreezes and the save goes through, plan synced.
    await tester.tap(find.text('Save changes'));
    await settle(tester);
    expect(find.text('Paylater is frozen'), findsOneWidget);
    await tester.tap(find.text('Unfreeze & save'));
    // The save's success snackbar holds a 4 s timer that starts only
    // after the 750 ms success beat — pump well past both.
    await settle(tester);
    await settle(tester);

    expect(AppPrefs.paylaterFrozen, isFalse);
    final updated = await tester.runAsync(
      () => db.getTransactionDetailById(purchase!.id),
    );
    expect(updated!.transaction.amount, 400000);
    final plan = await tester.runAsync(() => db.getInstallmentPlan(planId!));
    expect(plan!.totalAmount, 400000);
    expect(plan.installmentAmount, 133333);

    // The amount field keeps focus (cursor blink timer) and the
    // success snackbar holds a 4 s timer — clear both before the
    // tree is disposed, or the test ends on a pending timer.
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
