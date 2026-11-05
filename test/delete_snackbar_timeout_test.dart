import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/data/database/app_database.dart';
import 'package:dmoney_manager/features/transactions/transaction_actions.dart';
import 'package:dmoney_manager/state/providers.dart';

/// The delete flow promises a 5-second undo snackbar, but a SnackBar
/// with an action persists until dismissed BY DEFAULT in the
/// framework (SnackBar.persist defaults to action != null) — the
/// duration was silently ignored and the bar stayed until swiped.
/// The flow now passes persist: false. This drives the real flow:
/// confirm the delete, see the bar, advance past the window, and
/// require it to be gone on its own.
void main() {
  testWidgets('record deleted snackbar times out on its own',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
    await initializeDateFormatting();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final walletId = await db.createWallet(
      accountId: 1,
      name: 'Jago',
      kind: 'bank',
      initialAmount: 100000,
    );
    final categoryId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: 'Food', kind: 'expense'),
        );
    final txId = await db.addTransaction(
      TransactionsCompanion.insert(
        walletId: walletId,
        categoryId: categoryId,
        kind: 'expense',
        amount: 25000,
        date: DateTime.now(),
      ),
    );
    final now = DateTime.now();
    final details = await tester.runAsync(
      () => db
          .watchTransactionsForWalletInRange(
            walletId,
            DateTime(now.year, now.month),
            DateTime(now.year, now.month + 1),
          )
          .first
          .then((items) =>
              items.firstWhere((d) => d.transaction.id == txId)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () =>
                      deleteTransactionFlow(context, ref, details!),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    // The flow awaits drift stream reads (photo snapshots) before it
    // deletes and shows the bar — those need real-async windows to
    // deliver, interleaved with pumps for the UI side.
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Record deleted'), findsOneWidget);

    // Past the 5-second undo window + exit animation: gone by itself.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Record deleted'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
