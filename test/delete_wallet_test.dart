import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// deleteWallet guard: a wallet with installment plans, recurring rules,
/// templates, or debts must not delete — foreign keys are unenforced at
/// runtime, so deleting would strand them (a recurring rule would keep
/// posting transactions that no wallet list can show).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
  });

  tearDown(() => db.close());

  Future<int> makeWallet(String name, String kind) =>
      db.createWallet(accountId: 1, name: name, kind: kind);

  Future<int> foodId() async {
    final cats = await db.select(db.categories).get();
    return cats.firstWhere((c) => c.name == 'Food').id;
  }

  Future<bool> walletExists(int id) async =>
      (await db.getWalletById(id)) != null;

  test('refuses a wallet with a recurring rule and no transactions',
      () async {
    final walletId = await makeWallet('Bank', 'bank');
    await db.addRecurringTransaction(
      RecurringTransactionsCompanion.insert(
        walletId: walletId,
        categoryId: await foodId(),
        kind: 'expense',
        amount: 50000,
        frequency: 'monthly',
        nextDue: DateTime.now(),
      ),
    );

    expect(await db.deleteWallet(walletId), isFalse);
    expect(await walletExists(walletId), isTrue);
  });

  test('refuses a wallet with an installment plan', () async {
    final walletId = await makeWallet('Paylater', 'paylater');
    await db.addInstallmentPlan(
      walletId: walletId,
      name: 'Phone',
      totalAmount: 1200000,
      installmentAmount: 400000,
      totalCount: 3,
    );

    expect(await db.deleteWallet(walletId), isFalse);
    expect(await walletExists(walletId), isTrue);
  });

  test('refuses a wallet with a template', () async {
    final walletId = await makeWallet('Bank', 'bank');
    await db.addTransactionTemplate(
      TransactionTemplatesCompanion.insert(
        name: 'Groceries',
        walletId: walletId,
        categoryId: await foodId(),
        kind: 'expense',
        amount: 100000,
      ),
    );

    expect(await db.deleteWallet(walletId), isFalse);
    expect(await walletExists(walletId), isTrue);
  });

  test('refuses a wallet with a debt', () async {
    final walletId = await makeWallet('Bank', 'bank');
    await db.addDebt(
      DebtsCompanion.insert(
        person: 'Alice',
        amount: 500000,
        direction: 'payable',
        walletId: Value(walletId),
      ),
    );

    expect(await db.deleteWallet(walletId), isFalse);
    expect(await walletExists(walletId), isTrue);
  });

  test('deletes a wallet with nothing attached', () async {
    final walletId = await makeWallet('Cash', 'cash');

    expect(await db.deleteWallet(walletId), isTrue);
    expect(await walletExists(walletId), isFalse);
  });
}
