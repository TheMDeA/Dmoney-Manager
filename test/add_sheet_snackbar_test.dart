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

/// The add sheet carries its own ScaffoldMessenger so its snackbars
/// render inside the sheet — but a messenger needs a Scaffold in its
/// subtree to present on, and the sheet had none, so every message it
/// tried to show (photo-pick failures, template confirmations, the
/// OCR "filled from receipt" hint) queued forever and never appeared.
/// The sheet's content now sits in a transparent Scaffold under the
/// messenger. Opening the sheet the way receipt OCR does fires the
/// "filled from receipt" snack from initState — it must be visible.
void main() {
  testWidgets('add sheet snackbar actually presents', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
    await initializeDateFormatting();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.createWallet(
      accountId: 1,
      name: 'Jago',
      kind: 'bank',
      initialAmount: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AddTransactionSheet(ocrFilled: true),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text('Filled from receipt — please verify the details.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
