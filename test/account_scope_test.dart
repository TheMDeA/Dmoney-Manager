library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dmoney_manager/data/database/app_database.dart';

/// Temporary verification for the account-scope package (v9):
/// - accounts.colorHex defaults
/// - aggregate queries respect accountId
/// - deleteAccount reassigns wallets, moveWalletsToAccount works
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // minimal seed: 2 accounts, 3 wallets, categories needed for transactions
    final personal = await db.addAccount(AccountsCompanion.insert(
        name: 'Personal', kind: 'personal', colorHex: const Value('#FF0000')));
    final work = await db.addAccount(AccountsCompanion.insert(
        name: 'Work', kind: 'work', colorHex: const Value('#00FF00')));
    expect(personal, isNot(work));

    final cash = await db.createWallet(
        accountId: personal, name: 'Cash', kind: 'cash', initialAmount: 1000);
    final bank = await db.createWallet(
        accountId: personal, name: 'Bank', kind: 'bank', initialAmount: 5000);
    final workWallet = await db.createWallet(
        accountId: work, name: 'WorkCard', kind: 'bank', initialAmount: 2000);

    final catId = await db.addCategory(CategoriesCompanion.insert(
        name: 'Food', kind: 'expense'));

    Future<void> tx(int walletId, int amount, String kind) =>
        db.addTransaction(TransactionsCompanion.insert(
          walletId: walletId,
          categoryId: catId,
          kind: kind,
          amount: amount,
          date: DateTime.now(),
        ));

    await tx(cash, 100, 'expense');
    await tx(bank, 200, 'expense');
    await tx(workWallet, 1000, 'expense');
    await tx(workWallet, 5000, 'income');
  });

  tearDown(() => db.close());

  test('colorHex defaults and persists', () async {
    final accounts = await db.watchAccounts().first;
    expect(accounts.length, 2);
    expect(accounts.map((a) => a.colorHex),
        containsAll(['#FF0000', '#00FF00']));
  });

  test('watchKindTotals scopes by account', () async {
    final all = await db
        .watchKindTotals(
            DateTime.now().subtract(const Duration(days: 1)),
            DateTime.now().add(const Duration(days: 1)))
        .first;
    final personal = await db
        .watchKindTotals(
            DateTime.now().subtract(const Duration(days: 1)),
            DateTime.now().add(const Duration(days: 1)),
            accountId: 1)
        .first;
    final work = await db
        .watchKindTotals(
            DateTime.now().subtract(const Duration(days: 1)),
            DateTime.now().add(const Duration(days: 1)),
            accountId: 2)
        .first;
    int sum(List<KindTotal> l, String k) =>
        l.where((t) => t.kind == k).fold<int>(0, (s, t) => s + t.total);
    expect(sum(all, 'expense'), 1300);
    expect(sum(personal, 'expense'), 300);
    expect(sum(work, 'expense'), 1000);
    expect(sum(work, 'income'), 5000);
    expect(sum(personal, 'income'), 0);
  });

  test('watchTransactions scopes by account', () async {
    final workTx = await db
        .watchTransactions(accountId: 2)
        .first;
    expect(workTx.length, 2);
    expect(workTx.every((t) => t.wallet.accountId == 2), isTrue);
  });

  test('watchWallets scopes by account (balance card math)', () async {
    final wallets = await db.watchWallets(accountId: 1).first;
    expect(wallets.length, 2);
    expect(wallets.fold<int>(0, (s, w) => s + w.balance), 6000 - 300);
  });

  test('moveWalletsToAccount + deleteAccount reassigns', () async {
    final wallets = await db.watchWallets(accountId: 2).first;
    await db.moveWalletsToAccount(
        wallets.map((w) => w.id).toList(), 1);
    expect((await db.watchWallets(accountId: 1).first).length, 3);
    await db.deleteAccount(2, 1);
    expect((await db.watchAccounts().first).length, 1);
    // transactions follow their wallet's new account
    final scoped = await db.watchTransactions(accountId: 1).first;
    expect(scoped.length, 4);
  });

  test('renameAccount + setAccountColor', () async {
    await db.renameAccount(1, 'Me');
    await db.setAccountColor(1, '#123456');
    final a = (await db.watchAccounts().first).firstWhere((x) => x.id == 1);
    expect(a.name, 'Me');
    expect(a.colorHex, '#123456');
  });
}
