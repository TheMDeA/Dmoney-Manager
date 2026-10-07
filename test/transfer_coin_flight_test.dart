import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/widgets/amount_field.dart';
import 'package:dmoney_manager/core/widgets/form_sheet.dart';
import 'package:dmoney_manager/data/database/app_database.dart';
import 'package:dmoney_manager/features/transactions/transfer_sheet.dart';
import 'package:dmoney_manager/state/providers.dart';

/// Transfer success: a coin flies from the From wallet to the To wallet,
/// then a checkmark pops before the sheet closes.
void main() {
  testWidgets('transfer plays coin flight', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
    await initializeDateFormatting();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final accountId = await db.addAccount(
      AccountsCompanion.insert(name: 'Personal', kind: 'personal'),
    );
    await db.createWallet(
      accountId: accountId,
      name: 'Cash',
      kind: 'cash',
      initialAmount: 100000,
    );
    await db.createWallet(
      accountId: accountId,
      name: 'BCA',
      kind: 'bank',
      initialAmount: 200000,
    );
    await db.addCategory(
      CategoriesCompanion.insert(name: 'Transfer', kind: 'transfer'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () =>
                      showSnackSheet(context, (_) => const TransferSheet()),
                  child: const Text('open transfer'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open transfer'));
    await tester.pumpAndSettle();

    // Two wallets available; From defaults to Cash, To to BCA.
    expect(find.textContaining('Cash'), findsWidgets);
    expect(find.textContaining('BCA'), findsWidgets);

    await tester.enterText(
      find.descendant(
        of: find.byType(AmountField),
        matching: find.byType(EditableText),
      ),
      '50000',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Transfer'));

    // The DB write lands first; poll until the checkmark pops mid-flight
    // (coin flight ~580ms into the ~1050ms celebration).
    var checkFound = false;
    for (var i = 0; i < 25 && !checkFound; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      checkFound = find.byIcon(Icons.check).evaluate().isNotEmpty;
    }
    expect(checkFound, isTrue);

    // Let the celebration finish so no timers are pending at teardown.
    await tester.pump(const Duration(milliseconds: 1500));

    // Exactly one transfer was recorded (no double-save).
    final now = DateTime.now();
    final txs = await db.getTransactionsInRange(
      now.subtract(const Duration(days: 1)),
      now.add(const Duration(days: 1)),
    );
    expect(txs.where((t) => t.transaction.kind == 'transfer').length, 1);

    await db.close();
  });
}
