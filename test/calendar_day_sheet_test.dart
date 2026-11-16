import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/data/database/app_database.dart';
import 'package:dmoney_manager/features/calendar/calendar_screen.dart';
import 'package:dmoney_manager/state/providers.dart';

/// The day sheet used to read the grid's frozen snapshot: edits made
/// from inside it never showed up, and flipping past the 42-day grid
/// showed "No transactions" for days that have transactions. It now
/// subscribes to its own day's range live.
void main() {
  Future<AppDatabase> openDb() async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
    await initializeDateFormatting();
    return AppDatabase.forTesting(NativeDatabase.memory());
  }

  /// One expense on the 1st of the current month (first grid row, always
  /// visible) and one on the day just before the grid starts — outside
  /// the 42-day range the old snapshot covered.
  Future<({int walletId, int categoryId, int firstTxId})> fixture(
    AppDatabase db,
  ) async {
    final walletId = await db.createWallet(
      accountId: 1,
      name: 'Jago',
      kind: 'bank',
    );
    final cats = await db.select(db.categories).get();
    final categoryId = cats.first.id;
    final now = DateTime.now();
    final first = DateTime(now.year, now.month);
    final gridStart = first.subtract(Duration(days: first.weekday % 7));
    final firstTxId = await db.addTransaction(
      TransactionsCompanion.insert(
        walletId: walletId,
        categoryId: categoryId,
        kind: 'expense',
        amount: 100000,
        note: const Value('Sheet lunch'),
        date: DateTime(first.year, first.month, 1, 12),
      ),
    );
    await db.addTransaction(
      TransactionsCompanion.insert(
        walletId: walletId,
        categoryId: categoryId,
        kind: 'expense',
        amount: 50000,
        note: const Value('Outside grid'),
        date: DateTime(
          gridStart.year,
          gridStart.month,
          gridStart.day,
          12,
        ).subtract(const Duration(days: 1)),
      ),
    );
    return (walletId: walletId, categoryId: categoryId, firstTxId: firstTxId);
  }

  Widget host(AppDatabase db) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CalendarScreen(),
    ),
  );

  /// Streams deliver on real async; a few small pumps let the grid and
  /// the sheet subscribe and render.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump();
  }

  Future<void> disposeTrap(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Opens the sheet on the 1st of the current month — the cell label
  /// is "M/1", unique in the grid, and always in the first row.
  Future<void> openFirstOfMonth(WidgetTester tester) async {
    final now = DateTime.now();
    final label = '${now.month}/1';
    expect(find.text(label), findsOneWidget);
    await tester.tap(find.text(label));
    await settle(tester);
  }

  testWidgets('day sheet refreshes after an edit', (tester) async {
    final db = await openDb();
    final f = await fixture(db);
    await tester.pumpWidget(host(db));
    await settle(tester);
    await openFirstOfMonth(tester);

    // The row and the sheet net both show the original amount.
    expect(find.text('Sheet lunch'), findsOneWidget);
    expect(find.text('-Rp 100.000'), findsWidgets);

    // Edit the amount through the same database the sheet watches.
    final now = DateTime.now();
    await tester.runAsync(
      () => db.updateTransaction(
        id: f.firstTxId,
        walletId: f.walletId,
        categoryId: f.categoryId,
        kind: 'expense',
        amount: 250000,
        note: 'Sheet lunch',
        date: DateTime(now.year, now.month, 1, 12),
      ),
    );
    await settle(tester);

    // Both the row and the net follow the edit; the old figure is gone.
    expect(find.text('Sheet lunch'), findsOneWidget);
    expect(find.text('-Rp 250.000'), findsWidgets);
    expect(find.text('-Rp 100.000'), findsNothing);
    await disposeTrap(tester);
  });

  testWidgets('day sheet shows a day outside the grid', (tester) async {
    final db = await openDb();
    await fixture(db);
    await tester.pumpWidget(host(db));
    await settle(tester);
    await openFirstOfMonth(tester);
    expect(find.text('Sheet lunch'), findsOneWidget);

    // Flip back past the first grid day: the old snapshot had no data
    // there and the sheet showed "No transactions".
    final now = DateTime.now();
    final first = DateTime(now.year, now.month);
    final steps = (first.weekday % 7) + 1;
    for (var i = 0; i < steps; i++) {
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await settle(tester);

    expect(find.text('Outside grid'), findsOneWidget);
    expect(find.text('No transactions yet'), findsNothing);
    await disposeTrap(tester);
  });
}
