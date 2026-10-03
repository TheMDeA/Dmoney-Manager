import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// Personal / Work / Family — unlimited accounts separating finances.
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get kind => text()(); // personal | work | family
}

/// Cash, bank accounts, e-wallets, credit cards.
class Wallets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  TextColumn get name => text()();
  TextColumn get kind => text()(); // cash | bank | ewallet | credit
  IntColumn get balance => integer().withDefault(const Constant(0))(); // whole IDR
  TextColumn get colorHex => text().withDefault(const Constant('#C6FF4A'))();
}

/// Expense / income categories; parentId == null means top-level.
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get iconKey => text().withDefault(const Constant('other'))();
  TextColumn get colorHex => text().withDefault(const Constant('#A78BFA'))();
  TextColumn get kind => text()(); // income | expense
  IntColumn get parentId => integer().nullable().references(Categories, #id)();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get walletId => integer().references(Wallets, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get kind => text()(); // income | expense | transfer
  IntColumn get amount => integer()(); // whole IDR, always positive
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  /// For transfers: the destination wallet. Null for income/expense.
  IntColumn get toWalletId => integer().nullable().references(Wallets, #id)();
}

/// Receipt / record photos attached to a transaction ("Save Photos").
class TransactionPhotos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().references(Transactions, #id)();
  TextColumn get path => text()();
}

/// Per-category monthly spending limits.
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get month => text()(); // yyyy-MM
  IntColumn get limit => integer()();
}

class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get target => integer()();
  IntColumn get saved => integer().withDefault(const Constant(0))();
  TextColumn get colorHex => text().withDefault(const Constant('#C6FF4A'))();
  DateTimeColumn get deadline => dateTime().nullable()();
}

/// Money you owe (payable) and money owed to you (receivable).
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get person => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get amount => integer()();
  TextColumn get direction => text()(); // payable | receivable
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get colorHex => text().withDefault(const Constant('#A78BFA'))();
}

// ---------------------------------------------------------------------------
// Joined view model
// ---------------------------------------------------------------------------

class TransactionWithDetails {
  final Transaction transaction;
  final Category category;
  final Wallet wallet;
  const TransactionWithDetails({
    required this.transaction,
    required this.category,
    required this.wallet,
  });
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [
  Accounts,
  Wallets,
  Categories,
  Transactions,
  TransactionPhotos,
  Budgets,
  Goals,
  Debts,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seed();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(transactions, transactions.toWalletId);
            await _ensureTransferCategory();
          }
        },
      );

  /// Inserts the hidden "Transfer" category if it doesn't exist yet
  /// (used by the v1→v2 migration; the fresh seed inserts it directly).
  Future<void> _ensureTransferCategory() async {
    final existing = await (select(categories)
          ..where((c) => c.kind.equals('transfer')))
        .get();
    if (existing.isEmpty) {
      await into(categories).insert(CategoriesCompanion.insert(
        name: 'Transfer',
        iconKey: const Value('swap_horiz'),
        colorHex: const Value('#9CA3AF'),
        kind: 'transfer',
      ));
    }
  }

  Future<int> get transferCategoryId async =>
      (await (select(categories)..where((c) => c.kind.equals('transfer')))
              .get())
          .first
          .id;

  // ------------------------------- watches -------------------------------

  Stream<List<Account>> watchAccounts() => select(accounts).watch();

  Stream<List<Wallet>> watchWallets({int? accountId}) {
    final q = select(wallets);
    if (accountId != null) q.where((w) => w.accountId.equals(accountId));
    return q.watch();
  }

  Stream<List<Category>> watchCategories({String? kind, bool topLevelOnly = false}) {
    final q = select(categories);
    if (kind != null) q.where((c) => c.kind.equals(kind));
    if (topLevelOnly) q.where((c) => c.parentId.isNull());
    q.orderBy([(c) => OrderingTerm.asc(c.name)]);
    return q.watch();
  }

  Stream<List<Category>> watchSubcategories(int parentId) =>
      (select(categories)..where((c) => c.parentId.equals(parentId))).watch();

  Stream<List<TransactionWithDetails>> watchTransactions({int? limit}) {
    final q = _joinedTransactions();
    if (limit != null) q.limit(limit);
    return q.watch().map(_toDetails);
  }

  Stream<List<Transaction>> watchTransactionsRaw() => select(transactions).watch();

  Stream<List<Budget>> watchBudgets(String month) =>
      (select(budgets)..where((b) => b.month.equals(month))).watch();

  Stream<List<Goal>> watchGoals() => select(goals).watch();

  Stream<List<Debt>> watchDebts({String? direction, bool? isPaid}) {
    final q = select(debts);
    if (direction != null) q.where((d) => d.direction.equals(direction));
    if (isPaid != null) q.where((d) => d.isPaid.equals(isPaid));
    return q.watch();
  }

  Stream<List<TransactionPhoto>> watchPhotos(int transactionId) =>
      (select(transactionPhotos)..where((p) => p.transactionId.equals(transactionId))).watch();

  Future<Wallet?> getWalletById(int id) =>
      (select(wallets)..where((w) => w.id.equals(id))).getSingleOrNull();

  // -------------------------------- writes -------------------------------

  /// Adjusts a wallet balance atomically (delta may be negative).
  Future<void> adjustWalletBalance(int walletId, int delta) {
    return customUpdate(
      'UPDATE wallets SET balance = balance + ? WHERE id = ?',
      variables: [Variable.withInt(delta), Variable.withInt(walletId)],
      updates: {wallets},
    );
  }

  /// Records an income/expense and keeps the wallet balance in sync.
  Future<int> addTransaction(TransactionsCompanion entry) {
    return transaction(() async {
      final id = await into(transactions).insert(entry);
      final kind = entry.kind.value;
      final amount = entry.amount.value;
      if (kind == 'income') {
        await adjustWalletBalance(entry.walletId.value, amount);
      } else if (kind == 'expense') {
        await adjustWalletBalance(entry.walletId.value, -amount);
      }
      return id;
    });
  }

  /// Records a wallet-to-wallet transfer and moves the balances.
  /// The row uses the hidden "Transfer" category and kind 'transfer'.
  Future<int> addTransfer({
    required int fromWalletId,
    required int toWalletId,
    required int amount,
    String note = '',
    DateTime? date,
  }) {
    return transaction(() async {
      final catId = await transferCategoryId;
      final id = await into(transactions).insert(TransactionsCompanion.insert(
        walletId: fromWalletId,
        categoryId: catId,
        kind: 'transfer',
        amount: amount,
        note: Value(note),
        date: date ?? DateTime.now(),
        toWalletId: Value(toWalletId),
      ));
      await adjustWalletBalance(fromWalletId, -amount);
      await adjustWalletBalance(toWalletId, amount);
      return id;
    });
  }

  Future<void> _reverseBalanceEffect(Transaction t) async {
    switch (t.kind) {
      case 'income':
        await adjustWalletBalance(t.walletId, -t.amount);
      case 'expense':
        await adjustWalletBalance(t.walletId, t.amount);
      case 'transfer':
        if (t.toWalletId != null) {
          await adjustWalletBalance(t.walletId, t.amount);
          await adjustWalletBalance(t.toWalletId!, -t.amount);
        }
    }
  }

  Future<void> deleteTransaction(int id) {
    return transaction(() async {
      final t = await (select(transactions)..where((e) => e.id.equals(id)))
          .getSingleOrNull();
      if (t == null) return;
      await _reverseBalanceEffect(t);
      await (delete(transactionPhotos)..where((p) => p.transactionId.equals(id)))
          .go();
      await (delete(transactions)..where((e) => e.id.equals(id))).go();
    });
  }

  /// Updates an income/expense record, keeping the wallet balance correct.
  Future<void> updateTransaction({
    required int id,
    required int walletId,
    required int categoryId,
    required String kind,
    required int amount,
    required String note,
    required DateTime date,
  }) {
    return transaction(() async {
      final old = await (select(transactions)..where((e) => e.id.equals(id)))
          .getSingleOrNull();
      if (old == null) return;
      await _reverseBalanceEffect(old);
      await (update(transactions)..where((e) => e.id.equals(id))).write(
        TransactionsCompanion(
          walletId: Value(walletId),
          categoryId: Value(categoryId),
          kind: Value(kind),
          amount: Value(amount),
          note: Value(note),
          date: Value(date),
        ),
      );
      if (kind == 'income') {
        await adjustWalletBalance(walletId, amount);
      } else if (kind == 'expense') {
        await adjustWalletBalance(walletId, -amount);
      }
    });
  }

  Future<void> updateCategory({
    required int id,
    required String name,
    required String iconKey,
    required String colorHex,
  }) =>
      (update(categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          name: Value(name),
          iconKey: Value(iconKey),
          colorHex: Value(colorHex),
        ),
      );

  Future<void> addPhoto(int transactionId, String path) =>
      into(transactionPhotos).insert(
        TransactionPhotosCompanion.insert(transactionId: transactionId, path: path),
      );

  /// Removes a photo attachment. The underlying image file is left alone —
  /// gallery picks belong to the user and camera shots live in app cache.
  Future<void> deletePhoto(int photoId) =>
      (delete(transactionPhotos)..where((p) => p.id.equals(photoId))).go();

  Future<int> addWallet(WalletsCompanion entry) => into(wallets).insert(entry);

  Future<int> addAccount(AccountsCompanion entry) =>
      into(accounts).insert(entry);

  Future<int> addCategory(CategoriesCompanion entry) => into(categories).insert(entry);

  Future<void> deleteCategory(int id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();

  Future<int> addBudget(BudgetsCompanion entry) => into(budgets).insert(entry);

  Future<void> updateBudgetLimit(int budgetId, int limit) =>
      (update(budgets)..where((b) => b.id.equals(budgetId)))
          .write(BudgetsCompanion(limit: Value(limit)));

  Future<void> deleteBudget(int budgetId) =>
      (delete(budgets)..where((b) => b.id.equals(budgetId))).go();

  Future<Budget?> getBudgetById(int id) =>
      (select(budgets)..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<int> addGoal(GoalsCompanion entry) => into(goals).insert(entry);

  Future<void> updateGoalSaved(int id, int saved) =>
      (update(goals)..where((g) => g.id.equals(id)))
          .write(GoalsCompanion(saved: Value(saved)));

  Future<int> addDebt(DebtsCompanion entry) => into(debts).insert(entry);

  Future<void> setDebtPaid(int id, bool paid) =>
      (update(debts)..where((d) => d.id.equals(id)))
          .write(DebtsCompanion(isPaid: Value(paid)));

  Future<List<TransactionWithDetails>> getTransactionsInRange(
      DateTime from, DateTime to) async {
    final q = _joinedTransactions()
      ..where(transactions.date.isBetweenValues(from, to));
    return _toDetails(await q.get());
  }

  // -------------------------------- internals ----------------------------

  JoinedSelectStatement _joinedTransactions() {
    final q = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      innerJoin(wallets, wallets.id.equalsExp(transactions.walletId)),
    ]);
    q.orderBy([OrderingTerm.desc(transactions.date)]);
    return q;
  }

  List<TransactionWithDetails> _toDetails(
      List<TypedResult> rows) {
    return rows
        .map((row) => TransactionWithDetails(
              transaction: row.readTable(transactions),
              category: row.readTable(categories),
              wallet: row.readTable(wallets),
            ))
        .toList();
  }

  // --------------------------------- seed --------------------------------

  Future<int> _categoryIdByName(String name) async {
    final row = await (select(categories)..where((c) => c.name.equals(name)))
        .getSingle();
    return row.id;
  }

  Future<void> _seed() async {
    // Fresh installs only get categories. Accounts and wallets are
    // created by the onboarding flow; sample transactions/budgets/
    // goals/debts are no longer seeded so new users start clean.
    await into(categories).insert(CategoriesCompanion.insert(
      name: 'Food',
      iconKey: const Value('food'),
      colorHex: const Value('#FB923C'),
      kind: 'expense',
    ));
    await into(categories).insert(CategoriesCompanion.insert(
      name: 'Coffee',
      iconKey: const Value('coffee'),
      colorHex: const Value('#B45309'),
      kind: 'expense',
      parentId: Value(await _categoryIdByName('Food')),
    ));
    await into(categories).insert(CategoriesCompanion.insert(
      name: 'Transport',
      iconKey: const Value('transport'),
      colorHex: const Value('#38BDF8'),
      kind: 'expense',
    ));
    await into(categories).insert(CategoriesCompanion.insert(
      name: 'Shopping',
      iconKey: const Value('shopping'),
      colorHex: const Value('#F472B6'),
      kind: 'expense',
    ));
    await into(categories).insert(CategoriesCompanion.insert(
      name: 'Bills',
      iconKey: const Value('bills'),
      colorHex: const Value('#FACC15'),
      kind: 'expense',
    ));
    await into(categories).insert(CategoriesCompanion.insert(
      name: 'Health',
      iconKey: const Value('health'),
      colorHex: const Value('#34D399'),
      kind: 'expense',
    ));
    await into(categories).insert(CategoriesCompanion.insert(
      name: 'Entertainment',
      iconKey: const Value('entertainment'),
      colorHex: const Value('#A78BFA'),
      kind: 'expense',
    ));
    await into(categories).insert(CategoriesCompanion.insert(
      name: 'Salary',
      iconKey: const Value('salary'),
      colorHex: const Value('#22C55E'),
      kind: 'income',
    ));
    await into(categories).insert(CategoriesCompanion.insert(
      name: 'Other',
      iconKey: const Value('other'),
      colorHex: const Value('#9CA3AF'),
      kind: 'expense',
    ));
    // Hidden category used by wallet-to-wallet transfers (kind 'transfer').
    await into(categories).insert(CategoriesCompanion.insert(
      name: 'Transfer',
      iconKey: const Value('swap_horiz'),
      colorHex: const Value('#9CA3AF'),
      kind: 'transfer',
    ));
  }
}

QueryExecutor _openConnection() => driftDatabase(name: 'money_manager');
