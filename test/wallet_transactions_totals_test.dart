import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/data/database/app_database.dart';
import 'package:dmoney_manager/features/transactions/widgets/grouped_transaction_list.dart';
import 'package:dmoney_manager/features/wallets/wallet_detail_screen.dart';
import 'package:dmoney_manager/state/providers.dart';

/// Transfers in the wallet transactions view count toward the wallet's
/// overview and day nets from that wallet's point of view — a transfer
/// in is income-side, a transfer out is expense-side (the reference
/// behavior Miko compared against: Jago income Rp 704.578 becomes
/// Rp 15.704.578 once the Rp 15.000.000 transfer in counts). The global
/// history keeps transfers neutral; that path is the grouped list
/// without a perspective wallet.
void main() {
  Future<AppDatabase> openDb() async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
    await initializeDateFormatting();
    return AppDatabase.forTesting(NativeDatabase.memory());
  }

  /// Livin (source) and Jago (destination): Jago gets Rp 704.578 income
  /// plus a Rp 15.000.000 transfer in; Livin gets a Rp 100.000 expense
  /// on top of the transfer out. All dated now (the screens open on the
  /// current month).
  Future<({int livin, int jago})> fixture(AppDatabase db) async {
    final livin = await db.createWallet(
        accountId: 1, name: 'Livin Mandiri', kind: 'bank');
    final jago =
        await db.createWallet(accountId: 1, name: 'Jago', kind: 'bank');
    final cats = await db.select(db.categories).get();
    final catId = cats.first.id;
    final now = DateTime.now();
    await db.addTransaction(TransactionsCompanion.insert(
      walletId: jago,
      categoryId: catId,
      kind: 'income',
      amount: 704578,
      date: now,
    ));
    await db.addTransaction(TransactionsCompanion.insert(
      walletId: livin,
      categoryId: catId,
      kind: 'expense',
      amount: 100000,
      date: now,
    ));
    await db.addTransfer(
      fromWalletId: livin,
      toWalletId: jago,
      amount: 15000000,
      date: now,
    );
    return (livin: livin, jago: jago);
  }


  /// First emission of the wallet's current-month items. Must run in a
  /// real-async zone: a drift stream never delivers inside the fake
  /// async of testWidgets without pumping.
  Future<List<TransactionWithDetails>> monthItems(
      WidgetTester tester, AppDatabase db, int walletId) async {
    final now = DateTime.now();
    final items = await tester.runAsync(
      () => db
          .watchTransactionsForWalletInRange(
            walletId,
            DateTime(now.year, now.month),
            DateTime(now.year, now.month + 1),
          )
          .first,
    );
    return items!;
  }

  Widget host(AppDatabase db, Widget child) => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );

  Future<void> pumpScreen(
      WidgetTester tester, AppDatabase db, int walletId, String name) async {
    await tester.pumpWidget(host(
      db,
      WalletTransactionsScreen(walletId: walletId, walletName: name),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }

  Future<void> disposeTrap(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('destination wallet: transfer in counts toward income',
      (tester) async {
    final db = await openDb();
    final f = await fixture(db);
    await pumpScreen(tester, db, f.jago, 'Jago');

    // Overview income folds the transfer in (704.578 + 15.000.000);
    // the bare income figure no longer appears.
    expect(find.text('Rp 15.704.578'), findsOneWidget);
    expect(find.text('Rp 704.578'), findsNothing);
    await disposeTrap(tester);
  });

  testWidgets('source wallet: transfer out counts toward expense',
      (tester) async {
    final db = await openDb();
    final f = await fixture(db);
    await pumpScreen(tester, db, f.livin, 'Livin Mandiri');

    // 100.000 of expenses + the 15.000.000 transfer out. The figure
    // shows on the expense row, the total row, and the day header.
    expect(find.text('-Rp 15.100.000'), findsWidgets);
    expect(find.text('Rp 0'), findsOneWidget); // income untouched
    await disposeTrap(tester);
  });

  testWidgets('grouped list without perspective: day net ignores transfers',
      (tester) async {
    final db = await openDb();
    final f = await fixture(db);
    final items = await monthItems(tester, db, f.jago);
    expect(items, hasLength(2)); // income + transfer in

    await tester.pumpWidget(host(
      db,
      Scaffold(body: GroupedTransactionList(items: items)),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Day net is just the income; the transfer-inclusive total is absent.
    expect(find.text('+Rp 704.578'), findsWidgets);
    expect(find.text('+Rp 15.704.578'), findsNothing);
    await disposeTrap(tester);
  });

  testWidgets('grouped list with perspective: day net counts the transfer',
      (tester) async {
    final db = await openDb();
    final f = await fixture(db);
    final items = await monthItems(tester, db, f.jago);

    await tester.pumpWidget(host(
      db,
      Scaffold(
        body: GroupedTransactionList(
          items: items,
          perspectiveWalletId: f.jago,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('+Rp 15.704.578'), findsWidgets);
    await disposeTrap(tester);
  });
}
