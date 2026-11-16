import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dmoney_manager/data/database/app_database.dart';

/// Recurring generation resilience: one broken rule must not block the
/// others. The broken rule here points at a wallet that does not exist;
/// with foreign keys enforced its insert throws, exactly the corruption
/// case that used to abort the whole batch silently at every launch.
void main() {
  late AppDatabase db;
  late int walletId;
  late int paylaterWalletId;
  late int categoryId;
  late int expenseCategoryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
    final account = await db.addAccount(AccountsCompanion.insert(
        name: 'Personal', kind: 'personal', colorHex: const Value('#FF0000')));
    walletId = await db.createWallet(
        accountId: account, name: 'Bank', kind: 'bank', initialAmount: 0);
    paylaterWalletId = await db.createWallet(
        accountId: account,
        name: 'SPayLater',
        kind: 'paylater',
        initialAmount: 0);
    final cat = await (db.select(db.categories)
          ..where((c) => c.kind.equals('income'))
          ..limit(1))
        .getSingle();
    categoryId = cat.id;
    final expenseCat = await (db.select(db.categories)
          ..where((c) => c.kind.equals('expense'))
          ..limit(1))
        .getSingle();
    expenseCategoryId = expenseCat.id;
  });

  tearDown(() => db.close());

  Future<int> addRule({
    required int wallet,
    required DateTime nextDue,
    String kind = 'income',
    int? category,
    String frequency = 'daily',
  }) {
    return db.into(db.recurringTransactions).insert(
          RecurringTransactionsCompanion.insert(
            walletId: wallet,
            categoryId: category ?? categoryId,
            kind: kind,
            amount: 1000,
            frequency: frequency,
            nextDue: nextDue,
          ),
        );
  }

  test('a broken rule does not block valid rules', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    // Poison first, so the valid rule only posts if failures are isolated.
    // Written with FKs off, as legacy data would have been; processing
    // runs with FKs on, like the app.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    final poisonId = await addRule(wallet: 999999, nextDue: yesterday);
    await db.customStatement('PRAGMA foreign_keys = ON');
    final validId = await addRule(wallet: walletId, nextDue: yesterday);

    final generated = await db.processDueRecurringTransactions();

    // Daily rule due yesterday catches up: yesterday + today.
    expect(generated, 2);
    final rows = await (db.select(db.transactions)
          ..where((t) => t.recurringId.equals(validId)))
        .get();
    expect(rows, hasLength(2));
    expect((await db.getWalletById(walletId))!.balance, 2000);

    // The broken rule produced nothing and kept its nextDue (retried and
    // re-logged next launch instead of silently blocking the batch).
    final poisonRows = await (db.select(db.transactions)
          ..where((t) => t.recurringId.equals(poisonId)))
        .get();
    expect(poisonRows, isEmpty);
    final poison = await (db.select(db.recurringTransactions)
          ..where((r) => r.id.equals(poisonId)))
        .getSingle();
    // (Stored dates are second-precision in the DB.)
    expect(poison.nextDue.millisecondsSinceEpoch ~/ 1000,
        yesterday.millisecondsSinceEpoch ~/ 1000);
  });

  test('no due rules generates nothing', () async {
    await addRule(
        wallet: walletId,
        nextDue: DateTime.now().add(const Duration(days: 1)));
    expect(await db.processDueRecurringTransactions(), 0);
  });

  test('income to a paylater wallet never generates', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    // A bad rule created before the form gate existed: monthly income
    // on a paylater wallet. It must post nothing, keep its nextDue, and
    // not block the other rules in the same run.
    final badId = await addRule(
      wallet: paylaterWalletId,
      nextDue: yesterday,
      frequency: 'monthly',
    );
    final validId = await addRule(
      wallet: walletId,
      nextDue: yesterday,
      frequency: 'monthly',
    );
    // A paylater expense rule is legitimate and must still generate.
    final expenseId = await addRule(
      wallet: paylaterWalletId,
      nextDue: yesterday,
      kind: 'expense',
      category: expenseCategoryId,
      frequency: 'monthly',
    );

    final generated = await db.processDueRecurringTransactions();

    // Monthly rules due yesterday post exactly once each.
    expect(generated, 2);

    Future<List<Transaction>> rowsFor(int ruleId) => (db.select(
      db.transactions,
    )..where((t) => t.recurringId.equals(ruleId))).get();

    expect(await rowsFor(badId), isEmpty);
    expect((await rowsFor(validId)), hasLength(1));
    expect((await rowsFor(expenseId)), hasLength(1));
    expect((await db.getWalletById(walletId))!.balance, 1000);
    expect((await db.getWalletById(paylaterWalletId))!.balance, -1000);

    // The bad rule kept its nextDue (retried and re-logged next launch
    // instead of silently dropping occurrences).
    final bad = await (db.select(db.recurringTransactions)
          ..where((r) => r.id.equals(badId)))
        .getSingle();
    // (Stored dates are second-precision in the DB.)
    expect(bad.nextDue.millisecondsSinceEpoch ~/ 1000,
        yesterday.millisecondsSinceEpoch ~/ 1000);
  });
}
