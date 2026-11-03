import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/data/database/app_database.dart';
import 'package:dmoney_manager/features/wallets/adjust_balance_sheet.dart';
import 'package:dmoney_manager/state/providers.dart';

/// Adjust Balance on paylater wallets: a paylater balance is the signed
/// negation of the debt (owing Rp 2.000.000 is stored as -2000000), so
/// the sheet edits owed wallets in "owed space" — the field holds the
/// positive outstanding amount and the saved target balance is its
/// negation. Before the fix the sheet prefilled the raw negative
/// balance, the amount parser stripped the minus sign, and the sheet
/// opened with a phantom difference that flipped the debt into an
/// overpayment on save.
void main() {
  Future<AppDatabase> openDb() async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
    await initializeDateFormatting();
    return AppDatabase.forTesting(NativeDatabase.memory());
  }

  Future<int> makeWallet(
    AppDatabase db,
    String kind,
    int balance,
  ) =>
      db.createWallet(
        accountId: 1,
        name: 'W',
        kind: kind,
        initialAmount: balance,
      );

  Future<void> pumpSheet(
    WidgetTester tester,
    AppDatabase db,
    Wallet wallet,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => AdjustBalanceSheet.show(context, wallet),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  }

  Future<void> disposeTrap(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<List<Transaction>> walletTxs(AppDatabase db, int walletId) async =>
      (await db.select(db.transactions).get())
          .where((t) => t.walletId == walletId)
          .toList();

  testWidgets('paylater owed: opens in owed space, no phantom difference',
      (tester) async {
    final db = await openDb();
    final id = await makeWallet(db, 'paylater', -2000000);
    final wallet = await db.getWalletById(id);
    await pumpSheet(tester, db, wallet!);

    // The field holds the positive outstanding amount, not -2.000.000,
    // and the untouched sheet is a no-op (Done disabled).
    expect(fieldText(tester), '2.000.000');
    expect(find.text('Current outstanding'), findsOneWidget);
    expect(find.text('New outstanding'), findsOneWidget);
    expect(find.text('Rp 2.000.000'), findsOneWidget);
    expect(find.text('No change'), findsOneWidget);
    final done = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Done'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(done.onPressed, isNull);
    await disposeTrap(tester);
  });

  testWidgets('paylater owed: saving a larger debt negates the target',
      (tester) async {
    final db = await openDb();
    final id = await makeWallet(db, 'paylater', -2000000);
    final wallet = await db.getWalletById(id);
    await pumpSheet(tester, db, wallet!);

    await tester.enterText(find.byType(TextField), '2500000');
    await tester.pump();
    await save(tester);

    expect((await db.getWalletById(id))!.balance, -2500000);
    final txs = await walletTxs(db, id);
    expect(txs, hasLength(1));
    expect(txs.single.kind, 'expense');
    expect(txs.single.amount, 500000);
    await disposeTrap(tester);
  });

  testWidgets('paylater owed: paying down via change-initial, no transaction',
      (tester) async {
    final db = await openDb();
    final id = await makeWallet(db, 'paylater', -2000000);
    final wallet = await db.getWalletById(id);
    await pumpSheet(tester, db, wallet!);

    await tester.ensureVisible(find.text('Change initial amount'));
    await tester.tap(find.text('Change initial amount'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '1500000');
    await tester.pump();
    await save(tester);

    expect((await db.getWalletById(id))!.balance, -1500000);
    expect(await walletTxs(db, id), isEmpty);
    await disposeTrap(tester);
  });

  testWidgets('paylater overpaid: plain balance editing still applies',
      (tester) async {
    final db = await openDb();
    final id = await makeWallet(db, 'paylater', 300000);
    final wallet = await db.getWalletById(id);
    await pumpSheet(tester, db, wallet!);

    expect(fieldText(tester), '300.000');
    expect(find.text('Current balance'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '200000');
    await tester.pump();
    await save(tester);

    expect((await db.getWalletById(id))!.balance, 200000);
    await disposeTrap(tester);
  });

  testWidgets('normal wallet: unchanged behavior', (tester) async {
    final db = await openDb();
    final id = await makeWallet(db, 'bank', 1000000);
    final wallet = await db.getWalletById(id);
    await pumpSheet(tester, db, wallet!);

    expect(fieldText(tester), '1.000.000');
    expect(find.text('No change'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '900000');
    await tester.pump();
    await save(tester);

    expect((await db.getWalletById(id))!.balance, 900000);
    final txs = await walletTxs(db, id);
    expect(txs, hasLength(1));
    expect(txs.single.kind, 'expense');
    expect(txs.single.amount, 100000);
    await disposeTrap(tester);
  });
}
