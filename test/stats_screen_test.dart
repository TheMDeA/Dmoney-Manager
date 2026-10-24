import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/data/database/app_database.dart';
import 'package:dmoney_manager/features/stats/stats_screen.dart';
import 'package:dmoney_manager/state/providers.dart';

/// Smoke test for the Stats stream restructure (audit #1): the screen
/// hoists its query streams into state and shares two of them between
/// sections (broadcast). This pumps the real screen over an in-memory
/// DB, then shifts the month — which rebinds every stream — and makes
/// sure everything renders without a double-subscription or a crash.
///
/// The month shift is invoked through the button's onPressed rather
/// than a gesture tap: in this sandbox the gesture + haptics path
/// stalls the fake-async test zone after a stream rebind.
void main() {
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final account = await db.addAccount(AccountsCompanion.insert(
        name: 'Personal', kind: 'personal', colorHex: const Value('#FF0000')));
    final walletId = await db.createWallet(
        accountId: account, name: 'Bank', kind: 'bank', initialAmount: 100000);
    final expenseCat = await (db.select(db.categories)
          ..where((c) => c.kind.equals('expense'))
          ..limit(1))
        .getSingle();
    await db.addTransaction(TransactionsCompanion.insert(
      walletId: walletId,
      categoryId: expenseCat.id,
      kind: 'expense',
      amount: 25000,
      date: DateTime.now(),
    ));
  });

  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('stats renders all sections and survives a month shift',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: StatsScreen()),
    ));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Spending by category'), findsOneWidget);
    expect(find.text('Net worth'), findsOneWidget);

    // Month shift rebinds every stream (new month key) — must not throw
    // and must keep rendering.
    tester
        .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right))
        .onPressed!();
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Spending by category'), findsOneWidget);

    tester
        .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left))
        .onPressed!();
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Net worth'), findsOneWidget);

    // Unmount inside the test and pump once: disposing a StreamBuilder
    // makes drift schedule a zero-duration cleanup timer, and the
    // harness fails the test if any timer is still pending when IT
    // disposes the tree after the body.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
