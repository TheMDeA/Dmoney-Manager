import 'package:drift/drift.dart' show Value;
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

/// The Next due card used to show the wallet's FULL outstanding with
/// "Mark as paid" whenever the wallet had more than one plan — even
/// though only some installments fall due on that date. It now sums
/// the installments due together that day and pays exactly those.
/// These tests reproduce the reported two-plan wallet.
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
      expect(
        s,
        contains('ListTile'),
        reason: 'unexpected exception while pumping the dashboard',
      );
    }
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<(AppDatabase, int, int)> pumpDashboard(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
    await initializeDateFormatting();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final walletId = await db.createWallet(
      accountId: 1,
      name: 'Tiktok Paylater',
      kind: 'paylater',
      initialAmount: 0,
    );
    await (db.update(db.wallets)..where((w) => w.id.equals(walletId))).write(
      const WalletsCompanion(dueDay: Value(2)),
    );
    final payerId = await db.createWallet(
      accountId: 1,
      name: 'Bank',
      kind: 'bank',
      initialAmount: 5000000,
    );
    final categoryId = await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'Shopping', kind: 'expense'));
    await db.addPlanWithPurchase(
      walletId: walletId,
      name: 'Tas Bodypack Neos',
      totalAmount: 568686,
      installmentAmount: 284343,
      totalCount: 2,
      categoryId: categoryId,
    );
    await db.addPlanWithPurchase(
      walletId: walletId,
      name: 'ensure gold mama',
      totalAmount: 386100,
      installmentAmount: 386100,
      totalCount: 1,
      categoryId: categoryId,
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
    return (db, walletId, payerId);
  }

  testWidgets('card shows the installments due together, not the total', (
    tester,
  ) async {
    await pumpDashboard(tester);
    // 284.343 (Neos #1) + 386.100 (ensure) fall due on the 2nd; the
    // second Neos installment does not — so the card must not claim
    // the full 954.786 outstanding is due.
    expect(find.textContaining('670.443'), findsWidgets);
    expect(find.text('Pay installments'), findsOneWidget);
    expect(find.text('Mark as paid'), findsNothing);
    await teardown(tester);
  });

  testWidgets('paying pays both plans due, advancing each counter', (
    tester,
  ) async {
    final (db, walletId, _) = await pumpDashboard(tester);
    await tester.tap(find.text('Pay installments'));
    await settle(tester);
    // Payer picker: choose the bank wallet.
    await tester.tap(find.text('Bank').last);
    await settle(tester);

    final plans = await tester.runAsync(() => db.plansForWallet(walletId));
    expect(plans!.map((p) => p.paidCount), [1, 1]);
    // Both transfers are plan-linked installment payments.
    final txs = await tester.runAsync(
      () => (db.select(
        db.transactions,
      )..where((t) => t.kind.equals('transfer'))).get(),
    );
    expect(txs, hasLength(2));
    expect(txs!.every((t) => t.planId != null), isTrue);
    expect(txs.fold<int>(0, (s, t) => s + t.amount), 670443);
    // Only the not-yet-due Neos installment remains outstanding.
    final wallet = await tester.runAsync(() => db.getWalletById(walletId));
    expect(wallet!.balance, -284343);
    await teardown(tester);
  });
}
