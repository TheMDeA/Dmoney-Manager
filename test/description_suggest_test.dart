import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dmoney_manager/data/database/app_database.dart';

/// Description autocomplete: distinct past descriptions *starting with* the
/// typed text (case-insensitive), ranked by frequency then recency.
void main() {
  late AppDatabase db;
  late int wallet;
  late int food;
  late int salary;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final account = await db.addAccount(AccountsCompanion.insert(
        name: 'Personal', kind: 'personal', colorHex: const Value('#FF0000')));
    wallet = await db.createWallet(
        accountId: account, name: 'Cash', kind: 'cash', initialAmount: 1000);
    food = await db.addCategory(
        CategoriesCompanion.insert(name: 'Food', kind: 'expense'));
    salary = await db.addCategory(
        CategoriesCompanion.insert(name: 'Salary', kind: 'income'));
  });

  tearDown(() => db.close());

  Future<void> tx(String note, String kind, int categoryId,
          {int daysAgo = 0}) =>
      db.addTransaction(TransactionsCompanion.insert(
        walletId: wallet,
        categoryId: categoryId,
        kind: kind,
        amount: 100,
        date: DateTime.now().subtract(Duration(days: daysAgo)),
        note: Value(note),
      ));

  test('empty query returns nothing', () async {
    await tx('Coffee', 'expense', food);
    expect(await db.suggestDescriptions('', kind: 'expense'), isEmpty);
    expect(await db.suggestDescriptions('   ', kind: 'expense'), isEmpty);
  });

  test('only prefix matches are suggested', () async {
    await tx('Awa fried chicken', 'expense', food);
    // Both merely contain 'aw' mid-string; neither starts with it.
    await tx('soto Betawi', 'expense', food);
    await tx('tws huawei', 'expense', food);
    expect(await db.suggestDescriptions('aw', kind: 'expense'),
        ['Awa fried chicken']);
  });

  test('matches case-insensitively', () async {
    await tx('Starbucks Coffee', 'expense', food);
    expect(await db.suggestDescriptions('STAR', kind: 'expense'),
        ['Starbucks Coffee']);
  });

  test('only matches the requested kind', () async {
    await tx('Payday', 'income', salary);
    expect(await db.suggestDescriptions('pay', kind: 'expense'), isEmpty);
    expect(await db.suggestDescriptions('pay', kind: 'income'), ['Payday']);
  });

  test('ignores empty notes', () async {
    await tx('', 'expense', food);
    await tx('Coffee', 'expense', food);
    expect(await db.suggestDescriptions('c', kind: 'expense'), ['Coffee']);
  });

  test('ranks by frequency, then recency', () async {
    await tx('Cake', 'expense', food, daysAgo: 0);
    await tx('Coffee', 'expense', food, daysAgo: 5);
    await tx('Coffee', 'expense', food, daysAgo: 4);
    await tx('Coffee', 'expense', food, daysAgo: 3);
    expect(
        await db.suggestDescriptions('c', kind: 'expense'), ['Coffee', 'Cake']);
  });

  test('recency breaks frequency ties', () async {
    await tx('Mart Old', 'expense', food, daysAgo: 9);
    await tx('Mart New', 'expense', food, daysAgo: 1);
    expect(await db.suggestDescriptions('mart', kind: 'expense'),
        ['Mart New', 'Mart Old']);
  });

  test('respects the limit', () async {
    for (var i = 0; i < 10; i++) {
      await tx('Shop $i', 'expense', food);
    }
    final out =
        await db.suggestDescriptions('shop', kind: 'expense', limit: 3);
    expect(out.length, 3);
  });

  test('LIKE wildcards in the query match literally', () async {
    await tx('100% juice', 'expense', food);
    await tx('1000 juice', 'expense', food);
    expect(await db.suggestDescriptions('100%', kind: 'expense'),
        ['100% juice']);
  });
}
