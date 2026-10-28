import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/utils/formatters.dart';
import 'package:dmoney_manager/core/widgets/amount_field.dart';
import 'package:dmoney_manager/data/database/app_database.dart';
import 'package:dmoney_manager/features/transactions/add_transaction_sheet.dart';
import 'package:dmoney_manager/state/providers.dart';

/// Session sticky date: within one app launch the add sheet reopens on the
/// last saved transaction's date; a fresh launch starts on today again.
/// The provider is deliberately not persisted, so these tests seed it
/// through a parent container instead of prefs.
void main() {
  test('notifier strips the time, keeping the date only', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(lastTransactionDateProvider.notifier)
        .set(DateTime(2026, 4, 10, 21, 50));
    expect(
      container.read(lastTransactionDateProvider),
      DateTime(2026, 4, 10),
    );
  });

  group('add sheet sticky date', () {
    Future<AppDatabase> openDb() async {
      SharedPreferences.setMockInitialValues({});
      await AppPrefs.init();
      await initializeDateFormatting();
      return AppDatabase.forTesting(NativeDatabase.memory());
    }

    Future<int> makeWallet(
      AppDatabase db,
      String name,
      String kind,
    ) =>
        db.createWallet(accountId: 1, name: name, kind: kind);

    Future<int> foodId(AppDatabase db) async {
      final cats = await db.select(db.categories).get();
      return cats.firstWhere((c) => c.name == 'Food').id;
    }

    Future<void> pumpSheet(
      WidgetTester tester,
      AppDatabase db,
      ProviderContainer container, {
      int? walletId,
      DateTime? initialDate,
      TransactionWithDetails? existing,
    }) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              home: Scaffold(
                body: AddTransactionSheet(
                  initialKind: 'expense',
                  initialWalletId: walletId,
                  initialDate: initialDate,
                  existing: existing,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> fillAndSave(
      WidgetTester tester, {
      required String desc,
      required String amount,
    }) async {
      final descField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'What was this for?',
      );
      await tester.enterText(descField, desc);
      await tester.pump();
      final amountField = find.descendant(
        of: find.byType(AmountField),
        matching: find.byType(TextField),
      );
      await tester.enterText(amountField, amount);
      await tester.pump();
      await tester.ensureVisible(find.text('All'));
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Food'));
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
    }

    Future<void> disposeTrap(WidgetTester tester) async {
      // Drift schedules a zero-duration cleanup timer when a
      // StreamBuilder is disposed; drain it so it can't leak into the
      // next test.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('sheet opens on the sticky date with a Today button',
        (tester) async {
      final db = await openDb();
      final bankId = await makeWallet(db, 'Jago', 'bank');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(lastTransactionDateProvider.notifier)
          .set(DateTime(2026, 4, 10, 21, 50));
      await pumpSheet(tester, db, container, walletId: bankId);
      expect(tester.takeException(), isNull);

      expect(find.text('10 Apr 2026'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);

      await tester.ensureVisible(find.text('Today'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pump();
      expect(find.text(formatDate(DateTime.now())), findsOneWidget);
      expect(find.text('Today'), findsNothing);
      await disposeTrap(tester);
    });

    testWidgets('explicit initialDate wins over the sticky date',
        (tester) async {
      final db = await openDb();
      final bankId = await makeWallet(db, 'Jago', 'bank');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(lastTransactionDateProvider.notifier)
          .set(DateTime(2026, 4, 10));
      await pumpSheet(
        tester,
        db,
        container,
        walletId: bankId,
        initialDate: DateTime(2026, 6, 5),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('05 Jun 2026'), findsOneWidget);
      await disposeTrap(tester);
    });

    testWidgets('saving a new transaction sets the sticky date',
        (tester) async {
      final db = await openDb();
      final bankId = await makeWallet(db, 'Jago', 'bank');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await pumpSheet(
        tester,
        db,
        container,
        walletId: bankId,
        initialDate: DateTime(2026, 4, 10),
      );
      expect(tester.takeException(), isNull);

      await fillAndSave(tester, desc: 'Sticky test', amount: '50000');

      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(1));
      expect(
        container.read(lastTransactionDateProvider),
        DateTime(2026, 4, 10),
      );
      await disposeTrap(tester);
    });

    testWidgets('editing does not move the sticky date', (tester) async {
      final db = await openDb();
      final bankId = await makeWallet(db, 'Jago', 'bank');
      final food = await foodId(db);
      final txId = await db.addTransaction(
        TransactionsCompanion.insert(
          walletId: bankId,
          categoryId: food,
          kind: 'expense',
          amount: 100000,
          note: const Value('Old desc'),
          memo: const Value(''),
          date: DateTime(2026, 1, 5),
        ),
      );
      final existing = await db.getTransactionDetailById(txId);
      expect(existing, isNotNull);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(lastTransactionDateProvider.notifier)
          .set(DateTime(2026, 4, 10));
      await pumpSheet(tester, db, container, existing: existing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Save changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      expect(
        container.read(lastTransactionDateProvider),
        DateTime(2026, 4, 10),
      );
      await disposeTrap(tester);
    });
  });
}
