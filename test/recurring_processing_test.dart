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
  late int categoryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
    final account = await db.addAccount(AccountsCompanion.insert(
        name: 'Personal', kind: 'personal', colorHex: const Value('#FF0000')));
    walletId = await db.createWallet(
        accountId: account, name: 'Bank', kind: 'bank', initialAmount: 0);
    final cat = await (db.select(db.categories)
          ..where((c) => c.kind.equals('income'))
          ..limit(1))
        .getSingle();
    categoryId = cat.id;
  });

  tearDown(() => db.close());

  Future<int> addRule({required int wallet, required DateTime nextDue}) {
    return db.into(db.recurringTransactions).insert(
          RecurringTransactionsCompanion.insert(
            walletId: wallet,
            categoryId: categoryId,
            kind: 'income',
            amount: 1000,
            frequency: 'daily',
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
}
