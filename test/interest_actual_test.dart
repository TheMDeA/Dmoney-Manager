import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/utils/interest_projection.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// Actual interest earned: income rows booked under the Interest
/// category, summed per wallet. The category is seeded for fresh
/// installs and created on first use for existing ones (same pattern
/// as the Transfer fee category); sums match by category id, never by
/// name, so renaming the category keeps working.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
  });

  tearDown(() => db.close());

  Future<int> makeWallet(String name, String kind) => db.createWallet(
        accountId: 1,
        name: name,
        kind: kind,
      );

  Future<int> addIncome(
    int walletId,
    int categoryId,
    int amount,
    DateTime date,
  ) =>
      db.addTransaction(
        TransactionsCompanion.insert(
          walletId: walletId,
          categoryId: categoryId,
          kind: 'income',
          amount: amount,
          note: const Value(''),
          date: date,
        ),
      );

  Future<int> categoryIdByName(String name) async {
    final cats = await db.select(db.categories).get();
    return cats.firstWhere((c) => c.name == name).id;
  }

  test('seeded Interest category is reused, not duplicated', () async {
    final first = await db.interestCategoryId;
    final second = await db.interestCategoryId;
    expect(first, second);
    final cats = await db.select(db.categories).get();
    expect(cats.where((c) => c.name == 'Interest'), hasLength(1));
  });

  test('year and total sums exclude other categories, wallets, kinds',
      () async {
    final w1 = await makeWallet('Jago', 'bank');
    final w2 = await makeWallet('Seabank', 'bank');
    final interestId = await db.interestCategoryId;
    final dividendId = await categoryIdByName('Dividend');
    final now = DateTime.now();
    final lastYear = DateTime(now.year - 1, 6, 15);

    await addIncome(w1, interestId, 500000, now);
    await addIncome(w1, interestId, 300000, lastYear);
    await addIncome(w1, dividendId, 700000, now);
    await addIncome(w2, interestId, 900000, now);
    await db.addTransaction(
      TransactionsCompanion.insert(
        walletId: w1,
        categoryId: interestId,
        kind: 'expense',
        amount: 100000,
        note: const Value(''),
        date: now,
      ),
    );

    final txs = await db.watchTransactionsForWallet(w1).first;
    expect(interestEarned(txs, interestId), 800000);
    expect(interestEarned(txs, interestId, year: now.year), 500000);
  });

  test('renamed category still counts by id', () async {
    final interestId = await db.interestCategoryId;
    final w = await makeWallet('Jago', 'bank');
    await addIncome(w, interestId, 250000, DateTime.now());
    await db.updateCategory(
      id: interestId,
      name: 'Bank interest',
      iconKey: 'account_balance',
      colorHex: '#4ADE80',
    );
    final txs = await db.watchTransactionsForWallet(w).first;
    expect(interestEarned(txs, interestId), 250000);
  });
}
