import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// P1 sync foundation (schema v18): every row gets a unique syncId, the
/// v18 backfill covers rows that lack one, and every write helper records
/// its change in the sync outbox in the same transaction as the data
/// change — so an outbox entry and its row can never disagree.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sync_schema_test');
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => root.path,
        );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await AppPrefs.init();
  });

  tearDown(() async {
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (await root.exists()) await root.delete(recursive: true);
  });

  final uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  Future<List<SyncOutboxData>> outbox() => db.select(db.syncOutbox).get();

  Future<int> outboxCount() async => (await outbox()).length;

  Future<bool> hasEntry(String table, String syncId, String op) async {
    final rows =
        await (db.select(db.syncOutbox)
              ..where((o) => o.targetTable.equals(table))
              ..where((o) => o.syncId.equals(syncId))
              ..where((o) => o.op.equals(op)))
            .get();
    return rows.isNotEmpty;
  }

  Future<int> entryCount(String table, String syncId, String op) async {
    final rows =
        await (db.select(db.syncOutbox)
              ..where((o) => o.targetTable.equals(table))
              ..where((o) => o.syncId.equals(syncId))
              ..where((o) => o.op.equals(op)))
            .get();
    return rows.length;
  }

  Future<int> makeAccount(String name) =>
      db.addAccount(AccountsCompanion.insert(name: name, kind: 'personal'));

  Future<int> makeWallet(
    String name,
    String kind, {
    int accountId = 1,
    int initialAmount = 0,
  }) => db.createWallet(
    accountId: accountId,
    name: name,
    kind: kind,
    initialAmount: initialAmount,
  );

  Future<int> foodId() async {
    final cats = await db.select(db.categories).get();
    return cats.firstWhere((c) => c.name == 'Food').id;
  }

  Future<int> salaryId() async {
    final cats = await db.select(db.categories).get();
    return cats.firstWhere((c) => c.name == 'Salary').id;
  }

  Future<Category> getCategory(int id) =>
      (db.select(db.categories)..where((c) => c.id.equals(id))).getSingle();

  Future<Wallet> getWallet(int id) => db.getWalletById(id).then((w) => w!);

  group('schema v18', () {
    test('fresh database: seeded rows have unique UUID syncIds', () async {
      final cats = await db.select(db.categories).get();
      expect(cats, isNotEmpty);
      final ids = cats.map((c) => c.syncId).toList();
      expect(ids.every((s) => s.isNotEmpty), isTrue);
      expect(ids.toSet().length, ids.length);
      for (final s in ids) {
        expect(s, matches(uuidPattern));
      }
      final state = await db.select(db.syncState).get();
      expect(state, hasLength(1));
      expect(state.single.id, 1);
      expect(state.single.lastPullCursor == null, isTrue);
      expect(state.single.lastSyncAt == null, isTrue);
    });

    test('backfill assigns unique ids, keeps existing ones, keywords '
        'are deterministic', () async {
      final legacyId = await db
          .into(db.wallets)
          .insert(
            WalletsCompanion.insert(
              accountId: 1,
              name: 'Legacy',
              kind: 'cash',
              syncId: const Value(''),
            ),
          );
      final keptId = await db
          .into(db.wallets)
          .insert(
            WalletsCompanion.insert(
              accountId: 1,
              name: 'Kept',
              kind: 'cash',
              syncId: const Value('keep-me'),
            ),
          );
      final food = await foodId();
      final foodRow = await getCategory(food);
      await db
          .into(db.categoryKeywords)
          .insert(
            CategoryKeywordsCompanion.insert(
              keyword: 'kopi',
              categoryId: food,
              hits: const Value(3),
              syncId: const Value(''),
            ),
          );

      await db.backfillMissingSyncIds();

      final legacy = await getWallet(legacyId);
      expect(legacy.syncId, isNot(''));
      expect(legacy.syncId, matches(uuidPattern));
      final kept = await getWallet(keptId);
      expect(kept.syncId, 'keep-me');
      final kw = await (db.select(
        db.categoryKeywords,
      )..where((k) => k.keyword.equals('kopi'))).getSingle();
      expect(kw.syncId, 'kw:kopi:${foodRow.syncId}');

      // Idempotent: a second run changes nothing.
      await db.backfillMissingSyncIds();
      final legacy2 = await getWallet(legacyId);
      expect(legacy2.syncId, legacy.syncId);
      final kw2 = await (db.select(
        db.categoryKeywords,
      )..where((k) => k.keyword.equals('kopi'))).getSingle();
      expect(kw2.syncId, kw.syncId);
    });

    test('syncIds are unique across tables', () async {
      final accountId = await makeAccount('Personal');
      final walletId = await makeWallet('Cash', 'cash', accountId: accountId);
      final catId = await db.addCategory(
        CategoriesCompanion.insert(name: 'Temp', kind: 'expense'),
      );
      final budgetId = await db.addBudget(
        BudgetsCompanion.insert(
          categoryId: await foodId(),
          month: '2026-11',
          limit: 100000,
        ),
      );
      final goalId = await db.addGoal(
        GoalsCompanion.insert(name: 'Trip', target: 1000000),
      );
      final all = <String>[
        (await (db.select(
          db.accounts,
        )..where((a) => a.id.equals(accountId))).getSingle()).syncId,
        (await getWallet(walletId)).syncId,
        (await getCategory(catId)).syncId,
        (await db.getBudgetById(budgetId).then((b) => b!)).syncId,
        (await db.getGoalById(goalId).then((g) => g!)).syncId,
      ];
      expect(all.every((s) => s.isNotEmpty), isTrue);
      expect(all.toSet().length, all.length);
      for (final s in all) {
        expect(s, matches(uuidPattern));
      }
    });
  });

  group('accounts', () {
    test('add / rename / recolor / move / delete enqueue entries', () async {
      final a = await makeAccount('Personal');
      final b = await makeAccount('Work');
      final account = await (db.select(
        db.accounts,
      )..where((x) => x.id.equals(a))).getSingle();
      expect(await hasEntry('accounts', account.syncId, 'insert'), isTrue);

      await db.renameAccount(a, 'Personal 2');
      expect(await hasEntry('accounts', account.syncId, 'update'), isTrue);
      await db.setAccountColor(a, '#FF0000');
      expect(await entryCount('accounts', account.syncId, 'update'), 2);

      final walletId = await makeWallet('Cash', 'cash', accountId: a);
      final wallet = await getWallet(walletId);
      await db.moveWalletsToAccount([walletId], b);
      expect(await hasEntry('wallets', wallet.syncId, 'update'), isTrue);

      await db.deleteAccount(a, b);
      expect(await hasEntry('accounts', account.syncId, 'delete'), isTrue);
    });
  });

  group('wallets', () {
    test(
      'create / add / update / reorder / initial-amount enqueue entries',
      () async {
        final walletId = await makeWallet('Cash', 'cash', initialAmount: 10000);
        var wallet = await getWallet(walletId);
        expect(await hasEntry('wallets', wallet.syncId, 'insert'), isTrue);

        final otherId = await db.addWallet(
          WalletsCompanion.insert(accountId: 1, name: 'Bank', kind: 'bank'),
        );
        final other = await getWallet(otherId);
        expect(await hasEntry('wallets', other.syncId, 'insert'), isTrue);

        await db.updateWallet(id: walletId, name: 'Cash 2', kind: 'cash');
        expect(await hasEntry('wallets', wallet.syncId, 'update'), isTrue);

        await db.changeWalletInitialAmount(walletId, 20000);
        expect(await entryCount('wallets', wallet.syncId, 'update'), 2);

        await db.reorderWallets([otherId, walletId]);
        expect(await entryCount('wallets', wallet.syncId, 'update'), 3);

        wallet = await getWallet(walletId);
        expect(wallet.balance, 20000);
      },
    );

    test('updateWallet refreshes updatedAt', () async {
      final walletId = await makeWallet('Cash', 'cash');
      await db.customStatement(
        'UPDATE wallets SET updated_at = 0 WHERE id = ?',
        [walletId],
      );
      await db.updateWallet(id: walletId, name: 'Cash 2', kind: 'cash');
      final wallet = await getWallet(walletId);
      expect(wallet.updatedAt.millisecondsSinceEpoch, greaterThan(0));
    });

    test('deleteWallet enqueues a delete', () async {
      final walletId = await makeWallet('Cash', 'cash');
      final wallet = await getWallet(walletId);
      expect(await db.deleteWallet(walletId), isTrue);
      expect(await hasEntry('wallets', wallet.syncId, 'delete'), isTrue);
    });

    test(
      'adjustWalletBalance writes no outbox entry (derived balance)',
      () async {
        final walletId = await makeWallet('Cash', 'cash');
        final before = await outboxCount();
        await db.adjustWalletBalance(walletId, 5000);
        expect(await outboxCount(), before);
        expect((await getWallet(walletId)).balance, 5000);
      },
    );
  });

  group('categories', () {
    test('add / update / reorder / delete enqueue entries', () async {
      final catId = await db.addCategory(
        CategoriesCompanion.insert(name: 'Temp', kind: 'expense'),
      );
      final cat = await getCategory(catId);
      expect(await hasEntry('categories', cat.syncId, 'insert'), isTrue);

      await db.updateCategory(
        id: catId,
        name: 'Temp 2',
        iconKey: 'other',
        colorHex: '#000000',
      );
      expect(await hasEntry('categories', cat.syncId, 'update'), isTrue);

      await db.reorderCategories([catId]);
      expect(await entryCount('categories', cat.syncId, 'update'), 2);
    });

    test('deleteCategory enqueues deletes + reassignment updates', () async {
      final walletId = await makeWallet('Cash', 'cash');
      final catId = await db.addCategory(
        CategoriesCompanion.insert(name: 'Temp', kind: 'expense'),
      );
      final cat = await getCategory(catId);
      final txId = await db.addTransaction(
        TransactionsCompanion.insert(
          walletId: walletId,
          categoryId: catId,
          kind: 'expense',
          amount: 5000,
          date: DateTime.now(),
        ),
      );
      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(txId))).getSingle();
      await db.deleteCategory(catId);
      expect(await hasEntry('categories', cat.syncId, 'delete'), isTrue);
      expect(await hasEntry('transactions', tx.syncId, 'update'), isTrue);
      final txAfter = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(txId))).getSingle();
      expect(txAfter.categoryId, await db.uncategorizedCategoryId);
    });

    test('lazy hidden categories enqueue insert entries', () async {
      final feeId = await db.feeCategoryId;
      final fee = await getCategory(feeId);
      expect(await hasEntry('categories', fee.syncId, 'insert'), isTrue);
      expect(await entryCount('categories', fee.syncId, 'insert'), 1);
      // Second call finds the existing row: no duplicate entry.
      await db.feeCategoryId;
      expect(await entryCount('categories', fee.syncId, 'insert'), 1);

      // 'Interest' is already in the seed, so the getter finds the seeded
      // row and creates nothing: no outbox entry by design (the P2
      // initial push covers all seeded rows).
      final interestId = await db.interestCategoryId;
      final interest = await getCategory(interestId);
      expect(await hasEntry('categories', interest.syncId, 'insert'), isFalse);
      final fallbackId = await db.uncategorizedCategoryId;
      final fallback = await getCategory(fallbackId);
      expect(await hasEntry('categories', fallback.syncId, 'insert'), isTrue);
    });
  });

  group('transactions', () {
    test('add / update / delete enqueue entries', () async {
      final walletId = await makeWallet('Cash', 'cash');
      final txId = await db.addTransaction(
        TransactionsCompanion.insert(
          walletId: walletId,
          categoryId: await foodId(),
          kind: 'expense',
          amount: 10000,
          date: DateTime.now(),
        ),
      );
      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(txId))).getSingle();
      expect(await hasEntry('transactions', tx.syncId, 'insert'), isTrue);

      await db.updateTransaction(
        id: txId,
        walletId: walletId,
        categoryId: await foodId(),
        kind: 'expense',
        amount: 12000,
        note: 'edited',
        date: DateTime.now(),
      );
      expect(await hasEntry('transactions', tx.syncId, 'update'), isTrue);

      await db.deleteTransaction(txId);
      expect(await hasEntry('transactions', tx.syncId, 'delete'), isTrue);
    });

    test('addTransfer enqueues transfer + fee inserts', () async {
      final from = await makeWallet('BCA', 'bank');
      final to = await makeWallet('GoPay', 'ewallet');
      final txId = await db.addTransfer(
        fromWalletId: from,
        toWalletId: to,
        amount: 50000,
        fee: 2500,
      );
      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(txId))).getSingle();
      expect(await hasEntry('transactions', tx.syncId, 'insert'), isTrue);
      final feeRows = await db.transferFeeRows(txId);
      expect(feeRows, hasLength(1));
      expect(
        await hasEntry('transactions', feeRows.single.syncId, 'insert'),
        isTrue,
      );
    });

    test('deleteTransaction enqueues tx + fee + photo deletes', () async {
      final from = await makeWallet('BCA', 'bank');
      final to = await makeWallet('GoPay', 'ewallet');
      final txId = await db.addTransfer(
        fromWalletId: from,
        toWalletId: to,
        amount: 50000,
        fee: 2500,
      );
      final src = File('${root.path}/src.jpg')..writeAsBytesSync([1, 2, 3]);
      await db.addPhoto(txId, src.path);
      final photos = await (db.select(
        db.transactionPhotos,
      )..where((p) => p.transactionId.equals(txId))).get();
      expect(photos, hasLength(1));
      final feeRows = await db.transferFeeRows(txId);

      await db.deleteTransaction(txId);

      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(txId))).getSingleOrNull();
      expect(tx == null, isTrue);
      // The transfer row itself is gone; its syncId came from the insert.
      final txSyncId =
          (await (db.select(db.syncOutbox)
                    ..where((o) => o.targetTable.equals('transactions'))
                    ..where((o) => o.op.equals('delete')))
                  .get())
              .map((o) => o.syncId)
              .toList();
      expect(txSyncId, hasLength(2)); // transfer + fee row
      expect(
        await hasEntry('transaction_photos', photos.single.syncId, 'delete'),
        isTrue,
      );
      expect(
        await hasEntry('transactions', feeRows.single.syncId, 'delete'),
        isTrue,
      );
    });

    test('restoreTransaction re-inserts with an insert entry', () async {
      final walletId = await makeWallet('Cash', 'cash');
      final txId = await db.addTransaction(
        TransactionsCompanion.insert(
          walletId: walletId,
          categoryId: await foodId(),
          kind: 'expense',
          amount: 10000,
          date: DateTime.now(),
        ),
      );
      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(txId))).getSingle();
      await db.deleteTransaction(txId);
      expect(await hasEntry('transactions', tx.syncId, 'delete'), isTrue);
      await db.restoreTransaction(tx, []);
      expect(await hasEntry('transactions', tx.syncId, 'insert'), isTrue);
      final restored = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(txId))).getSingleOrNull();
      expect(restored != null, isTrue);
    });

    test('setTransactionPlan enqueues a transaction update', () async {
      final walletId = await makeWallet('Shopeepaylater', 'paylater');
      final txId = await db.addTransaction(
        TransactionsCompanion.insert(
          walletId: walletId,
          categoryId: await foodId(),
          kind: 'expense',
          amount: 900000,
          date: DateTime.now(),
        ),
      );
      final planId = await db.addInstallmentPlan(
        walletId: walletId,
        name: 'Manual',
        totalAmount: 900000,
        installmentAmount: 300000,
        totalCount: 3,
      );
      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(txId))).getSingle();
      await db.setTransactionPlan(txId, planId);
      expect(await hasEntry('transactions', tx.syncId, 'update'), isTrue);
    });
  });

  group('photos', () {
    test('addPhoto / deletePhoto enqueue entries', () async {
      final walletId = await makeWallet('Cash', 'cash');
      final txId = await db.addTransaction(
        TransactionsCompanion.insert(
          walletId: walletId,
          categoryId: await foodId(),
          kind: 'expense',
          amount: 10000,
          date: DateTime.now(),
        ),
      );
      final src = File('${root.path}/src.jpg')..writeAsBytesSync([1, 2, 3]);
      final stored = await db.addPhoto(txId, src.path);
      expect(await File(stored).exists(), isTrue);
      final photos = await (db.select(
        db.transactionPhotos,
      )..where((p) => p.transactionId.equals(txId))).get();
      expect(photos, hasLength(1));
      expect(
        await hasEntry('transaction_photos', photos.single.syncId, 'insert'),
        isTrue,
      );
      await db.deletePhoto(photos.single.id);
      expect(
        await hasEntry('transaction_photos', photos.single.syncId, 'delete'),
        isTrue,
      );
      expect(await File(stored).exists(), isFalse);
    });
  });

  group('budgets', () {
    test('add / update / delete enqueue entries', () async {
      final budgetId = await db.addBudget(
        BudgetsCompanion.insert(
          categoryId: await foodId(),
          month: '2026-11',
          limit: 1000000,
        ),
      );
      final budget = await db.getBudgetById(budgetId).then((b) => b!);
      expect(await hasEntry('budgets', budget.syncId, 'insert'), isTrue);
      await db.updateBudgetLimit(budgetId, 2000000);
      expect(await hasEntry('budgets', budget.syncId, 'update'), isTrue);
      await db.deleteBudget(budgetId);
      expect(await hasEntry('budgets', budget.syncId, 'delete'), isTrue);
    });
  });

  group('goals', () {
    test('add / update / deposit / delete enqueue entries', () async {
      final goalId = await db.addGoal(
        GoalsCompanion.insert(name: 'Trip', target: 1000000),
      );
      final goal = await db.getGoalById(goalId).then((g) => g!);
      expect(await hasEntry('goals', goal.syncId, 'insert'), isTrue);

      await db.updateGoal(id: goalId, name: 'Trip 2', target: 1200000);
      expect(await hasEntry('goals', goal.syncId, 'update'), isTrue);

      await db.recordGoalDeposit(
        goalId: goalId,
        amount: 100000,
        date: DateTime.now(),
      );
      var deposits = await (db.select(
        db.goalDeposits,
      )..where((d) => d.goalId.equals(goalId))).get();
      expect(deposits, hasLength(1));
      expect(
        await hasEntry('goal_deposits', deposits.single.syncId, 'insert'),
        isTrue,
      );
      expect((await db.getGoalById(goalId))!.saved, 100000);

      await db.deleteGoalDeposit(deposits.single);
      expect(
        await hasEntry('goal_deposits', deposits.single.syncId, 'delete'),
        isTrue,
      );

      await db.recordGoalDeposit(
        goalId: goalId,
        amount: 50000,
        date: DateTime.now(),
      );
      deposits = await (db.select(
        db.goalDeposits,
      )..where((d) => d.goalId.equals(goalId))).get();
      await db.deleteGoal(goalId);
      expect(await hasEntry('goals', goal.syncId, 'delete'), isTrue);
      expect(
        await hasEntry('goal_deposits', deposits.single.syncId, 'delete'),
        isTrue,
      );
    });

    test('updateGoalSaved writes no outbox entry (derived saved)', () async {
      final goalId = await db.addGoal(
        GoalsCompanion.insert(name: 'Trip', target: 1000000),
      );
      final before = await outboxCount();
      await db.updateGoalSaved(goalId, 42);
      expect(await outboxCount(), before);
    });
  });

  group('debts', () {
    test('create / update / delete enqueue entries', () async {
      final walletId = await makeWallet('BCA', 'bank');
      final debtId = await db.createDebt(
        person: 'Alice',
        note: '',
        amount: 100000,
        direction: 'payable',
        walletId: walletId,
      );
      final debt = await db.getDebtById(debtId).then((d) => d!);
      expect(await hasEntry('debts', debt.syncId, 'insert'), isTrue);
      final creationTx = await (db.select(
        db.transactions,
      )..where((t) => t.debtId.equals(debtId))).get();
      expect(creationTx, hasLength(1));
      expect(
        await hasEntry('transactions', creationTx.single.syncId, 'insert'),
        isTrue,
      );

      await db.updateDebt(
        id: debtId,
        person: 'Alice',
        note: 'updated',
        amount: 120000,
        walletId: walletId,
        recordAsTransaction: true,
      );
      expect(await hasEntry('debts', debt.syncId, 'update'), isTrue);
      expect(
        await hasEntry('transactions', creationTx.single.syncId, 'update'),
        isTrue,
      );
    });

    test('record / delete payment enqueue entries', () async {
      final walletId = await makeWallet('BCA', 'bank');
      final debtId = await db.createDebt(
        person: 'Bob',
        note: '',
        amount: 50000,
        direction: 'receivable',
        walletId: walletId,
      );
      final debt = await db.getDebtById(debtId).then((d) => d!);
      await db.recordDebtPayment(
        debt: debt,
        amount: 20000,
        date: DateTime.now(),
        walletId: walletId,
      );
      final payments = await (db.select(
        db.debtPayments,
      )..where((p) => p.debtId.equals(debtId))).get();
      expect(payments, hasLength(1));
      expect(
        await hasEntry('debt_payments', payments.single.syncId, 'insert'),
        isTrue,
      );
      final paymentTx = await (db.select(
        db.transactions,
      )..where((t) => t.debtPaymentId.equals(payments.single.id))).get();
      expect(paymentTx, hasLength(1));
      expect(
        await hasEntry('transactions', paymentTx.single.syncId, 'insert'),
        isTrue,
      );

      await db.deleteDebtPayment(payments.single, debt);
      expect(
        await hasEntry('debt_payments', payments.single.syncId, 'delete'),
        isTrue,
      );
      expect(
        await hasEntry('transactions', paymentTx.single.syncId, 'delete'),
        isTrue,
      );
    });

    test('deleteDebt enqueues debt + payment + tx deletes', () async {
      final walletId = await makeWallet('BCA', 'bank');
      final debtId = await db.createDebt(
        person: 'Bob',
        note: '',
        amount: 50000,
        direction: 'receivable',
        walletId: walletId,
      );
      final debt = await db.getDebtById(debtId).then((d) => d!);
      await db.recordDebtPayment(
        debt: debt,
        amount: 20000,
        date: DateTime.now(),
        walletId: walletId,
      );
      final payments = await (db.select(
        db.debtPayments,
      )..where((p) => p.debtId.equals(debtId))).get();
      final txs = await (db.select(
        db.transactions,
      )..where((t) => t.debtId.equals(debtId))).get();
      await db.deleteDebt(debtId);
      expect(await hasEntry('debts', debt.syncId, 'delete'), isTrue);
      expect(
        await hasEntry('debt_payments', payments.single.syncId, 'delete'),
        isTrue,
      );
      for (final t in txs) {
        expect(await hasEntry('transactions', t.syncId, 'delete'), isTrue);
      }
    });

    test('setDebtPaid writes no outbox entry (derived isPaid)', () async {
      final walletId = await makeWallet('BCA', 'bank');
      final debtId = await db.createDebt(
        person: 'Bob',
        note: '',
        amount: 50000,
        direction: 'receivable',
        walletId: walletId,
      );
      final before = await outboxCount();
      await db.setDebtPaid(debtId, true);
      expect(await outboxCount(), before);
    });

    test('addDebt enqueues an insert', () async {
      final debtId = await db.addDebt(
        DebtsCompanion.insert(
          person: 'Carol',
          amount: 70000,
          direction: 'payable',
        ),
      );
      final debt = await db.getDebtById(debtId).then((d) => d!);
      expect(await hasEntry('debts', debt.syncId, 'insert'), isTrue);
    });
  });

  group('installment plans', () {
    test('add / purchase / edit / delete enqueue entries', () async {
      final walletId = await makeWallet('Shopeepaylater', 'paylater');
      final planId = await db.addInstallmentPlan(
        walletId: walletId,
        name: 'Manual',
        totalAmount: 900000,
        installmentAmount: 300000,
        totalCount: 3,
      );
      final manual = await db.getInstallmentPlan(planId).then((p) => p!);
      expect(
        await hasEntry('installment_plans', manual.syncId, 'insert'),
        isTrue,
      );

      final planId2 = await db.addPlanWithPurchase(
        walletId: walletId,
        name: 'Phone',
        totalAmount: 1200000,
        installmentAmount: 400000,
        totalCount: 3,
        categoryId: await foodId(),
      );
      final plan = await db.getInstallmentPlan(planId2).then((p) => p!);
      expect(
        await hasEntry('installment_plans', plan.syncId, 'insert'),
        isTrue,
      );
      final purchase =
          await (db.select(db.transactions)
                ..where((t) => t.planId.equals(planId2))
                ..where((t) => t.kind.equals('expense')))
              .getSingle();
      expect(await hasEntry('transactions', purchase.syncId, 'insert'), isTrue);

      await db.editInstallmentPlan(
        planId: planId2,
        name: 'Phone',
        totalAmount: 1500000,
        installmentAmount: 500000,
        totalCount: 3,
        createdAt: plan.createdAt,
      );
      expect(
        await hasEntry('installment_plans', plan.syncId, 'update'),
        isTrue,
      );
      expect(await hasEntry('transactions', purchase.syncId, 'update'), isTrue);

      final linked = await db.planTransactions(planId2);
      await db.deleteInstallmentPlan(planId2);
      expect(
        await hasEntry('installment_plans', plan.syncId, 'delete'),
        isTrue,
      );
      for (final t in linked) {
        expect(await hasEntry('transactions', t.syncId, 'delete'), isTrue);
      }
    });

    test(
      'markInstallmentPaid writes no outbox entry (derived paidCount)',
      () async {
        final walletId = await makeWallet('Shopeepaylater', 'paylater');
        final planId = await db.addPlanWithPurchase(
          walletId: walletId,
          name: 'Phone',
          totalAmount: 1200000,
          installmentAmount: 400000,
          totalCount: 3,
          categoryId: await foodId(),
        );
        final before = await outboxCount();
        await db.markInstallmentPaid(planId);
        expect(await outboxCount(), before);
      },
    );

    test('restoreInstallmentPlan re-inserts with an insert entry', () async {
      final walletId = await makeWallet('Shopeepaylater', 'paylater');
      final planId = await db.addInstallmentPlan(
        walletId: walletId,
        name: 'Manual',
        totalAmount: 900000,
        installmentAmount: 300000,
        totalCount: 3,
      );
      final plan = await db.getInstallmentPlan(planId).then((p) => p!);
      await db.deleteInstallmentPlan(planId);
      expect(
        await hasEntry('installment_plans', plan.syncId, 'delete'),
        isTrue,
      );
      await db.restoreInstallmentPlan(plan);
      expect(
        await hasEntry('installment_plans', plan.syncId, 'insert'),
        isTrue,
      );
    });
  });

  group('recurring transactions', () {
    test('add / update / pause / delete enqueue entries', () async {
      final walletId = await makeWallet('Cash', 'cash');
      final ruleId = await db.addRecurringTransaction(
        RecurringTransactionsCompanion.insert(
          walletId: walletId,
          categoryId: await salaryId(),
          kind: 'income',
          amount: 100000,
          note: const Value('Salary'),
          frequency: 'monthly',
          nextDue: DateTime.now().add(const Duration(days: 30)),
        ),
      );
      final rule = await (db.select(
        db.recurringTransactions,
      )..where((r) => r.id.equals(ruleId))).getSingle();
      expect(
        await hasEntry('recurring_transactions', rule.syncId, 'insert'),
        isTrue,
      );

      await db.updateRecurringTransaction(
        ruleId,
        RecurringTransactionsCompanion(
          amount: const Value(120000),
          note: const Value('Salary 2'),
        ),
      );
      expect(
        await hasEntry('recurring_transactions', rule.syncId, 'update'),
        isTrue,
      );

      await db.setRecurringActive(ruleId, false);
      expect(
        await entryCount('recurring_transactions', rule.syncId, 'update'),
        2,
      );

      await db.deleteRecurringTransaction(ruleId);
      expect(
        await hasEntry('recurring_transactions', rule.syncId, 'delete'),
        isTrue,
      );
    });

    test('processDueRecurringTransactions enqueues generated txs + rule '
        'update', () async {
      final walletId = await makeWallet('Cash', 'cash');
      final ruleId = await db.addRecurringTransaction(
        RecurringTransactionsCompanion.insert(
          walletId: walletId,
          categoryId: await salaryId(),
          kind: 'income',
          amount: 100000,
          note: const Value('Salary'),
          frequency: 'monthly',
          nextDue: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
      final generated = await db.processDueRecurringTransactions();
      expect(generated, greaterThan(0));
      final txs = await (db.select(
        db.transactions,
      )..where((t) => t.recurringId.equals(ruleId))).get();
      expect(txs, isNotEmpty);
      for (final t in txs) {
        expect(await hasEntry('transactions', t.syncId, 'insert'), isTrue);
      }
      final rule = await (db.select(
        db.recurringTransactions,
      )..where((r) => r.id.equals(ruleId))).getSingle();
      expect(
        await hasEntry('recurring_transactions', rule.syncId, 'update'),
        isTrue,
      );
    });
  });

  group('templates', () {
    test('add / bump / delete enqueue entries', () async {
      final walletId = await makeWallet('Cash', 'cash');
      final templateId = await db.addTransactionTemplate(
        TransactionTemplatesCompanion.insert(
          name: 'Lunch',
          walletId: walletId,
          categoryId: await foodId(),
          kind: 'expense',
          amount: 25000,
        ),
      );
      final template = await (db.select(
        db.transactionTemplates,
      )..where((t) => t.id.equals(templateId))).getSingle();
      expect(
        await hasEntry('transaction_templates', template.syncId, 'insert'),
        isTrue,
      );
      await db.bumpTemplateUse(templateId);
      expect(
        await hasEntry('transaction_templates', template.syncId, 'update'),
        isTrue,
      );
      await db.deleteTransactionTemplate(templateId);
      expect(
        await hasEntry('transaction_templates', template.syncId, 'delete'),
        isTrue,
      );
    });
  });

  group('keywords', () {
    test('learning enqueues deterministic insert then update', () async {
      final food = await foodId();
      final foodRow = await getCategory(food);
      await db.learnKeywords({'kopi', 'pagi'}, food);
      expect(
        await hasEntry(
          'category_keywords',
          'kw:kopi:${foodRow.syncId}',
          'insert',
        ),
        isTrue,
      );
      expect(
        await hasEntry(
          'category_keywords',
          'kw:pagi:${foodRow.syncId}',
          'insert',
        ),
        isTrue,
      );
      await db.learnKeywords({'kopi'}, food);
      expect(
        await hasEntry(
          'category_keywords',
          'kw:kopi:${foodRow.syncId}',
          'update',
        ),
        isTrue,
      );
      await db.unlearnKeywords({'kopi'}, food);
      expect(
        await entryCount(
          'category_keywords',
          'kw:kopi:${foodRow.syncId}',
          'update',
        ),
        2,
      );
    });
  });
}
