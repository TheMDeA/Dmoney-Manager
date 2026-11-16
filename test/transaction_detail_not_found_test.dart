import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/data/database/app_database.dart';
import 'package:dmoney_manager/features/transactions/transaction_detail_screen.dart';
import 'package:dmoney_manager/state/providers.dart';

/// Opening the detail of a deleted transaction used to spin forever:
/// the FutureBuilder showed a spinner whenever data was null, with no
/// done-check. It must show a not-found state with a way back instead.
void main() {
  Future<void> pumpDetail(WidgetTester tester, AppDatabase db) async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
    await initializeDateFormatting();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TransactionDetailScreen(
                        // No transaction with this id exists in the
                        // empty test database.
                        transactionId: 999999,
                        iconKey: 'receipt',
                        colorHex: '#4ADE80',
                        title: 'Test',
                      ),
                    ),
                  ),
                  child: const Text('Open detail'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Open detail'));
    await tester.tap(find.text('Open detail'));
    // Let the real (async) load finish, then rebuild.
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('detail of a missing record shows not-found, not a spinner',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await pumpDetail(tester, db);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Record not found'), findsOneWidget);
    expect(find.text('It may have been deleted.'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    // The way back works: Close pops to the opener. pumpAndSettle, not
    // a single pump — the outgoing route stays in the tree while its
    // exit animation runs, so one frame still finds its widgets.
    await tester.ensureVisible(find.text('Close'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Record not found'), findsNothing);
    expect(find.text('Open detail'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
