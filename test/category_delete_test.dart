import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dmoney_manager/data/database/app_database.dart';

/// Category deletion must never orphan history: deleting a category
/// reassigns its transactions, budgets, recurring rules and templates
/// to the 'Uncategorized' fallback, so they stay visible in every
/// joined list. Regression test for the round-2 audit finding where
/// the old delete dropped the category rows and the inner joins in
/// _joinedTransactions silently hid every affected transaction.
void main() {
  late AppDatabase db;
  late int walletId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final account = await db.addAccount(AccountsCompanion.insert(
        name: 'Personal', kind: 'personal', colorHex: const Value('#FF0000')));
    walletId = await db.createWallet(
        accountId: account, name: 'Bank', kind: 'bank', initialAmount: 0);
  });

  tearDown(() => db.close());

  Future<int> addCategory(String name,
      {String kind = 'expense', int? parentId}) {
    return db.addCategory(CategoriesCompanion.insert(
      name: name,
      kind: kind,
      parentId: Value(parentId),
    ));
  }

  Future<int> addTx(int categoryId, int amount) {
    return db.addTransaction(TransactionsCompanion.insert(
      walletId: walletId,
      categoryId: categoryId,
      kind: 'expense',
      amount: amount,
      date: DateTime(2026, 10, 24),
    ));
  }

  test('deleting a parent reassigns its and its subcategories rows',
      () async {
    final parent = await addCategory('Food');
    final sub = await addCategory('Snacks', parentId: parent);
    final other = await addCategory('Transport');
    final txParent = await addTx(parent, 5000);
    final txSub = await addTx(sub, 2000);
    final txOther = await addTx(other, 3000);
    final budget = await db.addBudget(BudgetsCompanion.insert(
        categoryId: parent, month: '2026-10', limit: 100000));
    final rule = await db.into(db.recurringTransactions).insert(
        RecurringTransactionsCompanion.insert(
            walletId: walletId,
            categoryId: parent,
            kind: 'expense',
            amount: 1000,
            frequency: 'monthly',
            nextDue: DateTime(2026, 11, 1)));
    final template = await db.into(db.transactionTemplates).insert(
        TransactionTemplatesCompanion.insert(
            name: 'Lunch',
            walletId: walletId,
            categoryId: sub,
            kind: 'expense',
            amount: 15000));

    await db.deleteCategory(parent);

    // Category rows are gone.
    final remaining = await db.allCategories();
    expect(remaining.map((c) => c.id), isNot(contains(parent)));
    expect(remaining.map((c) => c.id), isNot(contains(sub)));

    // The fallback exists and everything now points at it.
    final fallbackId = await db.uncategorizedCategoryId;
    final fallback = remaining.firstWhere((c) => c.id == fallbackId);
    expect(fallback.name, 'Uncategorized');
    expect(fallback.kind, 'uncategorized');

    // Transactions survive AND stay visible through the joined query
    // (the old code made them vanish from every list).
    final visible = await db.watchTransactions().first;
    final visibleIds = visible.map((t) => t.transaction.id).toSet();
    expect(visibleIds, containsAll([txParent, txSub, txOther]));
    for (final t in visible.where((t) =>
        t.transaction.id == txParent || t.transaction.id == txSub)) {
      expect(t.transaction.categoryId, fallbackId);
      expect(t.category.name, 'Uncategorized');
    }
    final untouched =
        visible.firstWhere((t) => t.transaction.id == txOther);
    expect(untouched.transaction.categoryId, other);

    // Budgets, rules and templates followed the transactions.
    final budgetRow =
        await (db.select(db.budgets)..where((b) => b.id.equals(budget)))
            .getSingle();
    expect(budgetRow.categoryId, fallbackId);
    final ruleRow = await (db.select(db.recurringTransactions)
          ..where((r) => r.id.equals(rule)))
        .getSingle();
    expect(ruleRow.categoryId, fallbackId);
    final templateRow = await (db.select(db.transactionTemplates)
          ..where((t) => t.id.equals(template)))
        .getSingle();
    expect(templateRow.categoryId, fallbackId);
  });

  test('deleting a subcategory reassigns only its own rows', () async {
    final parent = await addCategory('Food');
    final sub = await addCategory('Snacks', parentId: parent);
    final txParent = await addTx(parent, 5000);
    final txSub = await addTx(sub, 2000);

    await db.deleteCategory(sub);

    final fallbackId = await db.uncategorizedCategoryId;
    final visible = await db.watchTransactions().first;
    expect(
        visible
            .firstWhere((t) => t.transaction.id == txSub)
            .transaction
            .categoryId,
        fallbackId);
    expect(
        visible
            .firstWhere((t) => t.transaction.id == txParent)
            .transaction
            .categoryId,
        parent);
    expect(
        (await db.allCategories()).map((c) => c.id), contains(parent));
  });

  test('deleting the fallback itself is a no-op', () async {
    final fallbackId = await db.uncategorizedCategoryId;
    final tx = await addTx(fallbackId, 1000);

    await db.deleteCategory(fallbackId);

    expect((await db.allCategories()).map((c) => c.id),
        contains(fallbackId));
    final visible = await db.watchTransactions().first;
    expect(
        visible
            .firstWhere((t) => t.transaction.id == tx)
            .transaction
            .categoryId,
        fallbackId);
  });
}
