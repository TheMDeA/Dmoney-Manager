import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

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
@TableIndex(name: 'idx_wallets_account', columns: {#accountId})
class Wallets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  TextColumn get name => text()();
  TextColumn get kind => text()(); // cash | bank | ewallet | credit
  IntColumn get balance => integer().withDefault(const Constant(0))(); // whole IDR
  IntColumn get initialAmount => integer().withDefault(const Constant(0))();
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
  /// Manual ordering for the Manage Categories screen (per kind group).
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@TableIndex(name: 'idx_transactions_date', columns: {#date})
@TableIndex(name: 'idx_transactions_wallet', columns: {#walletId})
@TableIndex(name: 'idx_transactions_category', columns: {#categoryId})
@TableIndex(name: 'idx_transactions_debt', columns: {#debtId})
@TableIndex(name: 'idx_transactions_debt_payment', columns: {#debtPaymentId})
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
  /// Set when this row records a debt's creation movement.
  IntColumn get debtId => integer().nullable().references(Debts, #id)();
  /// Set when this row records a specific debt repayment.
  IntColumn get debtPaymentId =>
      integer().nullable().references(DebtPayments, #id)();
  /// Set when this row was generated from a recurring rule.
  IntColumn get recurringId =>
      integer().nullable().references(RecurringTransactions, #id)();
}

/// Receipt / record photos attached to a transaction ("Save Photos").
@TableIndex(name: 'idx_photos_transaction', columns: {#transactionId})
class TransactionPhotos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().references(Transactions, #id)();
  TextColumn get path => text()();
}

/// Per-category monthly spending limits.
@TableIndex(name: 'idx_budgets_month', columns: {#month})
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
@TableIndex(name: 'idx_debts_direction', columns: {#direction})
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get person => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get amount => integer()();
  TextColumn get direction => text()(); // payable | receivable
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get colorHex => text().withDefault(const Constant('#A78BFA'))();
  IntColumn get walletId => integer().nullable().references(Wallets, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  /// When true, the debt's creation and repayments are recorded as
  /// transactions (linked via transactions.debtId / debtPaymentId) so
  /// they show up in the transaction history.
  BoolColumn get recordAsTransaction =>
      boolean().withDefault(const Constant(true))();
}

/// Partial repayments recorded against a debt.
@TableIndex(name: 'idx_debt_payments_debt', columns: {#debtId})
class DebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get debtId => integer().references(Debts, #id)();
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get walletId => integer().nullable().references(Wallets, #id)();
}

/// Deposit / withdrawal history for a savings goal.
/// Positive amount = deposit, negative = withdrawal.
@TableIndex(name: 'idx_goal_deposits_goal', columns: {#goalId})
class GoalDeposits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get goalId => integer().references(Goals, #id)();
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

/// Recurring income/expense rules (subscriptions, salary, rent).
/// Due occurrences are materialized as real transactions on app start.
@TableIndex(name: 'idx_recurring_next_due', columns: {#nextDue})
class RecurringTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get walletId => integer().references(Wallets, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get kind => text()(); // income | expense
  IntColumn get amount => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get frequency => text()(); // daily | weekly | monthly | yearly
  DateTimeColumn get nextDue => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// One-tap transaction templates for the add-transaction sheet.
class TransactionTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get walletId => integer().references(Wallets, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get kind => text()(); // income | expense
  IntColumn get amount => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get useCount => integer().withDefault(const Constant(0))();
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

/// Per-category expense total for a period (donut chart).
typedef CategoryTotal = ({int categoryId, int total});

/// Per-month, per-kind total (bar chart + savings trend).
/// [month] is 'yyyy-MM', [kind] is 'income' | 'expense'.
typedef MonthlyTotal = ({String month, String kind, int total});

/// Per-kind total for a period.
typedef KindTotal = ({String kind, int total});

/// Per-day, per-kind total. [day] is 'yyyy-MM-dd'.
typedef DailyTotal = ({String day, String kind, int total});

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
  DebtPayments,
  GoalDeposits,
  RecurringTransactions,
  TransactionTemplates,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 8;

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
          if (from < 3) {
            await m.createTable(debtPayments);
            await m.addColumn(debts, debts.walletId);
            await m.addColumn(debts, debts.createdAt);
          }
          if (from < 4) {
            await m.addColumn(wallets, wallets.initialAmount);
            // Best-effort backfill: current balance is the closest known
            // starting point for pre-v4 wallets.
            await customUpdate(
              'UPDATE wallets SET initial_amount = balance',
              updates: {wallets},
            );
            await m.createTable(goalDeposits);
          }
          if (from < 5) {
            // Indexes for hot filter columns (fresh installs get them via
            // createAll; this covers upgrades from released versions).
            await m.createIndex(idxWalletsAccount);
            await m.createIndex(idxTransactionsDate);
            await m.createIndex(idxTransactionsWallet);
            await m.createIndex(idxTransactionsCategory);
            await m.createIndex(idxPhotosTransaction);
            await m.createIndex(idxBudgetsMonth);
            await m.createIndex(idxDebtsDirection);
            await m.createIndex(idxDebtPaymentsDebt);
            await m.createIndex(idxGoalDepositsGoal);
          }
          if (from < 6) {
            await m.addColumn(transactions, transactions.debtId);
            await m.addColumn(transactions, transactions.debtPaymentId);
            await m.addColumn(debts, debts.recordAsTransaction);
            await m.createIndex(idxTransactionsDebt);
            await m.createIndex(idxTransactionsDebtPayment);
            await _ensureDebtCategory();
          }
          if (from < 7) {
            await m.addColumn(categories, categories.sortOrder);
            // Preserve the previous alphabetical order as the initial
            // manual order, per (kind, parent) group.
            final all = await select(categories).get();
            final groups = <String, List<Category>>{};
            for (final c in all) {
              groups
                  .putIfAbsent('${c.kind}|${c.parentId}', () => [])
                  .add(c);
            }
            for (final group in groups.values) {
              group.sort((a, b) => a.name.compareTo(b.name));
              for (var i = 0; i < group.length; i++) {
                await (update(categories)
                      ..where((c) => c.id.equals(group[i].id)))
                    .write(CategoriesCompanion(sortOrder: Value(i)));
              }
            }
          }
          if (from < 8) {
            await m.createTable(recurringTransactions);
            await m.createTable(transactionTemplates);
            await m.addColumn(transactions, transactions.recurringId);
            await m.createIndex(idxRecurringNextDue);
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

  /// Signed wallet delta for a debt's creation movement:
  /// lending (receivable) takes money out, borrowing (payable) brings it in.
  int _debtWalletEffect(String direction, int amount) =>
      direction == 'receivable' ? -amount : amount;

  /// Signed wallet delta for a repayment:
  /// being repaid (receivable) brings money in, repaying (payable) takes it out.
  int _debtPaymentEffect(String direction, int amount) =>
      direction == 'receivable' ? amount : -amount;

  /// Note text for a debt-linked transaction.
  String _debtTxNote(String direction, String person, String note,
      {required bool payment}) {
    final base = payment
        ? (direction == 'receivable'
            ? 'Repayment from $person'
            : 'Repayment to $person')
        : (direction == 'receivable'
            ? 'Loan to $person'
            : 'Borrowed from $person');
    return note.isEmpty ? base : '$base · $note';
  }

  /// Hidden "Debt" category used by debt-linked transactions.
  /// Created on demand so it exists on fresh installs and upgrades alike.
  Future<int> get debtCategoryId async {
    final existing =
        await (select(categories)..where((c) => c.kind.equals('debt'))).get();
    if (existing.isNotEmpty) return existing.first.id;
    return into(categories).insert(CategoriesCompanion.insert(
      name: 'Debt',
      iconKey: const Value('handshake'),
      colorHex: const Value('#F472B6'),
      kind: 'debt',
    ));
  }

  Future<void> _ensureDebtCategory() async {
    await debtCategoryId;
  }

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
    q.orderBy([
      (c) => OrderingTerm.asc(c.sortOrder),
      (c) => OrderingTerm.asc(c.name),
    ]);
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

  /// Transactions touching one wallet (as source or transfer destination),
  /// newest first. Powers the wallet detail screen.
  Stream<List<TransactionWithDetails>> watchTransactionsForWallet(
      int walletId) {
    final q = _joinedTransactions()
      ..where(transactions.walletId.equals(walletId) |
          transactions.toWalletId.equals(walletId));
    return q.watch().map(_toDetails);
  }

  /// Transactions of one category inside [from, to]. Powers the budget
  /// detail screen (pass the month's first/last instant).
  Stream<List<TransactionWithDetails>> watchTransactionsForCategory(
      int categoryId, DateTime from, DateTime to) {
    final q = _joinedTransactions()
      ..where(transactions.categoryId.equals(categoryId) &
          transactions.date.isBetweenValues(from, to));
    return q.watch().map(_toDetails);
  }

  /// Per-category expense totals inside [from, to], largest first.
  /// The database aggregates; the UI only receives one row per category.
  Stream<List<CategoryTotal>> watchCategoryExpenseTotals(
      DateTime from, DateTime to) {
    final total = transactions.amount.sum();
    final q = selectOnly(transactions)
      ..addColumns([transactions.categoryId, total])
      ..where(transactions.kind.equals('expense') &
          transactions.date.isBetweenValues(from, to))
      ..groupBy([transactions.categoryId])
      ..orderBy([OrderingTerm.desc(total)]);
    return q.watch().map((rows) => rows
        .map((row) => (
              categoryId: row.read(transactions.categoryId)!,
              total: row.read(total) ?? 0,
            ))
        .toList());
  }

  /// Per-kind totals inside [from, to]: one row per kind present.
  /// Backs range summaries like the home balance card.
  Stream<List<KindTotal>> watchKindTotals(DateTime from, DateTime to) {
    final total = transactions.amount.sum();
    final q = selectOnly(transactions)
      ..addColumns([transactions.kind, total])
      ..where(transactions.date.isBetweenValues(from, to))
      ..groupBy([transactions.kind]);
    return q.watch().map((rows) => rows
        .map((row) => (
              kind: row.read(transactions.kind) ?? '',
              total: row.read(total) ?? 0,
            ))
        .toList());
  }

  /// Per-day, per-kind totals inside [from, to], oldest day first.
  /// [day] is 'yyyy-MM-dd'. Backs the 7-day sparklines.
  Stream<List<DailyTotal>> watchDailyKindTotals(
      DateTime from, DateTime to) {
    final dayExpr = CustomExpression<String>(
        "strftime('%Y-%m-%d', transactions.date, 'unixepoch', 'localtime')");
    final total = transactions.amount.sum();
    final q = selectOnly(transactions)
      ..addColumns([dayExpr, transactions.kind, total])
      ..where(transactions.date.isBetweenValues(from, to))
      ..groupBy([dayExpr, transactions.kind])
      ..orderBy([OrderingTerm.asc(dayExpr)]);
    return q.watch().map((rows) => rows
        .map((row) => (
              day: row.read(dayExpr) ?? '',
              kind: row.read(transactions.kind) ?? '',
              total: row.read(total) ?? 0,
            ))
        .toList());
  }

  /// Per-month income/expense totals inside [from, to], oldest month first.
  /// Backs the 6-month bar chart and the net-savings trend.
  Stream<List<MonthlyTotal>> watchMonthlyKindTotals(
      DateTime from, DateTime to) {
    final monthExpr = CustomExpression<String>(
        "strftime('%Y-%m', transactions.date, 'unixepoch', 'localtime')");
    final total = transactions.amount.sum();
    final q = selectOnly(transactions)
      ..addColumns([monthExpr, transactions.kind, total])
      ..where(transactions.date.isBetweenValues(from, to))
      ..groupBy([monthExpr, transactions.kind])
      ..orderBy([OrderingTerm.asc(monthExpr)]);
    return q.watch().map((rows) => rows
        .map((row) => (
              month: row.read(monthExpr) ?? '',
              kind: row.read(transactions.kind) ?? '',
              total: row.read(total) ?? 0,
            ))
        .toList());
  }

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

  /// Re-inserts a previously deleted transaction with its original id,
  /// re-applying its wallet balance effect and photo attachments.
  /// Backs the "Undo" action offered right after a delete. The receipt
  /// files themselves are left on disk by [deleteTransaction], so the
  /// restored photo rows point at valid files again.
  Future<void> restoreTransaction(
      Transaction t, List<TransactionPhoto> photos) {
    return transaction(() async {
      await into(transactions).insert(t.toCompanion(false));
      switch (t.kind) {
        case 'income':
          await adjustWalletBalance(t.walletId, t.amount);
        case 'expense':
          await adjustWalletBalance(t.walletId, -t.amount);
        case 'transfer':
          if (t.toWalletId != null) {
            await adjustWalletBalance(t.walletId, -t.amount);
            await adjustWalletBalance(t.toWalletId!, t.amount);
          }
      }
      for (final p in photos) {
        await into(transactionPhotos).insert(
          TransactionPhotosCompanion.insert(
            transactionId: t.id,
            path: p.path,
          ),
        );
      }
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

  /// Persists a manual drag-reorder: [orderedIds] is the new top-to-bottom
  /// order of one (kind, top-level) group.
  Future<void> reorderCategories(List<int> orderedIds) {
    return transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(categories)..where((c) => c.id.equals(orderedIds[i])))
            .write(CategoriesCompanion(sortOrder: Value(i)));
      }
    });
  }

  /// Attaches a photo to a transaction.
  ///
  /// The source file (e.g. the image_picker cache copy) is copied into the
  /// app's documents directory first, because the picker's cache path is
  /// not guaranteed to survive cache clears or app restarts. The stored
  /// path (our copy) is what gets saved in the database; the user's
  /// gallery original is never moved or modified.
  Future<String> addPhoto(int transactionId, String sourcePath) async {
    final docs = await getApplicationDocumentsDirectory();
    final receipts = Directory('${docs.path}/receipts');
    await receipts.create(recursive: true);
    final dot = sourcePath.lastIndexOf('.');
    final ext = (dot >= 0 && dot > sourcePath.lastIndexOf('/'))
        ? sourcePath.substring(dot + 1).toLowerCase()
        : 'jpg';
    final dest =
        '${receipts.path}/${DateTime.now().millisecondsSinceEpoch}_$transactionId.$ext';
    final stored = await File(sourcePath).copy(dest);
    await into(transactionPhotos).insert(
      TransactionPhotosCompanion.insert(
          transactionId: transactionId, path: stored.path),
    );
    return stored.path;
  }

  /// Removes a photo attachment. Our stored copy is deleted too; the
  /// user's original (gallery photo / camera roll) is always kept.
  Future<void> deletePhoto(int photoId) async {
    final row = await (select(transactionPhotos)
          ..where((p) => p.id.equals(photoId)))
        .getSingleOrNull();
    await (delete(transactionPhotos)..where((p) => p.id.equals(photoId))).go();
    if (row == null) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File(row.path);
      // Safety: only ever delete files inside our own receipts folder,
      // never the user's originals (covers rows stored before this fix).
      if (file.path.startsWith('${docs.path}/receipts')) {
        if (await file.exists()) await file.delete();
      }
    } catch (_) {
      // A missing file must never block removing the attachment record.
    }
  }

  Future<int> addWallet(WalletsCompanion entry) => into(wallets).insert(entry);

  /// Creates a wallet with its opening balance recorded as the initial amount.
  Future<int> createWallet({
    required int accountId,
    required String name,
    required String kind,
    int initialAmount = 0,
    String colorHex = '#C6FF4A',
  }) =>
      into(wallets).insert(WalletsCompanion.insert(
        accountId: accountId,
        name: name,
        kind: kind,
        balance: Value(initialAmount),
        initialAmount: Value(initialAmount),
        colorHex: Value(colorHex),
      ));

  Future<void> updateWallet({
    required int id,
    required String name,
    required String kind,
    String? colorHex,
  }) =>
      (update(wallets)..where((w) => w.id.equals(id))).write(
        WalletsCompanion(
          name: Value(name),
          kind: Value(kind),
          colorHex: colorHex == null ? const Value.absent() : Value(colorHex),
        ),
      );

  /// Sets a wallet's balance directly (Adjust Balance). The difference is
  /// absorbed as a correction — no transaction is created.
  Future<void> setWalletBalance(int id, int newBalance) =>
      (update(wallets)..where((w) => w.id.equals(id)))
          .write(WalletsCompanion(balance: Value(newBalance)));

  /// Deletes a wallet. Returns false when it still has transactions —
  /// those must be moved or deleted first.
  Future<bool> deleteWallet(int id) async {
    final txCount = await (select(transactions)
          ..where((t) =>
              t.walletId.equals(id) |
              t.toWalletId.equalsNullable(id)))
        .get();
    if (txCount.isNotEmpty) return false;
    await (delete(wallets)..where((w) => w.id.equals(id))).go();
    return true;
  }

  Future<int> addAccount(AccountsCompanion entry) =>
      into(accounts).insert(entry);

  Future<int> addCategory(CategoriesCompanion entry) => into(categories).insert(entry);

  Future<void> deleteCategory(int id) {
    return transaction(() async {
      await (delete(categories)..where((c) => c.parentId.equals(id))).go();
      await (delete(categories)..where((c) => c.id.equals(id))).go();
    });
  }

  Future<int> addBudget(BudgetsCompanion entry) => into(budgets).insert(entry);

  Future<void> updateBudgetLimit(int budgetId, int limit) =>
      (update(budgets)..where((b) => b.id.equals(budgetId)))
          .write(BudgetsCompanion(limit: Value(limit)));

  Future<void> deleteBudget(int budgetId) =>
      (delete(budgets)..where((b) => b.id.equals(budgetId))).go();

  Future<Budget?> getBudgetById(int id) =>
      (select(budgets)..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<int> addGoal(GoalsCompanion entry) => into(goals).insert(entry);

  Future<Goal?> getGoalById(int id) =>
      (select(goals)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<void> updateGoal({
    required int id,
    required String name,
    required int target,
    DateTime? deadline,
    String? colorHex,
  }) =>
      (update(goals)..where((g) => g.id.equals(id))).write(
        GoalsCompanion(
          name: Value(name),
          target: Value(target),
          deadline: Value(deadline),
          colorHex: colorHex == null ? const Value.absent() : Value(colorHex),
        ),
      );

  Future<void> deleteGoal(int id) {
    return transaction(() async {
      await (delete(goalDeposits)..where((d) => d.goalId.equals(id))).go();
      await (delete(goals)..where((g) => g.id.equals(id))).go();
    });
  }

  Stream<List<GoalDeposit>> watchGoalDeposits(int goalId) =>
      (select(goalDeposits)
            ..where((d) => d.goalId.equals(goalId))
            ..orderBy([(d) => OrderingTerm.desc(d.date)]))
          .watch();

  /// Records a deposit (positive) or withdrawal (negative) against a goal,
  /// keeping the goal's saved total in sync.
  Future<void> recordGoalDeposit({
    required int goalId,
    required int amount,
    required DateTime date,
    String note = '',
  }) {
    return transaction(() async {
      final goal = await getGoalById(goalId);
      if (goal == null) return;
      await into(goalDeposits).insert(GoalDepositsCompanion.insert(
        goalId: goalId,
        amount: amount,
        date: date,
        note: Value(note),
      ));
      await updateGoalSaved(goalId, goal.saved + amount);
    });
  }

  /// Deletes one deposit/withdrawal entry, reversing the saved total.
  Future<void> deleteGoalDeposit(GoalDeposit deposit) {
    return transaction(() async {
      final goal = await getGoalById(deposit.goalId);
      await (delete(goalDeposits)..where((d) => d.id.equals(deposit.id))).go();
      if (goal != null) {
        await updateGoalSaved(deposit.goalId, goal.saved - deposit.amount);
      }
    });
  }

  Future<void> updateGoalSaved(int id, int saved) =>
      (update(goals)..where((g) => g.id.equals(id)))
          .write(GoalsCompanion(saved: Value(saved)));

  Future<int> addDebt(DebtsCompanion entry) => into(debts).insert(entry);

  /// Creates a debt and moves the linked wallet balance:
  /// lending takes money out, borrowing brings money in.
  Future<int> createDebt({
    required String person,
    required String note,
    required int amount,
    required String direction,
    DateTime? dueDate,
    int? walletId,
    String colorHex = '#A78BFA',
    bool recordAsTransaction = true,
    DateTime? createdAt,
  }) {
    return transaction(() async {
      final now = createdAt ?? DateTime.now();
      final id = await into(debts).insert(DebtsCompanion.insert(
        person: person,
        note: Value(note),
        amount: amount,
        direction: direction,
        dueDate: Value(dueDate),
        walletId: Value(walletId),
        colorHex: Value(colorHex),
        recordAsTransaction: Value(recordAsTransaction),
        createdAt: Value(now),
      ));
      if (walletId != null) {
        if (recordAsTransaction) {
          final catId = await debtCategoryId;
          await into(transactions).insert(TransactionsCompanion.insert(
            walletId: walletId,
            categoryId: catId,
            kind: direction == 'receivable' ? 'expense' : 'income',
            amount: amount,
            note:
                Value(_debtTxNote(direction, person, note, payment: false)),
            date: now,
            debtId: Value(id),
          ));
        }
        await adjustWalletBalance(
            walletId, _debtWalletEffect(direction, amount));
      }
      return id;
    });
  }

  Future<Debt?> getDebtById(int id) =>
      (select(debts)..where((d) => d.id.equals(id))).getSingleOrNull();

  /// Updates a debt's fields, keeping the wallet movement in sync when the
  /// amount changes, and re-evaluating the paid state.
  Future<void> updateDebt({
    required int id,
    required String person,
    required String note,
    required int amount,
    DateTime? dueDate,
    int? walletId,
    required bool recordAsTransaction,
  }) {
    return transaction(() async {
      final old = await getDebtById(id);
      if (old == null) return;
      await (update(debts)..where((d) => d.id.equals(id))).write(
        DebtsCompanion(
          person: Value(person),
          note: Value(note),
          amount: Value(amount),
          dueDate: Value(dueDate),
          walletId: Value(walletId),
          recordAsTransaction: Value(recordAsTransaction),
        ),
      );

      // The creation entry is the debt-linked transaction without a
      // payment link; payment entries carry debtPaymentId.
      final linkedTx = await (select(transactions)
            ..where((t) =>
                t.debtId.equals(id) & t.debtPaymentId.isNull()))
          .getSingleOrNull();

      // Undo the old wallet effect, however it was applied.
      if (linkedTx != null) {
        await _reverseBalanceEffect(linkedTx);
      } else if (old.walletId != null) {
        await adjustWalletBalance(
            old.walletId!, -_debtWalletEffect(old.direction, old.amount));
      }

      // Apply the new wallet effect, with or without a history entry.
      if (recordAsTransaction && walletId != null) {
        final catId = await debtCategoryId;
        final kind = old.direction == 'receivable' ? 'expense' : 'income';
        final txNote =
            _debtTxNote(old.direction, person, note, payment: false);
        if (linkedTx != null) {
          await (update(transactions)..where((t) => t.id.equals(linkedTx.id)))
              .write(
            TransactionsCompanion(
              walletId: Value(walletId),
              categoryId: Value(catId),
              kind: Value(kind),
              amount: Value(amount),
              note: Value(txNote),
              date: Value(linkedTx.date),
            ),
          );
        } else {
          await into(transactions).insert(TransactionsCompanion.insert(
            walletId: walletId,
            categoryId: catId,
            kind: kind,
            amount: amount,
            note: Value(txNote),
            date: old.createdAt,
            debtId: Value(id),
          ));
        }
        await adjustWalletBalance(
            walletId, _debtWalletEffect(old.direction, amount));
      } else {
        if (linkedTx != null) {
          // The entry is no longer wanted — drop the orphaned row.
          await (delete(transactions)..where((t) => t.id.equals(linkedTx.id)))
              .go();
        }
        if (walletId != null) {
          await adjustWalletBalance(
              walletId, _debtWalletEffect(old.direction, amount));
        }
      }

      final paidTotal = await debtPaidTotal(id);
      await setDebtPaid(id, paidTotal >= amount);
    });
  }

  /// Deletes a debt, reversing the initial wallet movement and every
  /// recorded payment so balances stay consistent.
  Future<void> deleteDebt(int id) {
    return transaction(() async {
      final debt = await getDebtById(id);
      if (debt == null) return;
      // Reverse every debt-linked history entry via its own effect.
      final linked =
          await (select(transactions)..where((t) => t.debtId.equals(id)))
              .get();
      for (final t in linked) {
        await _reverseBalanceEffect(t);
      }
      if (linked.isNotEmpty) {
        await (delete(transactions)..where((t) => t.debtId.equals(id))).go();
      }
      // Legacy/manual path: reverse effects that have no history entry.
      final hasCreationTx = linked.any((t) => t.debtPaymentId == null);
      if (!hasCreationTx && debt.walletId != null) {
        await adjustWalletBalance(debt.walletId!,
            -_debtWalletEffect(debt.direction, debt.amount));
      }
      final payments =
          await (select(debtPayments)..where((p) => p.debtId.equals(id))).get();
      for (final p in payments) {
        final hasTx = linked.any((t) => t.debtPaymentId == p.id);
        if (!hasTx && p.walletId != null) {
          await adjustWalletBalance(
              p.walletId!, -_debtPaymentEffect(debt.direction, p.amount));
        }
      }
      await (delete(debtPayments)..where((p) => p.debtId.equals(id))).go();
      await (delete(debts)..where((d) => d.id.equals(id))).go();
    });
  }

  Stream<List<DebtPayment>> watchDebtPayments(int debtId) =>
      (select(debtPayments)
            ..where((p) => p.debtId.equals(debtId))
            ..orderBy([(p) => OrderingTerm.desc(p.date)]))
          .watch();

  Future<int> debtPaidTotal(int debtId) async {
    final q = selectOnly(debtPayments)
      ..addColumns([debtPayments.amount.sum()])
      ..where(debtPayments.debtId.equals(debtId));
    final row = await q.getSingleOrNull();
    return row?.read(debtPayments.amount.sum()) ?? 0;
  }

  /// Records a partial repayment: moves the payment wallet balance
  /// (money back in for receivables, money out for payables) and marks
  /// the debt paid once fully covered.
  Future<void> recordDebtPayment({
    required Debt debt,
    required int amount,
    required DateTime date,
    String note = '',
    int? walletId,
  }) {
    return transaction(() async {
      final paymentId = await into(debtPayments).insert(
        DebtPaymentsCompanion.insert(
          debtId: debt.id,
          amount: amount,
          date: date,
          note: Value(note),
          walletId: Value(walletId),
        ),
      );
      if (walletId != null) {
        if (debt.recordAsTransaction) {
          final catId = await debtCategoryId;
          await into(transactions).insert(TransactionsCompanion.insert(
            walletId: walletId,
            categoryId: catId,
            kind: debt.direction == 'receivable' ? 'income' : 'expense',
            amount: amount,
            note: Value(_debtTxNote(debt.direction, debt.person, note,
                payment: true)),
            date: date,
            debtId: Value(debt.id),
            debtPaymentId: Value(paymentId),
          ));
        }
        await adjustWalletBalance(
            walletId, _debtPaymentEffect(debt.direction, amount));
      }
      final paidTotal = await debtPaidTotal(debt.id);
      if (paidTotal >= debt.amount && !debt.isPaid) {
        await setDebtPaid(debt.id, true);
      }
    });
  }

  /// Deletes one repayment, reversing its wallet movement.
  Future<void> deleteDebtPayment(DebtPayment payment, Debt debt) {
    return transaction(() async {
      final linkedTx = await (select(transactions)
            ..where((t) => t.debtPaymentId.equals(payment.id)))
          .getSingleOrNull();
      if (linkedTx != null) {
        await _reverseBalanceEffect(linkedTx);
        await (delete(transactions)..where((t) => t.id.equals(linkedTx.id)))
            .go();
      } else if (payment.walletId != null) {
        await adjustWalletBalance(payment.walletId!,
            -_debtPaymentEffect(debt.direction, payment.amount));
      }
      await (delete(debtPayments)..where((p) => p.id.equals(payment.id))).go();
      final paidTotal = await debtPaidTotal(debt.id);
      if (paidTotal < debt.amount && debt.isPaid) {
        await setDebtPaid(debt.id, false);
      }
    });
  }

  Future<void> setDebtPaid(int id, bool paid) =>
      (update(debts)..where((d) => d.id.equals(id)))
          .write(DebtsCompanion(isPaid: Value(paid)));

  Future<List<TransactionWithDetails>> getTransactionsInRange(
      DateTime from, DateTime to) async {
    final q = _joinedTransactions()
      ..where(transactions.date.isBetweenValues(from, to));
    return _toDetails(await q.get());
  }

  // ------------------------- recurring transactions ----------------------

  Stream<List<RecurringTransaction>> watchRecurringTransactions() =>
      (select(recurringTransactions)
            ..orderBy([(r) => OrderingTerm.asc(r.nextDue)]))
          .watch();

  Future<int> addRecurringTransaction(RecurringTransactionsCompanion entry) =>
      into(recurringTransactions).insert(entry);

  Future<void> updateRecurringTransaction(
          int id, RecurringTransactionsCompanion entry) =>
      (update(recurringTransactions)..where((r) => r.id.equals(id)))
          .write(entry);

  Future<void> deleteRecurringTransaction(int id) =>
      (delete(recurringTransactions)..where((r) => r.id.equals(id))).go();

  Future<void> setRecurringActive(int id, bool active) =>
      (update(recurringTransactions)..where((r) => r.id.equals(id)))
          .write(RecurringTransactionsCompanion(active: Value(active)));

  /// Materializes every due occurrence of active recurring rules as real
  /// transactions (linked via transactions.recurringId) and advances each
  /// rule's nextDue. Returns the number of generated transactions.
  /// Called on app start; safe to call repeatedly.
  Future<int> processDueRecurringTransactions() {
    return transaction(() async {
      final now = DateTime.now();
      final rules = await (select(recurringTransactions)
            ..where((r) => r.active.equals(true))
            ..where((r) => r.nextDue.isSmallerOrEqualValue(now)))
          .get();
      var generated = 0;
      for (final rule in rules) {
        var due = rule.nextDue;
        var guard = 0;
        // Catch up on missed occurrences (guarded against runaway rules).
        while (!due.isAfter(now) &&
            (rule.endDate == null || !due.isAfter(rule.endDate!)) &&
            guard < 36) {
          await into(transactions).insert(TransactionsCompanion.insert(
            walletId: rule.walletId,
            categoryId: rule.categoryId,
            kind: rule.kind,
            amount: rule.amount,
            note: Value(rule.note),
            date: due,
            recurringId: Value(rule.id),
          ));
          await adjustWalletBalance(
              rule.walletId, rule.kind == 'income' ? rule.amount : -rule.amount);
          generated++;
          due = _advanceRecurring(due, rule.frequency);
          guard++;
        }
        await (update(recurringTransactions)
              ..where((r) => r.id.equals(rule.id)))
            .write(RecurringTransactionsCompanion(nextDue: Value(due)));
      }
      return generated;
    });
  }

  DateTime _advanceRecurring(DateTime d, String frequency) {
    switch (frequency) {
      case 'daily':
        return d.add(const Duration(days: 1));
      case 'weekly':
        return d.add(const Duration(days: 7));
      case 'monthly':
        // DateTime normalizes month overflow (Dec -> Jan next year).
        return DateTime(d.year, d.month + 1, d.day, d.hour, d.minute);
      case 'yearly':
        return DateTime(d.year + 1, d.month, d.day, d.hour, d.minute);
      default:
        return d.add(const Duration(days: 30));
    }
  }

  // ------------------------- transaction templates -----------------------

  Stream<List<TransactionTemplate>> watchTransactionTemplates() =>
      (select(transactionTemplates)
            ..orderBy([
              (t) => OrderingTerm.desc(t.useCount),
              (t) => OrderingTerm.asc(t.name),
            ]))
          .watch();

  Future<int> addTransactionTemplate(TransactionTemplatesCompanion entry) =>
      into(transactionTemplates).insert(entry);

  Future<void> deleteTransactionTemplate(int id) =>
      (delete(transactionTemplates)..where((t) => t.id.equals(id))).go();

  Future<void> bumpTemplateUse(int id) async {
    final row =
        await (select(transactionTemplates)..where((t) => t.id.equals(id)))
            .getSingle();
    await (update(transactionTemplates)..where((t) => t.id.equals(id))).write(
        TransactionTemplatesCompanion(useCount: Value(row.useCount + 1)));
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
