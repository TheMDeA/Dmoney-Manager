import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dmoney_manager/data/database/app_database.dart';

/// Description autocomplete: distinct past descriptions matching the typed
/// text, ranked by frequency then recency, carrying the category/wallet of
/// their most recent use.
void main() {
  late AppDatabase db;
  late int wallet;
  late int otherWallet;
  late int food;
  late int transport;
  late int salary;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final account = await db.addAccount(AccountsCompanion.insert(
        name: 'Personal', kind: 'personal', colorHex: const Value('#FF0000')));
    wallet = await db.createWallet(
        accountId: account, name: 'Cash', kind: 'cash', initialAmount: 1000);
    otherWallet = await db.createWallet(
        accountId: account, name: 'Bank', kind: 'bank', initialAmount: 1000);
    food = await db.addCategory(
        CategoriesCompanion.insert(name: 'Food', kind: 'expense'));
    transport = await db.addCategory(
        CategoriesCompanion.insert(name: 'Transport', kind: 'expense'));
    salary = await db.addCategory(
        CategoriesCompanion.insert(name: 'Salary', kind: 'income'));
  });

  tearDown(() => db.close());

  Future<void> tx(String note, String kind, int categoryId,
          {int? walletId, int daysAgo = 0}) =>
      db.addTransaction(TransactionsCompanion.insert(
        walletId: walletId ?? wallet,
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

  test('matches case-insensitively on contains', () async {
    await tx('Starbucks Coffee', 'expense', food);
    final lower = await db.suggestDescriptions('star', kind: 'expense');
    expect(lower.map((s) => s.note), ['Starbucks Coffee']);
    final upper = await db.suggestDescriptions('COFFEE', kind: 'expense');
    expect(upper.map((s) => s.note), ['Starbucks Coffee']);
  });

  test('only matches the requested kind', () async {
    await tx('Payday', 'income', salary);
    expect(await db.suggestDescriptions('pay', kind: 'expense'), isEmpty);
    final income = await db.suggestDescriptions('pay', kind: 'income');
    expect(income.map((s) => s.note), ['Payday']);
  });

  test('ignores empty notes', () async {
    await tx('', 'expense', food);
    await tx('Coffee', 'expense', food);
    final out = await db.suggestDescriptions('o', kind: 'expense');
    expect(out.map((s) => s.note), ['Coffee']);
  });

  test('ranks by frequency, then recency', () async {
    await tx('Tea', 'expense', food, daysAgo: 0);
    await tx('Coffee', 'expense', food, daysAgo: 5);
    await tx('Coffee', 'expense', food, daysAgo: 4);
    await tx('Coffee', 'expense', food, daysAgo: 3);
    final out = await db.suggestDescriptions('e', kind: 'expense');
    expect(out.map((s) => s.note), ['Coffee', 'Tea']);
  });

  test('recency breaks frequency ties', () async {
    await tx('Old Mart', 'expense', food, daysAgo: 9);
    await tx('New Mart', 'expense', food, daysAgo: 1);
    final out = await db.suggestDescriptions('mart', kind: 'expense');
    expect(out.map((s) => s.note), ['New Mart', 'Old Mart']);
  });

  test('prefix matches come before contains matches', () async {
    await tx('Iced Coffee', 'expense', food, daysAgo: 0);
    await tx('Iced Coffee', 'expense', food, daysAgo: 0);
    await tx('Coffee Bean', 'expense', food, daysAgo: 0);
    final out = await db.suggestDescriptions('cof', kind: 'expense');
    expect(out.first.note, 'Coffee Bean');
  });

  test('carries the category/wallet of the most recent use', () async {
    await tx('Coffee', 'expense', transport,
        walletId: otherWallet, daysAgo: 10);
    await tx('Coffee', 'expense', food, daysAgo: 1);
    final out = await db.suggestDescriptions('cof', kind: 'expense');
    expect(out.single.categoryId, food);
    expect(out.single.walletId, wallet);
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
    final out = await db.suggestDescriptions('100%', kind: 'expense');
    expect(out.map((s) => s.note), ['100% juice']);
  });
}
