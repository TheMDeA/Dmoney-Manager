import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/utils/cash_basis.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// Cash-basis paylater totals: a paylater purchase is borrowing, not
/// spending — only the money that actually leaves a funding wallet
/// counts, dated when it is paid.
void main() {
  group('cashIncomeOf / cashExpenseOf', () {
    test('normal income and expense count in full', () {
      expect(
        cashIncomeOf(kind: 'income', sourceWalletKind: 'bank', amount: 5000000),
        5000000,
      );
      expect(
        cashExpenseOf(
          kind: 'expense',
          sourceWalletKind: 'bank',
          amount: 100000,
        ),
        100000,
      );
    });

    test('rows on a paylater wallet never count', () {
      expect(
        cashIncomeOf(
          kind: 'income',
          sourceWalletKind: 'paylater',
          amount: 500000,
        ),
        0,
      );
      expect(
        cashExpenseOf(
          kind: 'expense',
          sourceWalletKind: 'paylater',
          amount: 16576880,
        ),
        0,
      );
    });

    test('a transfer into paylater from a funding wallet is spending', () {
      expect(
        cashExpenseOf(
          kind: 'transfer',
          sourceWalletKind: 'bank',
          destWalletKind: 'paylater',
          amount: 5525627,
        ),
        5525627,
      );
      expect(
        cashIncomeOf(
          kind: 'transfer',
          sourceWalletKind: 'bank',
          destWalletKind: 'paylater',
          amount: 5525627,
        ),
        0,
      );
    });

    test('moving debt between paylater wallets is not spending', () {
      expect(
        cashExpenseOf(
          kind: 'transfer',
          sourceWalletKind: 'paylater',
          destWalletKind: 'paylater',
          amount: 1000000,
        ),
        0,
      );
    });

    test('a transfer out of paylater is neither income nor expense', () {
      expect(
        cashExpenseOf(
          kind: 'transfer',
          sourceWalletKind: 'paylater',
          destWalletKind: 'bank',
          amount: 2000000,
        ),
        0,
      );
      expect(
        cashIncomeOf(
          kind: 'transfer',
          sourceWalletKind: 'paylater',
          destWalletKind: 'bank',
          amount: 2000000,
        ),
        0,
      );
    });

    test('a transfer between non-paylater wallets stays neutral', () {
      expect(
        cashExpenseOf(
          kind: 'transfer',
          sourceWalletKind: 'bank',
          destWalletKind: 'ewallet',
          amount: 224484,
        ),
        0,
      );
      expect(
        cashIncomeOf(
          kind: 'transfer',
          sourceWalletKind: 'bank',
          destWalletKind: 'ewallet',
          amount: 224484,
        ),
        0,
      );
    });
  });

  group('cash-basis SQL aggregates', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({});
      await AppPrefs.init();
    });

    tearDown(() => db.close());

    Future<int> makeWallet(String name, String kind, {int accountId = 1}) =>
        db.createWallet(accountId: accountId, name: name, kind: kind);

    Future<int> categoryIdByName(String name) async {
      final cats = await db.select(db.categories).get();
      return cats.firstWhere((c) => c.name == name).id;
    }

    Future<int> addRow({
      required int walletId,
      required int categoryId,
      required String kind,
      required int amount,
      required DateTime date,
      int? planId,
    }) => db.addTransaction(
      TransactionsCompanion.insert(
        walletId: walletId,
        categoryId: categoryId,
        kind: kind,
        amount: amount,
        date: date,
        planId: Value(planId),
      ),
    );

    Future<Transaction> getTx(int id) =>
        (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();

    /// November 2026 fixture. Amounts mirror the real report: a
    /// 16.576.880 paylater purchase, 5.525.627 installments, and the
    /// edge rows around it.
    Future<
      ({
        int jago,
        int shopee,
        int tiktok,
        int food,
        int salary,
        int planId,
        int installmentTxId,
        int unlinkedTxId,
      })
    >
    seedNovember() async {
      final jago = await makeWallet('Jago', 'bank');
      final shopee = await makeWallet('Shopeepaylater', 'paylater');
      final tiktok = await makeWallet('TikTok Paylater', 'paylater');
      await makeWallet('Work BCA', 'bank', accountId: 2);
      final food = await categoryIdByName('Food');
      final salary = await categoryIdByName('Salary');

      // Normal rows.
      await addRow(
        walletId: jago,
        categoryId: food,
        kind: 'expense',
        amount: 100000,
        date: DateTime(2026, 11, 10, 12),
      );
      await addRow(
        walletId: jago,
        categoryId: salary,
        kind: 'income',
        amount: 5000000,
        date: DateTime(2026, 11, 1, 9),
      );

      // The plan purchase: 16.576.880 on the paylater wallet.
      final planId = await db.addInstallmentPlan(
        walletId: shopee,
        name: 'Xiaomi 17 Ultra',
        totalAmount: 16576880,
        installmentAmount: 5525627,
        totalCount: 3,
      );
      await addRow(
        walletId: shopee,
        categoryId: food,
        kind: 'expense',
        amount: 16576880,
        date: DateTime(2026, 11, 11, 4, 55),
        planId: planId,
      );

      // One installment paid in November, one in December.
      final installmentTxId = await db.addTransfer(
        fromWalletId: jago,
        toWalletId: shopee,
        amount: 5525627,
        note: 'Installment payment: Xiaomi 17 Ultra',
        date: DateTime(2026, 11, 20, 12),
        planId: planId,
      );
      await db.addTransfer(
        fromWalletId: jago,
        toWalletId: shopee,
        amount: 5525627,
        note: 'Installment payment: Xiaomi 17 Ultra',
        date: DateTime(2026, 12, 5, 12),
        planId: planId,
      );

      // Edge rows: debt moved between paylater wallets, money moved out
      // of paylater, income landing on paylater.
      await db.addTransfer(
        fromWalletId: shopee,
        toWalletId: tiktok,
        amount: 1000000,
        date: DateTime(2026, 11, 22, 12),
      );
      await db.addTransfer(
        fromWalletId: shopee,
        toWalletId: jago,
        amount: 2000000,
        date: DateTime(2026, 11, 23, 12),
      );
      await addRow(
        walletId: shopee,
        categoryId: salary,
        kind: 'income',
        amount: 500000,
        date: DateTime(2026, 11, 24, 12),
      );

      // An unlinked paydown with a transfer fee.
      final unlinkedTxId = await db.addTransfer(
        fromWalletId: jago,
        toWalletId: shopee,
        amount: 100000,
        date: DateTime(2026, 11, 25, 12),
        fee: 2500,
      );

      // Same-month expense on the second account.
      final workWallets = await (db.select(
        db.wallets,
      )..where((w) => w.accountId.equals(2))).get();
      await addRow(
        walletId: workWallets.first.id,
        categoryId: food,
        kind: 'expense',
        amount: 50000,
        date: DateTime(2026, 11, 12, 12),
      );

      return (
        jago: jago,
        shopee: shopee,
        tiktok: tiktok,
        food: food,
        salary: salary,
        planId: planId,
        installmentTxId: installmentTxId,
        unlinkedTxId: unlinkedTxId,
      );
    }

    DateTime novStart() => DateTime(2026, 11, 1);
    DateTime novEnd() => DateTime(2026, 11, 30, 23, 59, 59, 999);
    DateTime decEnd() => DateTime(2026, 12, 31, 23, 59, 59, 999);

    Map<String, int> kindMap(List<KindTotal> rows) =>
        Map.fromEntries(rows.map((r) => MapEntry(r.kind, r.total)));

    test('watchCashKindTotals counts only cash that moved', () async {
      await seedNovember();
      final rows = await db.watchCashKindTotals(novStart(), novEnd()).first;
      // Income: the 5.000.000 salary only — the 500.000 on the paylater
      // wallet is not money in. Expense: normal 100.000 + November
      // installment 5.525.627 + unlinked paydown 100.000 + fee 2.500 +
      // the second account's 50.000 (unscoped query includes all
      // accounts). The 16.576.880 purchase, the paylater-to-paylater
      // move and the transfer out of paylater are all excluded.
      expect(kindMap(rows), {
        'income': 5000000,
        'expense': 100000 + 5525627 + 100000 + 2500 + 50000,
      });
    });

    test('watchCashKindTotals respects the account filter', () async {
      await seedNovember();
      final account1 = await db
          .watchCashKindTotals(novStart(), novEnd(), accountId: 1)
          .first;
      expect(kindMap(account1), {
        'income': 5000000,
        'expense': 100000 + 5525627 + 100000 + 2500,
      });
      final account2 = await db
          .watchCashKindTotals(novStart(), novEnd(), accountId: 2)
          .first;
      expect(kindMap(account2), {'expense': 50000});
    });

    test('watchCashMonthlyKindTotals splits by month', () async {
      await seedNovember();
      final rows = await db
          .watchCashMonthlyKindTotals(novStart(), decEnd())
          .first;
      final got = rows.map((r) => (r.month, r.kind, r.total)).toSet();
      expect(got, {
        ('2026-11', 'income', 5000000),
        ('2026-11', 'expense', 100000 + 5525627 + 100000 + 2500 + 50000),
        ('2026-12', 'expense', 5525627),
      });
    });

    test('watchCashCategoryExpenseTotals attributes installments', () async {
      final seed = await seedNovember();
      final transferId = await db.transferCategoryId;
      final feeId = await db.feeCategoryId;
      final rows = await db
          .watchCashCategoryExpenseTotals(novStart(), novEnd(), accountId: 1)
          .first;
      final got = Map.fromEntries(
        rows.map((r) => MapEntry(r.categoryId, r.total)),
      );
      // Food: normal 100.000 + the plan installment 5.525.627, which
      // counts under the purchase's category — not the 16.576.880
      // purchase itself, which never appears. The unlinked paydown
      // falls back to the hidden Transfer category, and its fee to the
      // Transfer fee category.
      expect(got, {
        seed.food: 100000 + 5525627,
        transferId: 100000,
        feeId: 2500,
      });
    });

    test('watchCashCategoryKindStats mirrors the cash rule', () async {
      final seed = await seedNovember();
      final transferId = await db.transferCategoryId;
      final feeId = await db.feeCategoryId;
      final expense = await db
          .watchCashCategoryKindStats(
            'expense',
            novStart(),
            novEnd(),
            accountId: 1,
          )
          .first;
      final expenseMap = Map.fromEntries(
        expense.map((r) => MapEntry(r.categoryId, (r.total, r.count))),
      );
      expect(expenseMap, {
        seed.food: (100000 + 5525627, 2),
        transferId: (100000, 1),
        feeId: (2500, 1),
      });
      final income = await db
          .watchCashCategoryKindStats(
            'income',
            novStart(),
            novEnd(),
            accountId: 1,
          )
          .first;
      expect(income, hasLength(1));
      expect(income.first.categoryId, seed.salary);
      expect(income.first.total, 5000000);
      expect(income.first.count, 1);
      // Transfers never appear as their own kind row.
      final transfers = await db
          .watchCashCategoryKindStats(
            'transfer',
            novStart(),
            novEnd(),
            accountId: 1,
          )
          .first;
      expect(transfers, isEmpty);
    });

    test('planPurchaseCategories maps plan to purchase category', () async {
      final seed = await seedNovember();
      final map = await db.planPurchaseCategories();
      expect(map, {seed.planId: seed.food});
      // A plan with no purchase has no entry.
      final planless = await db.addInstallmentPlan(
        walletId: seed.shopee,
        name: 'Manual',
        totalAmount: 900000,
        installmentAmount: 300000,
        totalCount: 3,
      );
      final after = await db.planPurchaseCategories();
      expect(after.containsKey(planless), isFalse);
      expect(after, {seed.planId: seed.food});
    });

    test('spendingCategoryOf uses the purchase category', () async {
      final seed = await seedNovember();
      final purchaseCategories = await db.planPurchaseCategories();
      final transferId = await db.transferCategoryId;

      final installment = await getTx(seed.installmentTxId);
      expect(
        spendingCategoryOf(
          t: installment,
          fallbackCategoryId: transferId,
          purchaseCategoryByPlanId: purchaseCategories,
        ),
        seed.food,
      );

      final unlinked = await getTx(seed.unlinkedTxId);
      expect(
        spendingCategoryOf(
          t: unlinked,
          fallbackCategoryId: transferId,
          purchaseCategoryByPlanId: purchaseCategories,
        ),
        transferId,
      );
    });

    test('watchCashTransactionsForCategory lists the rows behind a '
        'cash total', () async {
      final seed = await seedNovember();
      // Food in November (account 1): the normal 100.000 expense +
      // the November installment (attributed to Food via the plan
      // purchase). The 16.576.880 purchase itself is excluded, and so
      // is the unlinked paydown (its category is Transfer, not Food).
      final rows = await db
          .watchCashTransactionsForCategory(
            seed.food,
            novStart(),
            novEnd(),
            kind: 'expense',
            accountId: 1,
          )
          .first;
      expect(
        rows.map((d) => d.transaction.amount),
        unorderedEquals([100000, 5525627]),
      );
      expect(rows.map((d) => d.transaction.id), contains(seed.installmentTxId));
    });
  });
}
