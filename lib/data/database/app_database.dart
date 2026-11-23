import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/recurring_dates.dart';

part 'app_database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// Personal / Work / Family — unlimited accounts separating finances.
@TableIndex(name: 'idx_accounts_sync_id', columns: {#syncId}, unique: true)
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get kind => text()(); // personal | work | family
  TextColumn get colorHex =>
      text().withDefault(const Constant('#C6FF4A'))(); // v9
  /// Cross-device identity for Supabase sync (v18). A random UUID,
  /// assigned at creation; the v18 migration backfills existing rows.
  /// Also the local side of the server's primary key.
  TextColumn get syncId =>
      text().withDefault(const Constant('')).clientDefault(_newSyncId)();

  /// Last local modification; refreshed by every write helper.
  // SQL default is the epoch (0): SQLite forbids non-constant defaults
  // in ALTER TABLE ... ADD COLUMN, and the v17->v18 migration adds this
  // column to non-empty tables — `currentDateAndTime` threw "Cannot add
  // a column with non-constant default" on every first 3.0.0 launch,
  // leaving the app on the boot splash forever (2026-11-23).
  // The clientDefault still stamps "now" for inserts that omit it
  // (e.g. the seed), so behaviour is unchanged.
  DateTimeColumn get updatedAt => dateTime()
      .withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))
      .clientDefault(() => DateTime.now())();

  /// Soft-delete marker for sync. Local deletes still hard-delete the
  /// row — the outbox tombstone carries the sync id to the server.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Cash, bank accounts, e-wallets, credit cards.
@TableIndex(name: 'idx_wallets_account', columns: {#accountId})
@TableIndex(name: 'idx_wallets_sync_id', columns: {#syncId}, unique: true)
class Wallets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  TextColumn get name => text()();
  TextColumn get kind => text()(); // cash | bank | ewallet | credit
  IntColumn get balance =>
      integer().withDefault(const Constant(0))(); // whole IDR
  IntColumn get initialAmount => integer().withDefault(const Constant(0))();
  TextColumn get colorHex => text().withDefault(const Constant('#C6FF4A'))();

  /// Brand logo template id ('bca', 'gopay', …) or null for the generic
  /// kind-based mark. v12.
  TextColumn get logoTemplate => text().nullable()();

  /// Manual ordering for the Arrange Wallets screen. v13.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Credit limit for paylater wallets (whole IDR). v15. Named
  /// `creditLimit` rather than `limit`: `limit` is a SQLite reserved word
  /// and would make drift generate broken SQL.
  IntColumn get creditLimit => integer().nullable()();

  /// Day of the month the statement closes (1-31). v15.
  IntColumn get statementDay => integer().nullable()();

  /// Day of the month payment is due (1-31). v15.
  IntColumn get dueDay => integer().nullable()();

  /// Monthly interest/fee rate in percent (e.g. 2.5 means 2.5%/month). v15.
  /// This is a paylater cost rate — never a savings growth rate.
  RealColumn get interestRateMonthly => real().nullable()();

  /// Annual interest rate in percent (e.g. 4.0 means 4%/year). v16.
  /// Savings growth for bank/ewallet wallets only; kept separate from
  /// the paylater monthly cost rate above on purpose.
  RealColumn get interestRateAnnual => real().nullable()();

  /// Cross-device identity for Supabase sync (v18). A random UUID,
  /// assigned at creation; the v18 migration backfills existing rows.
  /// Also the local side of the server's primary key.
  TextColumn get syncId =>
      text().withDefault(const Constant('')).clientDefault(_newSyncId)();

  /// Last local modification; refreshed by every write helper.
  // SQL default is the epoch (0): SQLite forbids non-constant defaults
  // in ALTER TABLE ... ADD COLUMN, and the v17->v18 migration adds this
  // column to non-empty tables — `currentDateAndTime` threw "Cannot add
  // a column with non-constant default" on every first 3.0.0 launch,
  // leaving the app on the boot splash forever (2026-11-23).
  // The clientDefault still stamps "now" for inserts that omit it
  // (e.g. the seed), so behaviour is unchanged.
  DateTimeColumn get updatedAt => dateTime()
      .withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))
      .clientDefault(() => DateTime.now())();

  /// Soft-delete marker for sync. Local deletes still hard-delete the
  /// row — the outbox tombstone carries the sync id to the server.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Expense / income categories; parentId == null means top-level.
@TableIndex(name: 'idx_categories_sync_id', columns: {#syncId}, unique: true)
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get iconKey => text().withDefault(const Constant('other'))();
  TextColumn get colorHex => text().withDefault(const Constant('#A78BFA'))();
  TextColumn get kind => text()(); // income | expense
  IntColumn get parentId => integer().nullable().references(Categories, #id)();

  /// Manual ordering for the Manage Categories screen (per kind group).
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Cross-device identity for Supabase sync (v18). A random UUID,
  /// assigned at creation; the v18 migration backfills existing rows.
  /// Also the local side of the server's primary key.
  TextColumn get syncId =>
      text().withDefault(const Constant('')).clientDefault(_newSyncId)();

  /// Last local modification; refreshed by every write helper.
  // SQL default is the epoch (0): SQLite forbids non-constant defaults
  // in ALTER TABLE ... ADD COLUMN, and the v17->v18 migration adds this
  // column to non-empty tables — `currentDateAndTime` threw "Cannot add
  // a column with non-constant default" on every first 3.0.0 launch,
  // leaving the app on the boot splash forever (2026-11-23).
  // The clientDefault still stamps "now" for inserts that omit it
  // (e.g. the seed), so behaviour is unchanged.
  DateTimeColumn get updatedAt => dateTime()
      .withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))
      .clientDefault(() => DateTime.now())();

  /// Soft-delete marker for sync. Local deletes still hard-delete the
  /// row — the outbox tombstone carries the sync id to the server.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@TableIndex(name: 'idx_transactions_date', columns: {#date})
@TableIndex(name: 'idx_transactions_wallet', columns: {#walletId})
@TableIndex(name: 'idx_transactions_category', columns: {#categoryId})
@TableIndex(name: 'idx_transactions_debt', columns: {#debtId})
@TableIndex(name: 'idx_transactions_debt_payment', columns: {#debtPaymentId})
@TableIndex(name: 'idx_transactions_transfer', columns: {#transferId})
@TableIndex(name: 'idx_transactions_sync_id', columns: {#syncId}, unique: true)
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get walletId => integer().references(Wallets, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get kind => text()(); // income | expense | transfer
  IntColumn get amount => integer()(); // whole IDR, always positive
  /// Mandatory description of the transaction (the primary text field).
  TextColumn get note => text().withDefault(const Constant(''))();

  /// Optional freeform memo.
  TextColumn get memo => text().withDefault(const Constant(''))();
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

  /// For a transfer-fee expense row: the transfer it belongs to.
  IntColumn get transferId =>
      integer().nullable().references(Transactions, #id)();

  /// For a paylater plan's purchase expense and its installment
  /// payments: the plan they belong to. Lets plan deletion remove its
  /// transactions and lets a plan show its own history.
  IntColumn get planId =>
      integer().nullable().references(InstallmentPlans, #id)();

  /// Cross-device identity for Supabase sync (v18). A random UUID,
  /// assigned at creation; the v18 migration backfills existing rows.
  /// Also the local side of the server's primary key.
  TextColumn get syncId =>
      text().withDefault(const Constant('')).clientDefault(_newSyncId)();

  /// Last local modification; refreshed by every write helper.
  // SQL default is the epoch (0): SQLite forbids non-constant defaults
  // in ALTER TABLE ... ADD COLUMN, and the v17->v18 migration adds this
  // column to non-empty tables — `currentDateAndTime` threw "Cannot add
  // a column with non-constant default" on every first 3.0.0 launch,
  // leaving the app on the boot splash forever (2026-11-23).
  // The clientDefault still stamps "now" for inserts that omit it
  // (e.g. the seed), so behaviour is unchanged.
  DateTimeColumn get updatedAt => dateTime()
      .withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))
      .clientDefault(() => DateTime.now())();

  /// Soft-delete marker for sync. Local deletes still hard-delete the
  /// row — the outbox tombstone carries the sync id to the server.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Receipt / record photos attached to a transaction ("Save Photos").
@TableIndex(name: 'idx_photos_transaction', columns: {#transactionId})
@TableIndex(
  name: 'idx_transaction_photos_sync_id',
  columns: {#syncId},
  unique: true,
)
class TransactionPhotos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().references(Transactions, #id)();
  TextColumn get path => text()();

  /// Storage object key for this photo in the `receipts` bucket
  /// (e.g. `receipts/<owner-uid>/<tx-sync-id>/<photo-sync-id>.jpg`),
  /// set once the bytes are uploaded (push) or the row is pulled.
  /// [path] stays a LOCAL filesystem path — the destination the
  /// bytes are downloaded to on demand — so the viewer, the
  /// receipts-folder safety guard in [AppDatabase.deletePhoto] and
  /// the backup service's basename path-rewrite all keep working
  /// unchanged. Null until the photo has ever been synced.
  TextColumn get remoteKey => text().nullable()();

  /// Cross-device identity for Supabase sync (v18). A random UUID,
  /// assigned at creation; the v18 migration backfills existing rows.
  /// Also the local side of the server's primary key.
  TextColumn get syncId =>
      text().withDefault(const Constant('')).clientDefault(_newSyncId)();

  /// Last local modification; refreshed by every write helper.
  // SQL default is the epoch (0): SQLite forbids non-constant defaults
  // in ALTER TABLE ... ADD COLUMN, and the v17->v18 migration adds this
  // column to non-empty tables — `currentDateAndTime` threw "Cannot add
  // a column with non-constant default" on every first 3.0.0 launch,
  // leaving the app on the boot splash forever (2026-11-23).
  // The clientDefault still stamps "now" for inserts that omit it
  // (e.g. the seed), so behaviour is unchanged.
  DateTimeColumn get updatedAt => dateTime()
      .withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))
      .clientDefault(() => DateTime.now())();

  /// Soft-delete marker for sync. Local deletes still hard-delete the
  /// row — the outbox tombstone carries the sync id to the server.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Per-category monthly spending limits.
@TableIndex(name: 'idx_budgets_month', columns: {#month})
@TableIndex(name: 'idx_budgets_sync_id', columns: {#syncId}, unique: true)
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get month => text()(); // yyyy-MM
  IntColumn get limit => integer()();

  /// Cross-device identity for Supabase sync (v18). A random UUID,
  /// assigned at creation; the v18 migration backfills existing rows.
  /// Also the local side of the server's primary key.
  TextColumn get syncId =>
      text().withDefault(const Constant('')).clientDefault(_newSyncId)();

  /// Last local modification; refreshed by every write helper.
  // SQL default is the epoch (0): SQLite forbids non-constant defaults
  // in ALTER TABLE ... ADD COLUMN, and the v17->v18 migration adds this
  // column to non-empty tables — `currentDateAndTime` threw "Cannot add
  // a column with non-constant default" on every first 3.0.0 launch,
  // leaving the app on the boot splash forever (2026-11-23).
  // The clientDefault still stamps "now" for inserts that omit it
  // (e.g. the seed), so behaviour is unchanged.
  DateTimeColumn get updatedAt => dateTime()
      .withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))
      .clientDefault(() => DateTime.now())();

  /// Soft-delete marker for sync. Local deletes still hard-delete the
  /// row — the outbox tombstone carries the sync id to the server.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@TableIndex(name: 'idx_goals_sync_id', columns: {#syncId}, unique: true)
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get target => integer()();
  IntColumn get saved => integer().withDefault(const Constant(0))();
  TextColumn get colorHex => text().withDefault(const Constant('#C6FF4A'))();
  DateTimeColumn get deadline => dateTime().nullable()();

  /// Cross-device identity for Supabase sync (v18). A random UUID,
  /// assigned at creation; the v18 migration backfills existing rows.
  /// Also the local side of the server's primary key.
  TextColumn get syncId =>
      text().withDefault(const Constant('')).clientDefault(_newSyncId)();

  /// Last local modification; refreshed by every write helper.
  // SQL default is the epoch (0): SQLite forbids non-constant defaults
  // in ALTER TABLE ... ADD COLUMN, and the v17->v18 migration adds this
  // column to non-empty tables — `currentDateAndTime` threw "Cannot add
  // a column with non-constant default" on every first 3.0.0 launch,
  // leaving the app on the boot splash forever (2026-11-23).
  // The clientDefault still stamps "now" for inserts that omit it
  // (e.g. the seed), so behaviour is unchanged.
  DateTimeColumn get updatedAt => dateTime()
      .withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))
      .clientDefault(() => DateTime.now())();

  /// Soft-delete marker for sync. Local deletes still hard-delete the
  /// row — the outbox tombstone carries the sync id to the server.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Money you owe (payable) and money owed to you (receivable).
@TableIndex(name: 'idx_debts_direction', columns: {#direction})
@TableIndex(name: 'idx_debts_sync_id', columns: {#syncId}, unique: true)
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

  /// Cross-device identity for Supabase sync (v18). A random UUID,
  /// assigned at creation; the v18 migration backfills existing rows.
  /// Also the local side of the server's primary key.
  TextColumn get syncId =>
      text().withDefault(const Constant('')).clientDefault(_newSyncId)();

  /// Last local modification; refreshed by every write helper.
  // SQL default is the epoch (0): SQLite forbids non-constant defaults
  // in ALTER TABLE ... ADD COLUMN, and the v17->v18 migration adds this
  // column to non-empty tables — `currentDateAndTime` threw "Cannot add
  // a column with non-constant default" on every first 3.0.0 launch,
  // leaving the app on the boot splash forever (2026-11-23).
  // The clientDefault still stamps "now" for inserts that omit it
  // (e.g. the seed), so behaviour is unchanged.
  DateTimeColumn get updatedAt => dateTime()
      .withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))
      .clientDefault(() => DateTime.now())();

  /// Soft-delete marker for sync. Local deletes still hard-delete the
  /// row — the outbox tombstone carries the sync id to the server.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Partial repayments recorded against a debt.
@TableIndex(name: 'idx_debt_payments_debt', columns: {#debtId})
@TableIndex(name: 'idx_debt_payments_sync_id', columns: {#syncId}, unique: true)
class DebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get debtId => integer().references(Debts, #id)();
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get walletId => integer().nullable().references(Wallets, #id)();

  /// Cross-device identity for Supabase sync (v18). A random UUID,
  /// assigned at creation; the v18 migration backfills existing rows.
  /// Also the local side of the server's primary key.
  TextColumn get syncId =>
      text().withDefault(const Constant('')).clientDefault(_newSyncId)();

  /// Last local modification; refreshed by every write helper.
  // SQL default is the epoch (0): SQLite forbids non-constant defaults
  // in ALTER TABLE ... ADD COLUMN, and the v17->v18 migration adds this
  // column to non-empty tables — `currentDateAndTime` threw "Cannot add
  // a column with non-constant default" on every first 3.0.0 launch,
  // leaving the app on the boot splash forever (2026-11-23).
  // The clientDefault still stamps "now" for inserts that omit it
  // (e.g. the seed), so behaviour is unchanged.
  DateTimeColumn get updatedAt => dateTime()
      .withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))
      .clientDefault(() => DateTime.now())();

  /// Soft-delete marker for sync. Local deletes still hard-delete the
  /// row — the outbox tombstone carries the sync id to the server.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Deposit / withdrawal history for a savings goal.
/// Positive amount = deposit, negative = withdrawal.
@TableIndex(name: 'idx_goal_deposits_goal', columns: {#goalId})
@TableIndex(name: 'idx_goal_deposits_sync_id', columns: {#syncId}, unique: true)
class GoalDeposits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get goalId => integer().references(Goals, #id)();
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();

  /// Cross-device identity for Supabase sync (v18). A random UUID,
  /// assigned at creation; the v18 migration backfills existing rows.
  /// Also the local side of the server's primary key.
  TextColumn get syncId =>
      text().withDefault(const Constant('')).clientDefault(_newSyncId)();

  /// Last local modification; refreshed by every write helper.
  // SQL default is the epoch (0): SQLite forbids non-constant defaults
  // in ALTER TABLE ... ADD COLUMN, and the v17->v18 migration adds this
  // column to non-empty tables — `currentDateAndTime` threw "Cannot add
  // a column with non-constant default" on every first 3.0.0 launch,
  // leaving the app on the boot splash forever (2026-11-23).
  // The clientDefault still stamps "now" for inserts that omit it
  // (e.g. the seed), so behaviour is unchanged.
  DateTimeColumn get updatedAt => dateTime()
      .withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))
      .clientDefault(() => DateTime.now())();

  /// Soft-delete marker for sync. Local deletes still hard-delete the
  /// row — the outbox tombstone carries the sync id to the server.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Recurring income/expense rules (subscriptions, salary, rent).
/// Due occurrences are materialized as real transactions on app start.
@TableIndex(name: 'idx_recurring_next_due', columns: {#nextDue})
@TableIndex(
  name: 'idx_recurring_transactions_sync_id',
  columns: {#syncId},
  unique: true,
)
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

  /// Cross-device identity for Supabase sync (v18). A random UUID,
  /// assigned at creation; the v18 migration backfills existing rows.
  /// Also the local side of the server's primary key.
  TextColumn get syncId =>
      text().withDefault(const Constant('')).clientDefault(_newSyncId)();

  /// Last local modification; refreshed by every write helper.
  // SQL default is the epoch (0): SQLite forbids non-constant defaults
  // in ALTER TABLE ... ADD COLUMN, and the v17->v18 migration adds this
  // column to non-empty tables — `currentDateAndTime` threw "Cannot add
  // a column with non-constant default" on every first 3.0.0 launch,
  // leaving the app on the boot splash forever (2026-11-23).
  // The clientDefault still stamps "now" for inserts that omit it
  // (e.g. the seed), so behaviour is unchanged.
  DateTimeColumn get updatedAt => dateTime()
      .withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))
      .clientDefault(() => DateTime.now())();

  /// Soft-delete marker for sync. Local deletes still hard-delete the
  /// row — the outbox tombstone carries the sync id to the server.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// One-tap transaction templates for the add-transaction sheet.
@TableIndex(
  name: 'idx_transaction_templates_sync_id',
  columns: {#syncId},
  unique: true,
)
class TransactionTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get walletId => integer().references(Wallets, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get kind => text()(); // income | expense
  IntColumn get amount => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get useCount => integer().withDefault(const Constant(0))();

  /// Cross-device identity for Supabase sync (v18). A random UUID,
  /// assigned at creation; the v18 migration backfills existing rows.
  /// Also the local side of the server's primary key.
  TextColumn get syncId =>
      text().withDefault(const Constant('')).clientDefault(_newSyncId)();

  /// Last local modification; refreshed by every write helper.
  // SQL default is the epoch (0): SQLite forbids non-constant defaults
  // in ALTER TABLE ... ADD COLUMN, and the v17->v18 migration adds this
  // column to non-empty tables — `currentDateAndTime` threw "Cannot add
  // a column with non-constant default" on every first 3.0.0 launch,
  // leaving the app on the boot splash forever (2026-11-23).
  // The clientDefault still stamps "now" for inserts that omit it
  // (e.g. the seed), so behaviour is unchanged.
  DateTimeColumn get updatedAt => dateTime()
      .withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))
      .clientDefault(() => DateTime.now())();

  /// Soft-delete marker for sync. Local deletes still hard-delete the
  /// row — the outbox tombstone carries the sync id to the server.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Learned keyword → category associations backing smart category
/// suggestions. [hits] counts how many saved transactions with [keyword]
/// in their note used [categoryId]. All learning happens on-device.
@TableIndex(
  name: 'idx_category_keywords_sync_id',
  columns: {#syncId},
  unique: true,
)
class CategoryKeywords extends Table {
  TextColumn get keyword => text()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get hits => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {keyword, categoryId};

  /// Cross-device identity for Supabase sync (v18). Deterministic,
  /// NOT a random UUID: 'kw:' || keyword || ':' || category sync id
  /// (see [_keywordSyncId]) — two devices learning the same keyword
  /// produce the same id. The v18 migration backfills existing rows.
  TextColumn get syncId => text().withDefault(const Constant(''))();

  /// Last local modification; refreshed by every write helper.
  // SQL default is the epoch (0): SQLite forbids non-constant defaults
  // in ALTER TABLE ... ADD COLUMN, and the v17->v18 migration adds this
  // column to non-empty tables — `currentDateAndTime` threw "Cannot add
  // a column with non-constant default" on every first 3.0.0 launch,
  // leaving the app on the boot splash forever (2026-11-23).
  // The clientDefault still stamps "now" for inserts that omit it
  // (e.g. the seed), so behaviour is unchanged.
  DateTimeColumn get updatedAt => dateTime()
      .withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))
      .clientDefault(() => DateTime.now())();

  /// Soft-delete marker for sync. Local deletes still hard-delete the
  /// row — the outbox tombstone carries the sync id to the server.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// A multi-month paylater purchase: total split into [totalCount] monthly
/// installments of [installmentAmount]. v15. Progress is tracked by
/// [paidCount] only — installments are not auto-posted as transactions.
@TableIndex(
  name: 'idx_installment_plans_sync_id',
  columns: {#syncId},
  unique: true,
)
class InstallmentPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get walletId => integer().references(Wallets, #id)();
  TextColumn get name => text()();
  IntColumn get totalAmount => integer()();
  IntColumn get installmentAmount => integer()();
  IntColumn get totalCount => integer()();
  IntColumn get paidCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Cross-device identity for Supabase sync (v18). A random UUID,
  /// assigned at creation; the v18 migration backfills existing rows.
  /// Also the local side of the server's primary key.
  TextColumn get syncId =>
      text().withDefault(const Constant('')).clientDefault(_newSyncId)();

  /// Last local modification; refreshed by every write helper.
  // SQL default is the epoch (0): SQLite forbids non-constant defaults
  // in ALTER TABLE ... ADD COLUMN, and the v17->v18 migration adds this
  // column to non-empty tables — `currentDateAndTime` threw "Cannot add
  // a column with non-constant default" on every first 3.0.0 launch,
  // leaving the app on the boot splash forever (2026-11-23).
  // The clientDefault still stamps "now" for inserts that omit it
  // (e.g. the seed), so behaviour is unchanged.
  DateTimeColumn get updatedAt => dateTime()
      .withDefault(Constant(DateTime.fromMillisecondsSinceEpoch(0)))
      .clientDefault(() => DateTime.now())();

  /// Soft-delete marker for sync. Local deletes still hard-delete the
  /// row — the outbox tombstone carries the sync id to the server.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

// ---------------------------------------------------------------------------
// Sync (Supabase, schema v18)
// ---------------------------------------------------------------------------

/// Fresh cross-device identity for a synced row.
String _newSyncId() => const Uuid().v4();

/// Deterministic sync id for a learned keyword row (see
/// `supabase/migrations/0001_init.sql`): 'kw:' || keyword || ':' ||
/// category sync id. Two devices learning the same keyword produce
/// the same id, so the server upsert merges instead of colliding on
/// the unique (owner_id, keyword, category_id) key.
String _keywordSyncId(String keyword, String categorySyncId) =>
    'kw:$keyword:$categorySyncId';

/// Outbox for Supabase sync (schema v18): one row per local mutation,
/// drained by the P2 push and removed on server ack. Entries are
/// written in the same transaction as the data change, so the two can
/// never disagree. Deletes are recorded here too — the row itself is
/// gone, but its sync id survives as a tombstone for the push.
class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get targetTable => text()();
  TextColumn get syncId => text()();

  /// 'insert' | 'update' | 'delete'.
  TextColumn get op => text()();
  DateTimeColumn get queuedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Single-row sync cursor (id is always 1): where the last pull
/// stopped and when the last sync ran. Read and written by the
/// P2/P3 sync engine; P1 only creates the table and its row.
class SyncState extends Table {
  IntColumn get id => integer()();
  TextColumn get lastPullCursor => text().nullable()();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
}

/// Last payload pushed to Supabase per sync id (schema v18, P2).
/// The push compares a row's current payload hash against this
/// record and skips the server call when nothing changed — the
/// server trigger bumps `server_updated_at` on every UPDATE, even a
/// no-op, so a blind re-push would churn every other device's pull
/// cursor. Deleted when the row's tombstone is pushed.
class SyncPushed extends Table {
  /// The row's sync id — globally unique across tables.
  TextColumn get syncId => text()();
  TextColumn get targetTable => text()();

  /// SHA-256 hex of the canonical JSON of the last pushed payload.
  TextColumn get hash => text()();
  DateTimeColumn get pushedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {syncId};
}

/// Rows overwritten by a pull (conflict keeper, schema v18, P3):
/// when last-write-wins replaces a row this device had previously
/// pushed, the losing local content is kept here as JSON so the
/// user can restore it from Settings. One entry per (table,
/// sync id) — a newer overwrite replaces the older loser. The
/// entry is deleted when the user restores or dismisses it.
/// Local-only bookkeeping: never synced, no outbox entry.
@TableIndex(
  name: 'idx_sync_conflicts_row',
  columns: {#targetTable, #syncId},
  unique: true,
)
class SyncConflicts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get targetTable => text()();
  TextColumn get syncId => text()();

  /// The losing row's full content as canonical JSON of the
  /// server-shaped payload (the shape the serialiser produces),
  /// so Restore can re-apply it through the pull-apply path.
  TextColumn get losingJson => text()();

  /// When the pull overwrote the local row.
  DateTimeColumn get overwrittenAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// Which device's edit won. Server rows carry no device id, so
  /// this stays null in P3 — kept for a future device tag.
  TextColumn get winningDevice => text().nullable()();
}

/// One sync run's outcome (P6 sync log, §8/§12): written by the
/// orchestrator after every cycle and by the first-run migration.
/// Local-only bookkeeping: never synced, no outbox entry. Capped
/// at the newest 50 rows ([recordSyncLog] prunes older ones) so
/// the log can never grow without bound on a device that syncs
/// every launch.
class SyncLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get pushed => integer().withDefault(const Constant(0))();
  IntColumn get pulled => integer().withDefault(const Constant(0))();
  IntColumn get conflicts => integer().withDefault(const Constant(0))();
  IntColumn get failed => integer().withDefault(const Constant(0))();

  /// Named failure mode of the run, if it failed — the failure
  /// mode name ('offline', 'authExpired', 'serverPaused',
  /// 'unknown'). Null on a clean run.
  TextColumn get failureMode => text().nullable()();

  /// The raw error message, if any (truncated at write time).
  /// Kept for debugging; the UI shows the named mode.
  TextColumn get error => text().nullable()();
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
typedef CategoryStat = ({int categoryId, int total, int count});

/// Per-month, per-kind total (bar chart + savings trend).
/// [month] is 'yyyy-MM', [kind] is 'income' | 'expense'.
typedef MonthlyTotal = ({String month, String kind, int total});

/// Per-kind total for a period.
typedef KindTotal = ({String kind, int total});

/// Per-day, per-kind total. [day] is 'yyyy-MM-dd'.
typedef DailyTotal = ({String day, String kind, int total});
typedef HourlyTotal = ({String hour, String kind, int total});

/// Cash-basis expressions for one transaction row: the source and
/// destination wallet aliases plus the effective kind/category
/// expressions built over them by the `_cashJoin` helper.
typedef _CashBasis = ({
  $WalletsTable src,
  $WalletsTable dst,
  CustomExpression<String> kind,
  CustomExpression<int> category,
});

/// What [reconcileDerivedState] changed: counts of rows whose
/// stored derived value differed from the recomputed one.
typedef DerivedReconcileResult = ({
  int walletsChanged,
  int plansChanged,
  int goalsChanged,
  int debtsChanged,
});

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(
  tables: [
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
    CategoryKeywords,
    InstallmentPlans,
    SyncOutbox,
    SyncState,
    SyncPushed,
    SyncConflicts,
    SyncLog,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 18;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seed();
      await into(
        syncState,
      ).insert(SyncStateCompanion.insert(id: 1));
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
          groups.putIfAbsent('${c.kind}|${c.parentId}', () => []).add(c);
        }
        for (final group in groups.values) {
          group.sort((a, b) => a.name.compareTo(b.name));
          for (var i = 0; i < group.length; i++) {
            await (update(categories)..where((c) => c.id.equals(group[i].id)))
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
      if (from < 9) {
        await m.addColumn(accounts, accounts.colorHex);
      }
      if (from < 10) {
        await m.createTable(categoryKeywords);
      }
      if (from < 11) {
        await m.addColumn(transactions, transactions.memo);
      }
      if (from < 12) {
        await m.addColumn(wallets, wallets.logoTemplate);
      }
      if (from < 13) {
        await m.addColumn(wallets, wallets.sortOrder);
        // Preserve the current (insertion) order as the initial
        // manual order.
        final all = await select(wallets).get();
        all.sort((a, b) => a.id.compareTo(b.id));
        for (var i = 0; i < all.length; i++) {
          await (update(wallets)..where((w) => w.id.equals(all[i].id))).write(
            WalletsCompanion(sortOrder: Value(i)),
          );
        }
      }
      if (from < 14) {
        await m.addColumn(transactions, transactions.transferId);
        await m.createIndex(idxTransactionsTransfer);
      }
      if (from < 15) {
        await m.addColumn(wallets, wallets.creditLimit);
        await m.addColumn(wallets, wallets.statementDay);
        await m.addColumn(wallets, wallets.dueDay);
        await m.addColumn(wallets, wallets.interestRateMonthly);
        await m.createTable(installmentPlans);
      }
      if (from < 16) {
        await m.addColumn(wallets, wallets.interestRateAnnual);
      }
      if (from < 17) {
        await m.addColumn(transactions, transactions.planId);
      }
      if (from < 18) {
        // Sync foundation (v3.0.0): cross-device identity + change
        // tracking for Supabase sync. New tables first, then the
        // three columns on every data table, then a backfill so no
        // row is left without an identity, and only then the unique
        // indexes — the columns land with the '' default, so the
        // indexes cannot exist before the backfill runs.
        await m.createTable(syncOutbox);
        await m.createTable(syncState);
        await m.createTable(syncPushed);
        // Conflict keeper (P3): folded into the unreleased v18
        // step — no shipped build has v18 yet, so no v19 is
        // needed. The unique index is created explicitly:
        // createTable only issues CREATE TABLE, not the indices.
        await m.createTable(syncConflicts);
        await m.createIndex(idxSyncConflictsRow);
        // Sync log (P6): folded into the unreleased v18 step —
        // no shipped build has v18 yet, so no v19 is needed.
        await m.createTable(syncLog);
        await into(
          syncState,
        ).insert(SyncStateCompanion.insert(id: 1));
        await m.addColumn(accounts, accounts.syncId);
        await m.addColumn(accounts, accounts.updatedAt);
        await m.addColumn(accounts, accounts.deletedAt);
        await m.addColumn(wallets, wallets.syncId);
        await m.addColumn(wallets, wallets.updatedAt);
        await m.addColumn(wallets, wallets.deletedAt);
        await m.addColumn(categories, categories.syncId);
        await m.addColumn(categories, categories.updatedAt);
        await m.addColumn(categories, categories.deletedAt);
        await m.addColumn(transactions, transactions.syncId);
        await m.addColumn(transactions, transactions.updatedAt);
        await m.addColumn(transactions, transactions.deletedAt);
        await m.addColumn(transactionPhotos, transactionPhotos.syncId);
        await m.addColumn(transactionPhotos, transactionPhotos.updatedAt);
        await m.addColumn(transactionPhotos, transactionPhotos.deletedAt);
        // P4 (photos): the Storage object key, folded into the
        // unreleased v18 step — no shipped build has v18 yet.
        await m.addColumn(transactionPhotos, transactionPhotos.remoteKey);
        await m.addColumn(budgets, budgets.syncId);
        await m.addColumn(budgets, budgets.updatedAt);
        await m.addColumn(budgets, budgets.deletedAt);
        await m.addColumn(goals, goals.syncId);
        await m.addColumn(goals, goals.updatedAt);
        await m.addColumn(goals, goals.deletedAt);
        await m.addColumn(debts, debts.syncId);
        await m.addColumn(debts, debts.updatedAt);
        await m.addColumn(debts, debts.deletedAt);
        await m.addColumn(debtPayments, debtPayments.syncId);
        await m.addColumn(debtPayments, debtPayments.updatedAt);
        await m.addColumn(debtPayments, debtPayments.deletedAt);
        await m.addColumn(goalDeposits, goalDeposits.syncId);
        await m.addColumn(goalDeposits, goalDeposits.updatedAt);
        await m.addColumn(goalDeposits, goalDeposits.deletedAt);
        await m.addColumn(recurringTransactions, recurringTransactions.syncId);
        await m.addColumn(
          recurringTransactions,
          recurringTransactions.updatedAt,
        );
        await m.addColumn(
          recurringTransactions,
          recurringTransactions.deletedAt,
        );
        await m.addColumn(transactionTemplates, transactionTemplates.syncId);
        await m.addColumn(transactionTemplates, transactionTemplates.updatedAt);
        await m.addColumn(transactionTemplates, transactionTemplates.deletedAt);
        await m.addColumn(categoryKeywords, categoryKeywords.syncId);
        await m.addColumn(categoryKeywords, categoryKeywords.updatedAt);
        await m.addColumn(categoryKeywords, categoryKeywords.deletedAt);
        await m.addColumn(installmentPlans, installmentPlans.syncId);
        await m.addColumn(installmentPlans, installmentPlans.updatedAt);
        await m.addColumn(installmentPlans, installmentPlans.deletedAt);
        await backfillMissingSyncIds();
        await m.createIndex(idxAccountsSyncId);
        await m.createIndex(idxWalletsSyncId);
        await m.createIndex(idxCategoriesSyncId);
        await m.createIndex(idxTransactionsSyncId);
        await m.createIndex(idxTransactionPhotosSyncId);
        await m.createIndex(idxBudgetsSyncId);
        await m.createIndex(idxGoalsSyncId);
        await m.createIndex(idxDebtsSyncId);
        await m.createIndex(idxDebtPaymentsSyncId);
        await m.createIndex(idxGoalDepositsSyncId);
        await m.createIndex(idxRecurringTransactionsSyncId);
        await m.createIndex(idxTransactionTemplatesSyncId);
        await m.createIndex(idxCategoryKeywordsSyncId);
        await m.createIndex(idxInstallmentPlansSyncId);
      }
    },
  );

  // ------------------------------- sync --------------------------------

  /// Records one local mutation for the P2 push. Must be called in the
  /// same transaction as the data change — every write helper below
  /// does exactly that, so an outbox entry and its row can never
  /// disagree. [op] is 'insert', 'update' or 'delete'.
  Future<void> _enqueueOutbox(String tableName, String syncId, String op) {
    return into(syncOutbox).insert(
      SyncOutboxCompanion.insert(targetTable: tableName, syncId: syncId, op: op),
    );
  }

  /// Public form of [_enqueueOutbox] for the conflict keeper's
  /// Restore: the restored row is a new local edit, so it gets an
  /// outbox entry and the next push sends it as the newest change.
  Future<void> enqueueOutbox(String tableName, String syncId, String op) =>
      _enqueueOutbox(tableName, syncId, op);

  /// Sync id to store for a companion-built insert: keep the caller's
  /// when present, else a fresh UUID. (Restores re-insert with the
  /// original id; everything else lets the helper generate one.)
  String _companionSyncId(Value<String> present) =>
      present.present ? present.value : _newSyncId();

  /// Assigns a sync id (and a fresh [updatedAt]) to every synced row
  /// that does not have one yet. Used by the v17→v18 migration — the
  /// new column lands with the '' default on every existing row —
  /// and by backup restore, which copies rows from pre-v18 backups
  /// that have no sync ids at all. Categories are backfilled before
  /// keywords: a keyword's sync id is derived from its category's.
  /// Rows that already have a sync id are untouched.
  Future<void> backfillMissingSyncIds() async {
    const idTables = [
      'accounts',
      'categories',
      'wallets',
      'goals',
      'installment_plans',
      'debts',
      'debt_payments',
      'goal_deposits',
      'recurring_transactions',
      'transaction_templates',
      'transactions',
      'transaction_photos',
      'budgets',
    ];
    final now = DateTime.now();
    for (final table in idTables) {
      final rows = await customSelect(
        'SELECT id FROM "$table" WHERE sync_id = \'\'',
        readsFrom: {},
      ).get();
      for (final row in rows) {
        await customUpdate(
          'UPDATE "$table" SET sync_id = ?, updated_at = ? WHERE id = ?',
          variables: [
            Variable.withString(_newSyncId()),
            Variable.withDateTime(now),
            Variable.withInt(row.read<int>('id')),
          ],
          updates: {},
        );
      }
    }
    // Keywords carry no integer id: their sync id is deterministic —
    // 'kw:' || keyword || ':' || category sync id — so two devices
    // learning the same keyword produce the same id (see
    // 0001_init.sql). An orphaned keyword (its category is gone)
    // falls back to a random id so the row is still syncable.
    final keywords = await customSelect(
      'SELECT keyword, category_id FROM category_keywords '
      "WHERE sync_id = ''",
      readsFrom: {},
    ).get();
    for (final row in keywords) {
      final keyword = row.read<String>('keyword');
      final categoryId = row.read<int>('category_id');
      final category = await (select(
        categories,
      )..where((c) => c.id.equals(categoryId))).getSingleOrNull();
      final syncId = category == null
          ? _newSyncId()
          : _keywordSyncId(keyword, category.syncId);
      await customUpdate(
        'UPDATE category_keywords SET sync_id = ?, updated_at = ? '
        'WHERE keyword = ? AND category_id = ?',
        variables: [
          Variable.withString(syncId),
          Variable.withDateTime(now),
          Variable.withString(keyword),
          Variable.withInt(categoryId),
        ],
        updates: {},
      );
    }
  }

  /// Resets sync state after a backup restore (P2 decision — see the
  /// concept doc §5). The restored database replaces every row, so
  /// pre-restore outbox entries describe row states that no longer
  /// exist, the pushed-hash records describe payloads that may no
  /// longer match, and the pull cursor points at a server state the
  /// local data no longer matches. So: clear the outbox and the hash
  /// records, re-enqueue every restored row as an insert (the server
  /// upsert is idempotent, so the restored state becomes the seed),
  /// and reset the pull cursor so P3 pulls from the beginning.
  /// Must be called inside the restore transaction.
  Future<void> resetSyncAfterRestore() async {
    const tables = [
      'accounts',
      'wallets',
      'categories',
      'category_keywords',
      'recurring_transactions',
      'transaction_templates',
      'installment_plans',
      'transactions',
      'transaction_photos',
      'budgets',
      'goals',
      'goal_deposits',
      'debts',
      'debt_payments',
    ];
    await customStatement('DELETE FROM sync_outbox');
    await customStatement('DELETE FROM sync_pushed');
    for (final table in tables) {
      await customStatement(
        "INSERT INTO sync_outbox (target_table, sync_id, op) "
        "SELECT '$table', sync_id, 'insert' FROM \"$table\" "
        "WHERE sync_id <> ''",
      );
    }
    await customUpdate(
      'UPDATE sync_state SET last_pull_cursor = NULL, '
      'last_sync_at = NULL WHERE id = 1',
      variables: const [],
      updates: {syncState},
    );
  }

  /// Watches the sync_state row (P5 status UI): last pull cursor +
  /// last sync time. Null before the first sync (the row is
  /// created in onCreate, so in practice it exists with nulls).
  Stream<SyncStateData?> watchSyncState() =>
      (select(syncState)..where((s) => s.id.equals(1))).watchSingleOrNull();

  /// Watches the number of pending outbox entries (P5 status UI +
  /// the save trigger). The outbox is small, so counting the
  /// watched rows is cheaper than a selectOnly count query.
  Stream<int> watchOutboxCount() =>
      select(syncOutbox).watch().map((rows) => rows.length);

  /// Wipes every synced table for a first-run migration (P5, §11):
  /// children first, then the outbox, the pushed-hash log and the
  /// conflict keeper, and the pull cursor reset so the next pull
  /// starts from the beginning. One transaction — a failure leaves
  /// the local data untouched. The seed categories go with the
  /// wipe; the pull re-creates the server's categories.
  /// `sync_state` is UPDATED, not deleted: the pull reads the row
  /// with getSingle(), so the row must survive the wipe.
  Future<void> wipeLocalDataForSync() async {
    const tables = [
      'transaction_photos',
      'transactions',
      'debt_payments',
      'goal_deposits',
      'budgets',
      'transaction_templates',
      'recurring_transactions',
      'category_keywords',
      'installment_plans',
      'debts',
      'goals',
      'categories',
      'wallets',
      'accounts',
    ];
    await transaction(() async {
      for (final table in tables) {
        await customStatement('DELETE FROM "$table"');
      }
      await customStatement('DELETE FROM sync_outbox');
      await customStatement('DELETE FROM sync_pushed');
      await customStatement('DELETE FROM sync_conflicts');
      await customUpdate(
        'UPDATE sync_state SET last_pull_cursor = NULL, '
        'last_sync_at = NULL WHERE id = 1',
        variables: const [],
        updates: {syncState},
      );
    });
  }

  /// Live list of conflict-keeper entries, newest overwrite first.
  Stream<List<SyncConflict>> watchSyncConflicts() =>
      (select(syncConflicts)
            ..orderBy([(c) => OrderingTerm.desc(c.overwrittenAt)]))
          .watch();

  /// Records a conflict-keeper entry (P3): the local row that a
  /// pull overwrote, kept as JSON so the user can restore it.
  /// One entry per (table, sync id) — a newer overwrite replaces
  /// the older loser. Must be called inside the pull's apply
  /// transaction, so the record and the overwrite land together.
  Future<void> recordSyncConflict({
    required String targetTable,
    required String syncId,
    required String losingJson,
    String? winningDevice,
  }) async {
    final existing =
        await (select(syncConflicts)
              ..where((c) => c.targetTable.equals(targetTable))
              ..where((c) => c.syncId.equals(syncId)))
            .getSingleOrNull();
    final now = DateTime.now();
    if (existing == null) {
      await into(syncConflicts).insert(
        SyncConflictsCompanion.insert(
          targetTable: targetTable,
          syncId: syncId,
          losingJson: losingJson,
          overwrittenAt: Value(now),
          winningDevice: Value(winningDevice),
        ),
      );
    } else {
      await (update(
        syncConflicts,
      )..where((c) => c.id.equals(existing.id))).write(
        SyncConflictsCompanion(
          losingJson: Value(losingJson),
          overwrittenAt: Value(now),
          winningDevice: Value(winningDevice),
        ),
      );
    }
  }

  /// Deletes one conflict-keeper entry (user dismissed it, or it
  /// was restored). Local bookkeeping only — no outbox entry.
  Future<void> deleteSyncConflict(int id) =>
      (delete(syncConflicts)..where((c) => c.id.equals(id))).go();

  /// Drops the last-push hash record for [syncId]. The hash means
  /// "the server already holds this exact content" — a conflict
  /// Restore re-applies content the server is known NOT to hold
  /// (the winner overwrote it), so the stale hash must go or the
  /// push's unchanged-skip would swallow the restored edit.
  /// Called by [SyncConflictService.restoreConflict]; local
  /// bookkeeping only — no outbox entry.
  Future<void> clearPushedHash(String syncId) =>
      (delete(syncPushed)..where((p) => p.syncId.equals(syncId))).go();

  /// One-shot pending-outbox count (P6 chunked push: the
  /// orchestrator decides the push mode from it). Cheaper than
  /// reading the rows — a COUNT(*) over the outbox.
  Future<int> outboxCount() async {
    final row = await customSelect(
      'SELECT COUNT(*) AS c FROM sync_outbox',
      readsFrom: {syncOutbox},
    ).getSingle();
    return row.read<int>('c');
  }

  /// Enqueues every local row as an 'insert' for the initial push
  /// (P6, §11). Rows that predate sync — the seed categories and
  /// every row the v18 backfill gave a sync id — have no outbox
  /// entry, so a plain drain would push nothing and the first sync
  /// would silently upload an empty library. Rows that already
  /// have an outbox entry are left alone (the NOT EXISTS guard),
  /// so calling this twice — or after new edits — never
  /// duplicates an entry. One transaction: a failure enqueues
  /// nothing. The server upsert is idempotent, so a row the
  /// server already holds is acked as unchanged by the hash
  /// check, never re-sent. Returns how many entries were added.
  Future<int> enqueueAllRowsForInitialPush() async {
    const tables = [
      'accounts',
      'categories',
      'wallets',
      'goals',
      'installment_plans',
      'debts',
      'debt_payments',
      'goal_deposits',
      'recurring_transactions',
      'transaction_templates',
      'budgets',
      'transactions',
      'category_keywords',
      'transaction_photos',
    ];
    var added = 0;
    await transaction(() async {
      for (final table in tables) {
        added += await customUpdate(
          'INSERT INTO sync_outbox (target_table, sync_id, op) '
          'SELECT ?, sync_id, ? FROM "$table" '
          'WHERE sync_id != ? '
          'AND NOT EXISTS (SELECT 1 FROM sync_outbox o '
          'WHERE o.target_table = ? AND o.sync_id = "$table".sync_id)',
          variables: [
            Variable.withString(table),
            Variable.withString('insert'),
            Variable.withString(''),
            Variable.withString(table),
          ],
          updates: {syncOutbox},
        );
      }
    });
    return added;
  }

  /// Records one sync run in the local log (P6, §8/§12) and
  /// prunes older rows, keeping the newest 50. Local-only —
  /// never synced, no outbox entry. The caller guards this call:
  /// logging must never fail a cycle.
  Future<void> recordSyncLog({
    required int pushed,
    required int pulled,
    required int conflicts,
    required int failed,
    String? failureMode,
    String? error,
  }) async {
    final trimmed = error == null
        ? null
        : (error.length > 500 ? error.substring(0, 500) : error);
    await transaction(() async {
      await into(syncLog).insert(
        SyncLogCompanion.insert(
          pushed: Value(pushed),
          pulled: Value(pulled),
          conflicts: Value(conflicts),
          failed: Value(failed),
          failureMode: Value(failureMode),
          error: Value(trimmed),
        ),
      );
      await customStatement(
        'DELETE FROM sync_log WHERE id NOT IN '
        '(SELECT id FROM sync_log ORDER BY id DESC LIMIT 50)',
      );
    });
  }

  /// The newest sync-log rows, newest first, for the Settings
  /// "Recent syncs" list (P6).
  Stream<List<SyncLogData>> watchRecentSyncLog({int limit = 5}) =>
      (select(syncLog)
            ..orderBy([(l) => OrderingTerm.desc(l.id)])
            ..limit(limit))
          .watch();

  /// Inserts the hidden "Transfer" category if it doesn't exist yet
  /// (used by the v1→v2 migration; the fresh seed inserts it directly).
  /// Runs during migration, before the sync columns exist — no outbox
  /// entry; the v18 backfill covers the row.
  Future<void> _ensureTransferCategory() async {
    final existing = await (select(
      categories,
    )..where((c) => c.kind.equals('transfer'))).get();
    if (existing.isEmpty) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: 'Transfer',
          iconKey: const Value('swap_horiz'),
          colorHex: const Value('#9CA3AF'),
          kind: 'transfer',
        ),
      );
    }
  }

  Future<int> get transferCategoryId async => (await (select(
    categories,
  )..where((c) => c.kind.equals('transfer'))).get()).first.id;

  /// The expense category transfer fees are booked under. Created on
  /// first use — existing installs never re-run the seed.
  Future<int> get feeCategoryId async {
    final existing =
        await (select(categories)..where(
              (c) => c.kind.equals('expense') & c.name.equals('Transfer fee'),
            ))
            .get();
    if (existing.isNotEmpty) return existing.first.id;
    // Lazily created outside any transaction (e.g. a screen reads
    // the id directly), so the insert + outbox entry are wrapped
    // in their own transaction here; nested inside a caller's
    // transaction this joins it via a savepoint.
    return transaction(() async {
      final syncId = _newSyncId();
      final id = await into(categories).insert(
        CategoriesCompanion.insert(
          name: 'Transfer fee',
          iconKey: const Value('receipt'),
          colorHex: const Value('#9CA3AF'),
          kind: 'expense',
          syncId: Value(syncId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('categories', syncId, 'insert');
      return id;
    });
  }

  /// The income category interest credits are booked under. Created on
  /// first use — existing installs never re-run the seed. Mirrors
  /// [feeCategoryId], except this one is user-visible: it appears in
  /// the category picker once created, which is the point — it is how
  /// interest income gets recorded.
  Future<int> get interestCategoryId async {
    final existing = await (select(
      categories,
    )..where((c) => c.kind.equals('income') & c.name.equals('Interest'))).get();
    if (existing.isNotEmpty) return existing.first.id;
    // Lazily created outside any transaction (e.g. a screen reads
    // the id directly), so the insert + outbox entry are wrapped
    // in their own transaction here; nested inside a caller's
    // transaction this joins it via a savepoint.
    return transaction(() async {
      final syncId = _newSyncId();
      final id = await into(categories).insert(
        CategoriesCompanion.insert(
          name: 'Interest',
          iconKey: const Value('account_balance'),
          colorHex: const Value('#4ADE80'),
          kind: 'income',
          syncId: Value(syncId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('categories', syncId, 'insert');
      return id;
    });
  }

  Future<List<Transaction>> transferFeeRows(int transferId) => (select(
    transactions,
  )..where((t) => t.transferId.equals(transferId))).get();

  /// Fallback category that transactions, budgets, rules and templates
  /// are reassigned to when their category is deleted, so nothing
  /// silently vanishes from the joined lists. Same hidden-category
  /// pattern as Debt/Adjustment: pickers and Manage Categories filter
  /// by kind 'income'/'expense', so kind 'uncategorized' keeps it out
  /// of sight, while unfiltered maps (Stats, Structure, Budgets) still
  /// resolve it to the name 'Uncategorized'.
  Future<int> get uncategorizedCategoryId async {
    final existing = await (select(
      categories,
    )..where((c) => c.kind.equals('uncategorized'))).get();
    if (existing.isNotEmpty) return existing.first.id;
    // Lazily created outside any transaction (e.g. a screen reads
    // the id directly), so the insert + outbox entry are wrapped
    // in their own transaction here; nested inside a caller's
    // transaction this joins it via a savepoint.
    return transaction(() async {
      final syncId = _newSyncId();
      final id = await into(categories).insert(
        CategoriesCompanion.insert(
          name: 'Uncategorized',
          iconKey: const Value('other'),
          colorHex: const Value('#9CA3AF'),
          kind: 'uncategorized',
          syncId: Value(syncId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('categories', syncId, 'insert');
      return id;
    });
  }

  /// Signed wallet delta for a debt's creation movement:
  /// lending (receivable) takes money out, borrowing (payable) brings it in.
  int _debtWalletEffect(String direction, int amount) =>
      direction == 'receivable' ? -amount : amount;

  /// Signed wallet delta for a repayment:
  /// being repaid (receivable) brings money in, repaying (payable) takes it out.
  int _debtPaymentEffect(String direction, int amount) =>
      direction == 'receivable' ? amount : -amount;

  /// Note text for a debt-linked transaction.
  String _debtTxNote(
    String direction,
    String person,
    String note, {
    required bool payment,
  }) {
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
    final existing = await (select(
      categories,
    )..where((c) => c.kind.equals('debt'))).get();
    if (existing.isNotEmpty) return existing.first.id;
    // Lazily created outside any transaction (e.g. a screen reads
    // the id directly), so the insert + outbox entry are wrapped
    // in their own transaction here; nested inside a caller's
    // transaction this joins it via a savepoint.
    return transaction(() async {
      final syncId = _newSyncId();
      final id = await into(categories).insert(
        CategoriesCompanion.insert(
          name: 'Debt',
          iconKey: const Value('handshake'),
          colorHex: const Value('#F472B6'),
          kind: 'debt',
          syncId: Value(syncId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('categories', syncId, 'insert');
      return id;
    });
  }

  Future<void> _ensureDebtCategory() async {
    await debtCategoryId;
  }

  /// Hidden "Adjustment" category for balance-adjustment transactions.
  /// Ensured lazily like the Debt category, so no DB migration is needed.
  /// Pickers filter by kind 'income'/'expense', so kind 'adjustment'
  /// keeps it out of sight; stats filter by transaction kind, so the
  /// adjustment still counts as income/expense there.
  Future<int> get adjustmentCategoryId async {
    final existing = await (select(
      categories,
    )..where((c) => c.kind.equals('adjustment'))).get();
    if (existing.isNotEmpty) return existing.first.id;
    // Lazily created outside any transaction (e.g. a screen reads
    // the id directly), so the insert + outbox entry are wrapped
    // in their own transaction here; nested inside a caller's
    // transaction this joins it via a savepoint.
    return transaction(() async {
      final syncId = _newSyncId();
      final id = await into(categories).insert(
        CategoriesCompanion.insert(
          name: 'Adjustment',
          iconKey: const Value('tune'),
          colorHex: const Value('#9CA3AF'),
          kind: 'adjustment',
          syncId: Value(syncId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('categories', syncId, 'insert');
      return id;
    });
  }

  /// Adjusts a wallet's balance by recording an income/expense transaction
  /// for the difference (dated now, note "Balance adjustment").
  /// Returns the created transaction id, or 0 when there's no difference.
  Future<int> adjustBalanceByTransaction(int walletId, int newBalance) {
    return transaction(() async {
      final w = await (select(
        wallets,
      )..where((e) => e.id.equals(walletId))).getSingleOrNull();
      if (w == null) return 0;
      final diff = newBalance - w.balance;
      if (diff == 0) return 0;
      final catId = await adjustmentCategoryId;
      return addTransaction(
        TransactionsCompanion.insert(
          walletId: walletId,
          categoryId: catId,
          kind: diff > 0 ? 'income' : 'expense',
          amount: diff.abs(),
          note: const Value('Balance adjustment'),
          date: DateTime.now(),
        ),
      );
    });
  }

  /// Sets a wallet's balance to [newBalance] by shifting its initial amount,
  /// leaving the transaction history untouched.
  Future<void> changeWalletInitialAmount(int walletId, int newBalance) {
    return transaction(() async {
      final w = await (select(
        wallets,
      )..where((e) => e.id.equals(walletId))).getSingleOrNull();
      if (w == null) return;
      final diff = newBalance - w.balance;
      if (diff == 0) return;
      await (update(wallets)..where((e) => e.id.equals(walletId))).write(
        WalletsCompanion(
          balance: Value(newBalance),
          initialAmount: Value(w.initialAmount + diff),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('wallets', w.syncId, 'update');
    });
  }

  // ------------------------------- watches -------------------------------

  Stream<List<Account>> watchAccounts() => select(accounts).watch();

  /// Joins wallets onto an aggregate-over-transactions query so it can be
  /// scoped to one account. A transaction counts toward the account of its
  /// source wallet ([transactions.walletId]).
  void _scopeToAccount(
    JoinedSelectStatement<$TransactionsTable, dynamic> q,
    int? accountId,
  ) {
    if (accountId != null) {
      q.join([innerJoin(wallets, wallets.id.equalsExp(transactions.walletId))]);
      q.where(wallets.accountId.equals(accountId));
    }
  }

  Stream<List<Wallet>> watchWallets({int? accountId}) {
    final q = select(wallets);
    if (accountId != null) q.where((w) => w.accountId.equals(accountId));
    q.orderBy([
      (w) => OrderingTerm.asc(w.sortOrder),
      (w) => OrderingTerm.asc(w.id),
    ]);
    return q.watch();
  }

  Stream<List<Category>> watchCategories({
    String? kind,
    bool topLevelOnly = false,
  }) {
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

  Stream<List<TransactionWithDetails>> watchTransactions({
    int? limit,
    int? accountId,
    DateTime? from,
  }) {
    final q = _joinedTransactions();
    if (accountId != null) q.where(wallets.accountId.equals(accountId));
    if (from != null) q.where(transactions.date.isBiggerOrEqualValue(from));
    if (limit != null) q.limit(limit);
    return q.watch().map(_toDetails);
  }

  Stream<List<Transaction>> watchTransactionsRaw() =>
      select(transactions).watch();

  /// Transactions touching one wallet (as source or transfer destination),
  /// newest first. Powers the wallet detail screen.
  Stream<List<TransactionWithDetails>> watchTransactionsForWallet(
    int walletId,
  ) {
    final q = _joinedTransactions()
      ..where(
        transactions.walletId.equals(walletId) |
            transactions.toWalletId.equals(walletId),
      );
    return q.watch().map(_toDetails);
  }

  /// Transactions touching one wallet inside [from, to], newest first.
  /// Powers the wallet transactions screen's month pager.
  Stream<List<TransactionWithDetails>> watchTransactionsForWalletInRange(
    int walletId,
    DateTime from,
    DateTime to,
  ) {
    final q = _joinedTransactions()
      ..where(
        transactions.walletId.equals(walletId) |
            transactions.toWalletId.equals(walletId),
      )
      ..where(transactions.date.isBetweenValues(from, to));
    return q.watch().map(_toDetails);
  }

  /// Transactions for one wallet + one category, newest first.
  /// Powers the wallet category detail screen.
  Stream<List<TransactionWithDetails>> watchTransactionsForWalletAndCategory(
    int walletId,
    int categoryId,
  ) {
    final q = _joinedTransactions()
      ..where(
        (transactions.walletId.equals(walletId) |
                transactions.toWalletId.equals(walletId)) &
            transactions.categoryId.equals(categoryId),
      );
    return q.watch().map(_toDetails);
  }

  /// Transactions of one category inside [from, to]. Powers the budget
  /// detail screen (pass the month's first/last instant).
  Stream<List<TransactionWithDetails>> watchTransactionsForCategory(
    int categoryId,
    DateTime from,
    DateTime to, {
    String? kind,
    int? accountId,
  }) {
    final q = _joinedTransactions()
      ..where(
        transactions.categoryId.equals(categoryId) &
            transactions.date.isBetweenValues(from, to),
      );
    if (kind != null) q.where(transactions.kind.equals(kind));
    if (accountId != null) q.where(wallets.accountId.equals(accountId));
    return q.watch().map(_toDetails);
  }

  /// Cash-basis version of [watchTransactionsForCategory]: the rows
  /// behind a cash-basis category total — a paylater purchase is
  /// excluded (unpaid borrowing), while an installment transfer
  /// attributed to this category is included, so the listed rows sum
  /// to the header total. Powers the Structure and budget detail
  /// screens. [kind] filters on the row's EFFECTIVE kind, so pass
  /// 'expense' to include installments (their stored kind is
  /// 'transfer'); omit it to get every cash-counting row.
  Stream<List<TransactionWithDetails>> watchCashTransactionsForCategory(
    int categoryId,
    DateTime from,
    DateTime to, {
    String? kind,
    int? accountId,
  }) {
    final q = _joinedTransactions();
    final cash = _cashJoin(q);
    q.where(
      cash.category.equals(categoryId) &
          transactions.date.isBetweenValues(from, to),
    );
    if (kind != null) {
      q.where(cash.kind.equals(kind));
    } else {
      q.where(cash.kind.isNotNull());
    }
    if (accountId != null) q.where(cash.src.accountId.equals(accountId));
    return q.watch().map(_toDetails);
  }

  /// Cash-basis expressions shared by the cash aggregates below.
  ///
  /// Joins the source wallet (aliased `src`) and, for transfers, the
  /// destination wallet (aliased `dst`) onto [q], and returns:
  /// - [kind]: the row's cash-basis kind — 'income' / 'expense', or NULL
  ///   when the row counts toward neither total (a paylater purchase, an
  ///   income on a paylater wallet, a transfer between two paylater
  ///   wallets, a transfer out of a paylater wallet, or any transfer
  ///   between non-paylater wallets);
  /// - [category]: the spending category — the linked purchase's category
  ///   for a plan installment, otherwise the row's own category.
  /// Account scoping is the source wallet's account, matching
  /// [_scopeToAccount] — callers filter on the returned [src].
  _CashBasis _cashJoin(JoinedSelectStatement<HasResultSet, dynamic> q) {
    final src = alias(wallets, 'src');
    final dst = alias(wallets, 'dst');
    q.join([
      innerJoin(src, src.id.equalsExp(transactions.walletId)),
      leftOuterJoin(dst, dst.id.equalsExp(transactions.toWalletId)),
    ]);
    final kind = CustomExpression<String>(
      "CASE "
      "WHEN transactions.kind = 'income' AND src.kind <> 'paylater' "
      "THEN 'income' "
      "WHEN transactions.kind = 'expense' AND src.kind <> 'paylater' "
      "THEN 'expense' "
      "WHEN transactions.kind = 'transfer' AND src.kind <> 'paylater' "
      "AND dst.kind = 'paylater' THEN 'expense' "
      "ELSE NULL END",
    );
    // The purchase is the expense row carrying the same plan id; when
    // there is none (unlinked paydown, or the purchase was deleted) the
    // transfer falls back to its own category.
    final category = CustomExpression<int>(
      'COALESCE('
      "(SELECT p.category_id FROM transactions p WHERE "
      "p.plan_id = transactions.plan_id AND p.kind = 'expense' LIMIT 1), "
      'transactions.category_id)',
    );
    return (src: src, dst: dst, kind: kind, category: category);
  }

  /// Per-category expense totals inside [from, to], largest first.
  /// The database aggregates; the UI only receives one row per category.
  Stream<List<CategoryTotal>> watchCategoryExpenseTotals(
    DateTime from,
    DateTime to, {
    int? accountId,
  }) {
    final total = transactions.amount.sum();
    final q = selectOnly(transactions)
      ..addColumns([transactions.categoryId, total]);
    _scopeToAccount(q, accountId);
    q
      ..where(
        transactions.kind.equals('expense') &
            transactions.date.isBetweenValues(from, to),
      )
      ..groupBy([transactions.categoryId])
      ..orderBy([OrderingTerm.desc(total)]);
    return q.watch().map(
      (rows) => rows
          .map(
            (row) => (
              categoryId: row.read(transactions.categoryId)!,
              total: row.read(total) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// Cash-basis version of [watchCategoryExpenseTotals]: expense rows on
  /// non-paylater wallets grouped by their own category, PLUS transfers
  /// from a non-paylater wallet into a paylater wallet (installment
  /// payments / paydowns) grouped by the spending category — the linked
  /// purchase's category when the transfer belongs to a plan, otherwise
  /// the transfer row's own (hidden Transfer) category. Expense rows on
  /// paylater wallets never appear: they are unpaid borrowing, not
  /// spending. The grouping expression always falls back to the row's
  /// own non-null category, so no null category can reach the grouping.
  Stream<List<CategoryTotal>> watchCashCategoryExpenseTotals(
    DateTime from,
    DateTime to, {
    int? accountId,
  }) {
    final total = transactions.amount.sum();
    final q = selectOnly(transactions);
    final cash = _cashJoin(q);
    q.addColumns([cash.category, total]);
    if (accountId != null) q.where(cash.src.accountId.equals(accountId));
    q
      ..where(
        cash.kind.equals('expense') &
            transactions.date.isBetweenValues(from, to),
      )
      ..groupBy([cash.category])
      ..orderBy([OrderingTerm.desc(total)]);
    return q.watch().map(
      (rows) => rows
          .map(
            (row) => (
              categoryId: row.read(cash.category)!,
              total: row.read(total) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// Per-category total + transaction count for a kind in a date range,
  /// sorted by total descending. Backs the Structure detail screen.
  Stream<List<CategoryStat>> watchCategoryKindStats(
    String kind,
    DateTime from,
    DateTime to, {
    int? accountId,
  }) {
    final total = transactions.amount.sum();
    final count = transactions.id.count();
    final q = selectOnly(transactions)
      ..addColumns([transactions.categoryId, total, count]);
    _scopeToAccount(q, accountId);
    q
      ..where(
        transactions.kind.equals(kind) &
            transactions.date.isBetweenValues(from, to),
      )
      ..groupBy([transactions.categoryId])
      ..orderBy([OrderingTerm.desc(total)]);
    return q.watch().map(
      (rows) => rows
          .map(
            (row) => (
              categoryId: row.read(transactions.categoryId)!,
              total: row.read(total) ?? 0,
              count: row.read(count) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// Cash-basis version of [watchCategoryKindStats]. Only 'income' and
  /// 'expense' ever produce rows — a paylater-bound transfer counts
  /// under 'expense', never as its own kind.
  Stream<List<CategoryStat>> watchCashCategoryKindStats(
    String kind,
    DateTime from,
    DateTime to, {
    int? accountId,
  }) {
    final total = transactions.amount.sum();
    final count = transactions.id.count();
    final q = selectOnly(transactions);
    final cash = _cashJoin(q);
    q.addColumns([cash.category, total, count]);
    if (accountId != null) q.where(cash.src.accountId.equals(accountId));
    q
      ..where(
        cash.kind.equals(kind) & transactions.date.isBetweenValues(from, to),
      )
      ..groupBy([cash.category])
      ..orderBy([OrderingTerm.desc(total)]);
    return q.watch().map(
      (rows) => rows
          .map(
            (row) => (
              categoryId: row.read(cash.category)!,
              total: row.read(total) ?? 0,
              count: row.read(count) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// Per-kind totals inside [from, to]: one row per kind present.
  /// Backs range summaries like the home balance card.
  Stream<List<KindTotal>> watchKindTotals(
    DateTime from,
    DateTime to, {
    int? accountId,
  }) {
    final total = transactions.amount.sum();
    final q = selectOnly(transactions)..addColumns([transactions.kind, total]);
    _scopeToAccount(q, accountId);
    q
      ..where(transactions.date.isBetweenValues(from, to))
      ..groupBy([transactions.kind]);
    return q.watch().map(
      (rows) => rows
          .map(
            (row) => (
              kind: row.read(transactions.kind) ?? '',
              total: row.read(total) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// Cash-basis version of [watchKindTotals]: one row per kind present,
  /// counting only rows where cash actually moved — paylater purchases
  /// and paylater-to-paylater moves are excluded, while transfers from
  /// a funding wallet into a paylater wallet count as 'expense'.
  Stream<List<KindTotal>> watchCashKindTotals(
    DateTime from,
    DateTime to, {
    int? accountId,
  }) {
    final total = transactions.amount.sum();
    final q = selectOnly(transactions);
    final cash = _cashJoin(q);
    q.addColumns([cash.kind, total]);
    if (accountId != null) q.where(cash.src.accountId.equals(accountId));
    q
      ..where(
        cash.kind.isNotNull() & transactions.date.isBetweenValues(from, to),
      )
      ..groupBy([cash.kind]);
    return q.watch().map(
      (rows) => rows
          .map(
            (row) =>
                (kind: row.read(cash.kind) ?? '', total: row.read(total) ?? 0),
          )
          .toList(),
    );
  }

  /// Per-day, per-kind totals inside [from, to], oldest day first.
  /// [day] is 'yyyy-MM-dd'. Backs the 7-day sparklines.
  Stream<List<DailyTotal>> watchDailyKindTotals(
    DateTime from,
    DateTime to, {
    int? accountId,
  }) {
    final dayExpr = CustomExpression<String>(
      "strftime('%Y-%m-%d', transactions.date, 'unixepoch', 'localtime')",
    );
    final total = transactions.amount.sum();
    final q = selectOnly(transactions)
      ..addColumns([dayExpr, transactions.kind, total]);
    _scopeToAccount(q, accountId);
    q
      ..where(transactions.date.isBetweenValues(from, to))
      ..groupBy([dayExpr, transactions.kind])
      ..orderBy([OrderingTerm.asc(dayExpr)]);
    return q.watch().map(
      (rows) => rows
          .map(
            (row) => (
              day: row.read(dayExpr) ?? '',
              kind: row.read(transactions.kind) ?? '',
              total: row.read(total) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// Per-hour, per-kind totals inside [from, to], oldest hour first.
  /// [hour] is 'HH' (00-23 local). Backs the day-range sparkline.
  Stream<List<HourlyTotal>> watchHourlyKindTotals(
    DateTime from,
    DateTime to, {
    int? accountId,
  }) {
    final hourExpr = CustomExpression<String>(
      "strftime('%H', transactions.date, 'unixepoch', 'localtime')",
    );
    final total = transactions.amount.sum();
    final q = selectOnly(transactions)
      ..addColumns([hourExpr, transactions.kind, total]);
    _scopeToAccount(q, accountId);
    q
      ..where(transactions.date.isBetweenValues(from, to))
      ..groupBy([hourExpr, transactions.kind])
      ..orderBy([OrderingTerm.asc(hourExpr)]);
    return q.watch().map(
      (rows) => rows
          .map(
            (row) => (
              hour: row.read(hourExpr) ?? '',
              kind: row.read(transactions.kind) ?? '',
              total: row.read(total) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// Per-month income/expense totals inside [from, to], oldest month first.
  /// Backs the 6-month bar chart and the net-savings trend.
  Stream<List<MonthlyTotal>> watchMonthlyKindTotals(
    DateTime from,
    DateTime to, {
    int? accountId,
  }) {
    final monthExpr = CustomExpression<String>(
      "strftime('%Y-%m', transactions.date, 'unixepoch', 'localtime')",
    );
    final total = transactions.amount.sum();
    final q = selectOnly(transactions)
      ..addColumns([monthExpr, transactions.kind, total]);
    _scopeToAccount(q, accountId);
    q
      ..where(transactions.date.isBetweenValues(from, to))
      ..groupBy([monthExpr, transactions.kind])
      ..orderBy([OrderingTerm.asc(monthExpr)]);
    return q.watch().map(
      (rows) => rows
          .map(
            (row) => (
              month: row.read(monthExpr) ?? '',
              kind: row.read(transactions.kind) ?? '',
              total: row.read(total) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// Cash-basis version of [watchMonthlyKindTotals]: per-month
  /// income/expense totals counting only rows where cash actually moved.
  Stream<List<MonthlyTotal>> watchCashMonthlyKindTotals(
    DateTime from,
    DateTime to, {
    int? accountId,
  }) {
    final monthExpr = CustomExpression<String>(
      "strftime('%Y-%m', transactions.date, 'unixepoch', 'localtime')",
    );
    final total = transactions.amount.sum();
    final q = selectOnly(transactions);
    final cash = _cashJoin(q);
    q.addColumns([monthExpr, cash.kind, total]);
    if (accountId != null) q.where(cash.src.accountId.equals(accountId));
    q
      ..where(
        cash.kind.isNotNull() & transactions.date.isBetweenValues(from, to),
      )
      ..groupBy([monthExpr, cash.kind])
      ..orderBy([OrderingTerm.asc(monthExpr)]);
    return q.watch().map(
      (rows) => rows
          .map(
            (row) => (
              month: row.read(monthExpr) ?? '',
              kind: row.read(cash.kind) ?? '',
              total: row.read(total) ?? 0,
            ),
          )
          .toList(),
    );
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

  Stream<List<TransactionPhoto>> watchPhotos(int transactionId) => (select(
    transactionPhotos,
  )..where((p) => p.transactionId.equals(transactionId))).watch();

  Future<Wallet?> getWalletById(int id) =>
      (select(wallets)..where((w) => w.id.equals(id))).getSingleOrNull();

  // -------------------------------- writes -------------------------------

  /// Adjusts a wallet balance atomically (delta may be negative).
  ///
  /// No outbox entry: the balance is derived state, recomputed from
  /// the transaction ledger after a pull (see concept doc section 7).
  /// The transaction rows that cause the change carry their own
  /// entries, so the receiving device re-derives the same balance.
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
      final syncId = _newSyncId();
      final id = await into(transactions).insert(
        entry.copyWith(syncId: Value(syncId), updatedAt: Value(DateTime.now())),
      );
      await _enqueueOutbox('transactions', syncId, 'insert');
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

  /// Distinct past descriptions starting with [query] (case-insensitive),
  /// ranked by use frequency then recency. Backs description autocomplete
  /// in the add-transaction sheet.
  Future<List<String>> suggestDescriptions(
    String query, {
    required String kind,
    int limit = 6,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    // Escape LIKE wildcards so typed %/_ match literally.
    final pattern =
        '${q.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    final rows = await customSelect(
      '''
      SELECT note FROM transactions t
      WHERE t.kind = ? AND t.note LIKE ? ESCAPE '\\' AND t.note <> ''
      GROUP BY t.note
      ORDER BY COUNT(*) DESC, MAX(t.date) DESC
      LIMIT ?
      ''',
      variables: [
        Variable.withString(kind),
        Variable.withString(pattern),
        Variable.withInt(limit),
      ],
      readsFrom: {transactions},
    ).get();
    return rows.map((r) => r.read<String>('note')).toList();
  }

  /// Records a wallet-to-wallet transfer and moves the balances.
  /// The row uses the hidden "Transfer" category and kind 'transfer'.
  /// A [fee] above zero is booked as an extra expense on the source
  /// wallet (its own row, linked back via `transferId`) so it shows up
  /// in expenses and is reversed together with the transfer.
  Future<int> addTransfer({
    required int fromWalletId,
    required int toWalletId,
    required int amount,
    String note = '',
    DateTime? date,
    int fee = 0,
    int? planId,
  }) {
    return transaction(() async {
      final catId = await transferCategoryId;
      final when = date ?? DateTime.now();
      final transferSyncId = _newSyncId();
      final id = await into(transactions).insert(
        TransactionsCompanion.insert(
          walletId: fromWalletId,
          categoryId: catId,
          kind: 'transfer',
          amount: amount,
          note: Value(note),
          date: when,
          toWalletId: Value(toWalletId),
          planId: Value(planId),
          syncId: Value(transferSyncId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('transactions', transferSyncId, 'insert');
      await adjustWalletBalance(fromWalletId, -amount);
      await adjustWalletBalance(toWalletId, amount);
      if (fee > 0) {
        final feeSyncId = _newSyncId();
        await into(transactions).insert(
          TransactionsCompanion.insert(
            walletId: fromWalletId,
            categoryId: await feeCategoryId,
            kind: 'expense',
            amount: fee,
            note: const Value('Transfer fee'),
            date: when,
            transferId: Value(id),
            syncId: Value(feeSyncId),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await _enqueueOutbox('transactions', feeSyncId, 'insert');
        await adjustWalletBalance(fromWalletId, -fee);
      }
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

  /// Deletes a transaction, reversing its balance effect. Returns the
  /// installment plan removed alongside it, if any — the caller needs
  /// it to offer undo — or null.
  ///
  /// Plan linkage is part of the ledger, not an afterthought:
  /// - Deleting a plan's purchase expense also deletes the plan, but
  ///   only while nothing has been paid on it. A plan with payments
  ///   throws a [StateError]: its history is real money, and the plan
  ///   card is the designed path to remove it.
  /// - Deleting an installment payment re-derives the plan's paid
  ///   counter from the payments that remain.
  Future<InstallmentPlan?> deleteTransaction(int id) {
    return transaction(() async {
      final t = await (select(
        transactions,
      )..where((e) => e.id.equals(id))).getSingleOrNull();
      if (t == null) return null;
      InstallmentPlan? deletedPlan;
      if (t.planId != null) {
        final plan = await getInstallmentPlan(t.planId!);
        if (plan != null && t.kind == 'expense') {
          if (plan.paidCount > 0) {
            throw StateError(
              'Plan ${plan.id} has ${plan.paidCount} paid installments; '
              'delete the plan instead of its purchase.',
            );
          }
          await (delete(
            installmentPlans,
          )..where((p) => p.id.equals(plan.id))).go();
          await _enqueueOutbox('installment_plans', plan.syncId, 'delete');
          deletedPlan = plan;
        }
      }
      // A transfer takes its fee expense rows with it, so the source
      // wallet is made whole again.
      if (t.kind == 'transfer') {
        for (final feeRow in await transferFeeRows(id)) {
          await _reverseBalanceEffect(feeRow);
          for (final photo in await (select(
            transactionPhotos,
          )..where((p) => p.transactionId.equals(feeRow.id))).get()) {
            await _enqueueOutbox('transaction_photos', photo.syncId, 'delete');
          }
          await (delete(
            transactionPhotos,
          )..where((p) => p.transactionId.equals(feeRow.id))).go();
          await (delete(
            transactions,
          )..where((e) => e.id.equals(feeRow.id))).go();
          await _enqueueOutbox('transactions', feeRow.syncId, 'delete');
        }
      }
      await _reverseBalanceEffect(t);
      for (final photo in await (select(
        transactionPhotos,
      )..where((p) => p.transactionId.equals(id))).get()) {
        await _enqueueOutbox('transaction_photos', photo.syncId, 'delete');
      }
      await (delete(
        transactionPhotos,
      )..where((p) => p.transactionId.equals(id))).go();
      await (delete(transactions)..where((e) => e.id.equals(id))).go();
      await _enqueueOutbox('transactions', t.syncId, 'delete');
      if (t.planId != null && t.kind == 'transfer') {
        await _resyncPlanPaidCount(t.planId!);
      }
      return deletedPlan;
    });
  }

  /// Re-inserts a plan removed alongside its purchase (see
  /// [deleteTransaction]). Backs the "Undo" action after deleting a
  /// plan purchase. The caller restores the plan before its purchase
  /// so the linked rows never point at a missing plan.
  Future<void> restoreInstallmentPlan(InstallmentPlan plan) {
    return transaction(() async {
      await into(installmentPlans).insert(
        plan.toCompanion(false).copyWith(updatedAt: Value(DateTime.now())),
      );
      await _enqueueOutbox('installment_plans', plan.syncId, 'insert');
    });
  }

  /// Re-inserts a previously deleted transaction with its original id,
  /// re-applying its wallet balance effect and photo attachments.
  /// Backs the "Undo" action offered right after a delete. The receipt
  /// files themselves are left on disk by [deleteTransaction], so the
  /// restored photo rows point at valid files again.
  Future<void> restoreTransaction(
    Transaction t,
    List<TransactionPhoto> photos,
  ) {
    return transaction(() async {
      final now = DateTime.now();
      await into(
        transactions,
      ).insert(t.toCompanion(false).copyWith(updatedAt: Value(now)));
      await _enqueueOutbox('transactions', t.syncId, 'insert');
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
        // Fresh rows (new ids): the original photo rows were deleted
        // with the transaction, so the restore re-creates them.
        final photoSyncId = _newSyncId();
        await into(transactionPhotos).insert(
          TransactionPhotosCompanion.insert(
            transactionId: t.id,
            path: p.path,
            syncId: Value(photoSyncId),
            updatedAt: Value(now),
          ),
        );
        await _enqueueOutbox('transaction_photos', photoSyncId, 'insert');
      }
      if (t.planId != null && t.kind == 'transfer') {
        await _resyncPlanPaidCount(t.planId!);
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
    String memo = '',
    required DateTime date,
  }) {
    return transaction(() async {
      final old = await (select(
        transactions,
      )..where((e) => e.id.equals(id))).getSingleOrNull();
      if (old == null) return;
      await _reverseBalanceEffect(old);
      await (update(transactions)..where((e) => e.id.equals(id))).write(
        TransactionsCompanion(
          walletId: Value(walletId),
          categoryId: Value(categoryId),
          kind: Value(kind),
          amount: Value(amount),
          note: Value(note),
          memo: Value(memo),
          date: Value(date),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('transactions', old.syncId, 'update');
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
  }) {
    return transaction(() async {
      final row = await (select(
        categories,
      )..where((c) => c.id.equals(id))).getSingleOrNull();
      if (row == null) return;
      await (update(categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          name: Value(name),
          iconKey: Value(iconKey),
          colorHex: Value(colorHex),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('categories', row.syncId, 'update');
    });
  }

  /// Persists a manual drag-reorder: [orderedIds] is the new top-to-bottom
  /// order of one (kind, top-level) group.
  Future<void> reorderCategories(List<int> orderedIds) {
    return transaction(() async {
      final now = DateTime.now();
      final rows = await (select(
        categories,
      )..where((c) => c.id.isIn(orderedIds))).get();
      final syncIds = {for (final r in rows) r.id: r.syncId};
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(
          categories,
        )..where((c) => c.id.equals(orderedIds[i]))).write(
          CategoriesCompanion(sortOrder: Value(i), updatedAt: Value(now)),
        );
        final syncId = syncIds[orderedIds[i]];
        if (syncId != null) {
          await _enqueueOutbox('categories', syncId, 'update');
        }
      }
    });
  }

  /// Persists a manual wallet order (Arrange Wallets screen).
  Future<void> reorderWallets(List<int> orderedIds) {
    return transaction(() async {
      final now = DateTime.now();
      final rows = await (select(
        wallets,
      )..where((w) => w.id.isIn(orderedIds))).get();
      final syncIds = {for (final r in rows) r.id: r.syncId};
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(wallets)..where((w) => w.id.equals(orderedIds[i]))).write(
          WalletsCompanion(sortOrder: Value(i), updatedAt: Value(now)),
        );
        final syncId = syncIds[orderedIds[i]];
        if (syncId != null) {
          await _enqueueOutbox('wallets', syncId, 'update');
        }
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
    final syncId = _newSyncId();
    await transaction(() async {
      await into(transactionPhotos).insert(
        TransactionPhotosCompanion.insert(
          transactionId: transactionId,
          path: stored.path,
          syncId: Value(syncId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('transaction_photos', syncId, 'insert');
    });
    return stored.path;
  }

  /// Removes a photo attachment. Our stored copy is deleted too; the
  /// user's original (gallery photo / camera roll) is always kept.
  Future<void> deletePhoto(int photoId) async {
    final row = await (select(
      transactionPhotos,
    )..where((p) => p.id.equals(photoId))).getSingleOrNull();
    if (row == null) {
      await (delete(
        transactionPhotos,
      )..where((p) => p.id.equals(photoId))).go();
      return;
    }
    await transaction(() async {
      await (delete(
        transactionPhotos,
      )..where((p) => p.id.equals(photoId))).go();
      await _enqueueOutbox('transaction_photos', row.syncId, 'delete');
    });
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

  /// Records the Storage object key of a photo after its bytes are
  /// uploaded (P4 push) — a bookkeeping write, not a user edit: no
  /// outbox entry (the pending insert/update entry already covers
  /// the row; this only fills in the key it uploads under) and no
  /// [updatedAt] change (the row's content did not change, so a
  /// pull must not see it as a newer local edit). Same rule as the
  /// other derived-only writers (adjustWalletBalance,
  /// markInstallmentPaid, updateGoalSaved, setDebtPaid).
  Future<void> setPhotoRemoteKey(int photoId, String key) async {
    await (update(
      transactionPhotos,
    )..where((p) => p.id.equals(photoId))).write(
      TransactionPhotosCompanion(remoteKey: Value(key)),
    );
  }

  Future<int> addWallet(WalletsCompanion entry) {
    return transaction(() async {
      final syncId = _companionSyncId(entry.syncId);
      final id = await into(wallets).insert(
        entry.copyWith(syncId: Value(syncId), updatedAt: Value(DateTime.now())),
      );
      await _enqueueOutbox('wallets', syncId, 'insert');
      return id;
    });
  }

  /// Creates a wallet with its opening balance recorded as the initial amount.
  /// New wallets append at the end of the manual order.
  Future<int> createWallet({
    required int accountId,
    required String name,
    required String kind,
    int initialAmount = 0,
    String colorHex = '#C6FF4A',
    String? logoTemplate,
    int? creditLimit,
    int? statementDay,
    int? dueDay,
    double? interestRateMonthly,
    double? interestRateAnnual,
  }) async {
    // Append after the current max so a fresh wallet never collides with
    // an existing manual order (default 0 would tie with the first card).
    final maxOrder =
        await (selectOnly(wallets)..addColumns([wallets.sortOrder.max()]))
            .map((r) => r.read(wallets.sortOrder.max()))
            .getSingleOrNull();
    final syncId = _newSyncId();
    return transaction(() async {
      final id = await into(wallets).insert(
        WalletsCompanion.insert(
          accountId: accountId,
          name: name,
          kind: kind,
          balance: Value(initialAmount),
          initialAmount: Value(initialAmount),
          colorHex: Value(colorHex),
          logoTemplate: Value(logoTemplate),
          sortOrder: Value((maxOrder ?? -1) + 1),
          creditLimit: Value(creditLimit),
          statementDay: Value(statementDay),
          dueDay: Value(dueDay),
          interestRateMonthly: Value(interestRateMonthly),
          interestRateAnnual: Value(interestRateAnnual),
          syncId: Value(syncId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('wallets', syncId, 'insert');
      return id;
    });
  }

  Future<void> updateWallet({
    required int id,
    required String name,
    required String kind,
    String? colorHex,
    String? logoTemplate,
    // Absent means "don't touch"; an explicit Value(null) clears the field.
    // The wallet form always passes all five, so edits there are exact.
    Value<int?> creditLimit = const Value.absent(),
    Value<int?> statementDay = const Value.absent(),
    Value<int?> dueDay = const Value.absent(),
    Value<double?> interestRateMonthly = const Value.absent(),
    Value<double?> interestRateAnnual = const Value.absent(),
  }) {
    return transaction(() async {
      final row = await (select(
        wallets,
      )..where((w) => w.id.equals(id))).getSingleOrNull();
      if (row == null) return;
      await (update(wallets)..where((w) => w.id.equals(id))).write(
        WalletsCompanion(
          name: Value(name),
          kind: Value(kind),
          colorHex: colorHex == null ? const Value.absent() : Value(colorHex),
          // The form sheet always knows the current template, so a null
          // here genuinely means "no template" and is written as such.
          logoTemplate: Value(logoTemplate),
          creditLimit: creditLimit,
          statementDay: statementDay,
          dueDay: dueDay,
          interestRateMonthly: interestRateMonthly,
          interestRateAnnual: interestRateAnnual,
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('wallets', row.syncId, 'update');
    });
  }

  // ------------------------- installment plans -------------------------

  Future<int> addInstallmentPlan({
    required int walletId,
    required String name,
    required int totalAmount,
    required int installmentAmount,
    required int totalCount,
    DateTime? createdAt,
  }) {
    return transaction(() async {
      final syncId = _newSyncId();
      final id = await into(installmentPlans).insert(
        InstallmentPlansCompanion.insert(
          walletId: walletId,
          name: name,
          totalAmount: totalAmount,
          installmentAmount: installmentAmount,
          totalCount: totalCount,
          createdAt: createdAt == null
              ? const Value.absent()
              : Value(createdAt),
          syncId: Value(syncId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('installment_plans', syncId, 'insert');
      return id;
    });
  }

  /// Single plan by id, or null. Used by the delete/edit guards, which
  /// need the plan's counters before deciding whether a linked
  /// transaction may change.
  Future<InstallmentPlan?> getInstallmentPlan(int id) => (select(
    installmentPlans,
  )..where((p) => p.id.equals(id))).getSingleOrNull();

/// Recomputes every derived value from the ledger (concept §7),
/// run after every pull and by the P5 first-run flow. The
/// recompute mirrors the incremental maintainers exactly — see
/// the notes inline — so a pulled ledger always lands on the
/// same balances the local helpers would have maintained.
///
/// Like the other derived writers ([updateGoalSaved],
/// [markInstallmentPaid], [setDebtPaid], [adjustWalletBalance])
/// this writes only the derived columns: no `updatedAt`, no
/// outbox entry — derived state never syncs as a value.
///
/// One deliberate correction over the maintainers: deleting a
/// debt payment whose linked transaction was already deleted
/// directly reverses the wallet effect twice (see
/// [deleteDebtPayment]); the recompute is final-state based, so
/// it lands on the correct balance and heals that drift.
Future<DerivedReconcileResult> reconcileDerivedState() {
  return transaction(() async {
    final allWallets = await select(wallets).get();
    final allTxs = await select(transactions).get();
    final allDebts = await select(debts).get();
    final allPayments = await select(debtPayments).get();
    final allGoals = await select(goals).get();
    final allDeposits = await select(goalDeposits).get();
    final allPlans = await select(installmentPlans).get();

    // --- wallets.balance ---
    // The ledger fold mirrors the incremental maintainers:
    // addTransaction / addTransfer / deleteTransaction (+ undo)
    // and processDueRecurringTransactions move the balance by
    // the same signed amounts. A transfer only moves money when
    // it has a destination (see _reverseBalanceEffect) — a
    // transfer row with a null toWalletId has no balance effect.
    final delta = <int, int>{};
    void addDelta(int? walletId, int amount) {
      if (walletId == null) return;
      delta[walletId] = (delta[walletId] ?? 0) + amount;
    }

    for (final t in allTxs) {
      switch (t.kind) {
        case 'income':
          addDelta(t.walletId, t.amount);
        case 'expense':
          addDelta(t.walletId, -t.amount);
        case 'transfer':
          if (t.toWalletId != null) {
            addDelta(t.walletId, -t.amount);
            addDelta(t.toWalletId, t.amount);
          }
      }
    }
    // Debts and repayments with no history entry still move the
    // wallet: createDebt / recordDebtPayment adjust the balance
    // directly when recordAsTransaction is false. With a history
    // entry the transaction row above already carries the effect,
    // so those rows are skipped here — counting both would double
    // the movement.
    final debtById = {for (final d in allDebts) d.id: d};
    for (final d in allDebts) {
      if (d.walletId != null && !d.recordAsTransaction) {
        addDelta(d.walletId, _debtWalletEffect(d.direction, d.amount));
      }
    }
    for (final p in allPayments) {
      final d = debtById[p.debtId];
      if (p.walletId != null && d != null && !d.recordAsTransaction) {
        addDelta(p.walletId, _debtPaymentEffect(d.direction, p.amount));
      }
    }
    var walletsChanged = 0;
    for (final w in allWallets) {
      final computed = w.initialAmount + (delta[w.id] ?? 0);
      if (computed != w.balance) {
        await (update(wallets)..where((x) => x.id.equals(w.id))).write(
          WalletsCompanion(balance: Value(computed)),
        );
        walletsChanged++;
      }
    }

    // --- installment_plans.paidCount ---
    // Same re-derivation as [_resyncPlanPaidCount]: the recorded
    // installment-payment transfers, capped at totalCount.
    final paymentCounts = <int, int>{};
    for (final t in allTxs) {
      if (t.planId != null && t.kind == 'transfer') {
        paymentCounts[t.planId!] = (paymentCounts[t.planId!] ?? 0) + 1;
      }
    }
    var plansChanged = 0;
    for (final p in allPlans) {
      final computed = (paymentCounts[p.id] ?? 0).clamp(0, p.totalCount);
      if (computed != p.paidCount) {
        await (update(
          installmentPlans,
        )..where((x) => x.id.equals(p.id))).write(
          InstallmentPlansCompanion(paidCount: Value(computed)),
        );
        plansChanged++;
      }
    }

    // --- goals.saved ---
    // Sum of the goal_deposits rows (withdrawals are negative),
    // the same total updateGoalSaved maintains incrementally.
    final savedByGoal = <int, int>{};
    for (final d in allDeposits) {
      savedByGoal[d.goalId] = (savedByGoal[d.goalId] ?? 0) + d.amount;
    }
    var goalsChanged = 0;
    for (final g in allGoals) {
      final computed = savedByGoal[g.id] ?? 0;
      if (computed != g.saved) {
        await (update(goals)..where((x) => x.id.equals(g.id))).write(
          GoalsCompanion(saved: Value(computed)),
        );
        goalsChanged++;
      }
    }

    // --- debts.isPaid ---
    // Paid in full when the payments cover the amount — the same
    // rule recordDebtPayment / updateDebt / deleteDebtPayment use.
    final paidByDebt = <int, int>{};
    for (final p in allPayments) {
      paidByDebt[p.debtId] = (paidByDebt[p.debtId] ?? 0) + p.amount;
    }
    var debtsChanged = 0;
    for (final d in allDebts) {
      final computed = (paidByDebt[d.id] ?? 0) >= d.amount;
      if (computed != d.isPaid) {
        await (update(debts)..where((x) => x.id.equals(d.id))).write(
          DebtsCompanion(isPaid: Value(computed)),
        );
        debtsChanged++;
      }
    }

    return (
      walletsChanged: walletsChanged,
      plansChanged: plansChanged,
      goalsChanged: goalsChanged,
      debtsChanged: debtsChanged,
    );
  });
}

  /// Re-derives a plan's paid counter from its recorded installment
  /// payments (plan-linked transfers), capped at [totalCount]. The
  /// counter is the count of payments, so deleting or restoring a
  /// payment must move it — a blind +/-1 would drift when undos
  /// interleave with other deletes.
  /// No outbox entry: paidCount is derived state, re-derived from
  /// the recorded installment-payment transfers after a pull (see
  /// concept doc section 7). The payment rows carry their own entries.
  Future<void> _resyncPlanPaidCount(int planId) async {
    final plan = await getInstallmentPlan(planId);
    if (plan == null) return;
    final payments =
        await (select(transactions)
              ..where((t) => t.planId.equals(planId))
              ..where((t) => t.kind.equals('transfer')))
            .get();
    final count = payments.length.clamp(0, plan.totalCount);
    if (count != plan.paidCount) {
      await (update(installmentPlans)..where((p) => p.id.equals(planId))).write(
        InstallmentPlansCompanion(paidCount: Value(count)),
      );
    }
  }

  /// Advances a plan by one paid installment, capped at [totalCount].
  /// No-op for unknown or already-complete plans.
  ///
  /// No outbox entry: paidCount is derived (see [_resyncPlanPaidCount]).
  /// The installment-payment transfer that triggers this call carries
  /// the change; the receiving device re-derives the counter.
  Future<void> markInstallmentPaid(int id) async {
    final plan = await (select(
      installmentPlans,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    if (plan == null || plan.paidCount >= plan.totalCount) return;
    await (update(installmentPlans)..where((p) => p.id.equals(id))).write(
      InstallmentPlansCompanion(paidCount: Value(plan.paidCount + 1)),
    );
  }

  /// Creates a plan together with its purchase expense, atomically.
  /// The expense is what makes the plan visible to every money figure:
  /// it pushes the paylater wallet negative by the plan total, so
  /// outstanding, limit used and amount owed all track the plan, and
  /// each installment payment then pays that balance down. Returns the
  /// plan id.
  Future<int> addPlanWithPurchase({
    required int walletId,
    required String name,
    required int totalAmount,
    required int installmentAmount,
    required int totalCount,
    required int categoryId,
  }) {
    return transaction(() async {
      final now = DateTime.now();
      final planSyncId = _newSyncId();
      final planId = await into(installmentPlans).insert(
        InstallmentPlansCompanion.insert(
          walletId: walletId,
          name: name,
          totalAmount: totalAmount,
          installmentAmount: installmentAmount,
          totalCount: totalCount,
          syncId: Value(planSyncId),
          updatedAt: Value(now),
        ),
      );
      await _enqueueOutbox('installment_plans', planSyncId, 'insert');
      final txSyncId = _newSyncId();
      await into(transactions).insert(
        TransactionsCompanion.insert(
          walletId: walletId,
          categoryId: categoryId,
          kind: 'expense',
          amount: totalAmount,
          note: Value(name),
          date: now,
          planId: Value(planId),
          syncId: Value(txSyncId),
          updatedAt: Value(now),
        ),
      );
      await _enqueueOutbox('transactions', txSyncId, 'insert');
      await adjustWalletBalance(walletId, -totalAmount);
      return planId;
    });
  }

  /// Links an already-saved transaction (an auto-plan's expense) to its
  /// plan. Bare update so it joins the caller's transaction.
  Future<void> setTransactionPlan(int transactionId, int planId) {
    return transaction(() async {
      final row = await (select(
        transactions,
      )..where((t) => t.id.equals(transactionId))).getSingleOrNull();
      if (row == null) return;
      await (update(
        transactions,
      )..where((t) => t.id.equals(transactionId))).write(
        TransactionsCompanion(
          planId: Value(planId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('transactions', row.syncId, 'update');
    });
  }

  /// Every transaction belonging to a plan: its purchase expense plus
  /// its installment payments, newest first.
  Future<List<Transaction>> planTransactions(int planId) =>
      (select(transactions)
            ..where((t) => t.planId.equals(planId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  /// Plan id → category id of its purchase expense row. Backs the
  /// Dart-fold sites that attribute an installment payment to the
  /// purchase's category (see `spendingCategoryOf`). A plan whose
  /// purchase is gone simply has no entry; callers fall back to the
  /// transfer row's own category.
  Future<Map<int, int>> planPurchaseCategories() async {
    final rows =
        await (selectOnly(transactions)
              ..addColumns([transactions.planId, transactions.categoryId])
              ..where(
                transactions.planId.isNotNull() &
                    transactions.kind.equals('expense'),
              ))
            .get();
    final map = <int, int>{};
    for (final row in rows) {
      final planId = row.read(transactions.planId);
      final categoryId = row.read(transactions.categoryId);
      if (planId != null && categoryId != null) map[planId] = categoryId;
    }
    return map;
  }

  /// Live version of [planTransactions] with wallet/category details,
  /// for the plan history sheet.
  Stream<List<TransactionWithDetails>> watchPlanTransactions(int planId) {
    final q = _joinedTransactions()..where(transactions.planId.equals(planId));
    return q.watch().map(_toDetails);
  }

  /// Deletes a plan and every transaction linked to it — its purchase
  /// expense and its installment payments — each through the normal
  /// delete path, so all wallet balances are restored and the wallet
  /// returns to its pre-plan state.
  Future<void> deleteInstallmentPlan(int id) {
    return transaction(() async {
      final plan = await getInstallmentPlan(id);
      if (plan == null) return;
      final linked = await planTransactions(id);
      // The plan row goes first: deleting its purchase through the
      // normal path would otherwise refuse while payments exist.
      await (delete(installmentPlans)..where((p) => p.id.equals(id))).go();
      await _enqueueOutbox('installment_plans', plan.syncId, 'delete');
      for (final t in linked) {
        await deleteTransaction(t.id);
      }
    });
  }

  /// Edits a plan's terms in place. When the total changes, the new
  /// amount is written through to the plan's linked purchase expense
  /// via [updateTransaction] — reversing the old expense and applying
  /// the new one — so the plan and the wallet balance never disagree
  /// about what was bought. A plan with no linked purchase expense
  /// cannot have its total changed: that throws a [StateError]
  /// rather than letting the plan drift from the ledger. The
  /// purchase's date follows [createdAt]'s day (keeping its own
  /// time), so the expense and the plan's schedule anchor keep
  /// describing the same purchase. [paidCount] is written only when
  /// provided — it exists for repairing the counter from the
  /// recorded payments, never for normal edits.
  Future<void> editInstallmentPlan({
    required int planId,
    required String name,
    required int totalAmount,
    required int installmentAmount,
    required int totalCount,
    required DateTime createdAt,
    int? paidCount,
    int? walletId,
  }) {
    return transaction(() async {
      final plan = await (select(
        installmentPlans,
      )..where((p) => p.id.equals(planId))).getSingleOrNull();
      if (plan == null) return;
      // The edit sheet guards these too, but the DB layer must not
      // persist a counter state the helpers can't represent.
      if (totalCount < plan.paidCount) {
        throw ArgumentError(
          'totalCount $totalCount is below paidCount ${plan.paidCount}',
        );
      }
      if (paidCount != null && paidCount > totalCount) {
        throw ArgumentError(
          'paidCount $paidCount exceeds totalCount $totalCount',
        );
      }
      Transaction? purchase;
      for (final t in await planTransactions(planId)) {
        if (t.kind == 'expense') {
          purchase = t;
          break;
        }
      }
      final dayChanged =
          createdAt.year != plan.createdAt.year ||
          createdAt.month != plan.createdAt.month ||
          createdAt.day != plan.createdAt.day;
      if (purchase != null && (totalAmount != plan.totalAmount || dayChanged)) {
        await updateTransaction(
          id: purchase.id,
          walletId: purchase.walletId,
          categoryId: purchase.categoryId,
          kind: purchase.kind,
          amount: totalAmount,
          note: purchase.note,
          memo: purchase.memo,
          date: dayChanged
              ? DateTime(
                  createdAt.year,
                  createdAt.month,
                  createdAt.day,
                  purchase.date.hour,
                  purchase.date.minute,
                )
              : purchase.date,
        );
      } else if (totalAmount != plan.totalAmount) {
        throw StateError(
          'Plan $planId has no linked purchase; its total cannot change.',
        );
      }
      await (update(installmentPlans)..where((p) => p.id.equals(planId))).write(
        InstallmentPlansCompanion(
          name: Value(name),
          totalAmount: Value(totalAmount),
          installmentAmount: Value(installmentAmount),
          totalCount: Value(totalCount),
          createdAt: Value(createdAt),
          paidCount: paidCount == null
              ? const Value.absent()
              : Value(paidCount),
          walletId: walletId == null ? const Value.absent() : Value(walletId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('installment_plans', plan.syncId, 'update');
    });
  }

  Stream<List<InstallmentPlan>> watchInstallmentPlans() => (select(
    installmentPlans,
  )..orderBy([(p) => OrderingTerm.desc(p.createdAt)])).watch();

  /// Plans on one wallet, for the due card's pay action (fresh read at
  /// tap time, not the dashboard's stream snapshot).
  Future<List<InstallmentPlan>> plansForWallet(int walletId) => (select(
    installmentPlans,
  )..where((p) => p.walletId.equals(walletId))).get();

  /// Deletes a wallet. Returns false when it still has transactions —
  /// those must be moved or deleted first — or when it still has
  /// installment plans, recurring rules, templates, or debts. Foreign
  /// keys are unenforced at runtime, so deleting a wallet with any of
  /// those would strand them: a recurring rule would keep posting
  /// transactions that no wallet list can show.
  Future<bool> deleteWallet(int id) async {
    final wallet = await getWalletById(id);
    final txCount =
        await (select(transactions)..where(
              (t) => t.walletId.equals(id) | t.toWalletId.equalsNullable(id),
            ))
            .get();
    if (txCount.isNotEmpty) return false;
    final plans = await (select(
      installmentPlans,
    )..where((p) => p.walletId.equals(id))).get();
    if (plans.isNotEmpty) return false;
    final rules = await (select(
      recurringTransactions,
    )..where((r) => r.walletId.equals(id))).get();
    if (rules.isNotEmpty) return false;
    final templates = await (select(
      transactionTemplates,
    )..where((t) => t.walletId.equals(id))).get();
    if (templates.isNotEmpty) return false;
    final linkedDebts = await (select(
      debts,
    )..where((d) => d.walletId.equals(id))).get();
    if (linkedDebts.isNotEmpty) return false;
    await transaction(() async {
      await (delete(wallets)..where((w) => w.id.equals(id))).go();
      if (wallet != null) {
        await _enqueueOutbox('wallets', wallet.syncId, 'delete');
      }
    });
    return true;
  }

  Future<int> addAccount(AccountsCompanion entry) {
    return transaction(() async {
      final syncId = _companionSyncId(entry.syncId);
      final id = await into(accounts).insert(
        entry.copyWith(syncId: Value(syncId), updatedAt: Value(DateTime.now())),
      );
      await _enqueueOutbox('accounts', syncId, 'insert');
      return id;
    });
  }

  Future<void> renameAccount(int id, String name) {
    return transaction(() async {
      final row = await (select(
        accounts,
      )..where((a) => a.id.equals(id))).getSingleOrNull();
      if (row == null) return;
      await (update(accounts)..where((a) => a.id.equals(id))).write(
        AccountsCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
      );
      await _enqueueOutbox('accounts', row.syncId, 'update');
    });
  }

  Future<void> setAccountColor(int id, String colorHex) {
    return transaction(() async {
      final row = await (select(
        accounts,
      )..where((a) => a.id.equals(id))).getSingleOrNull();
      if (row == null) return;
      await (update(accounts)..where((a) => a.id.equals(id))).write(
        AccountsCompanion(
          colorHex: Value(colorHex),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('accounts', row.syncId, 'update');
    });
  }

  /// Moves [walletIds] into [accountId].
  Future<void> moveWalletsToAccount(List<int> walletIds, int accountId) {
    return transaction(() async {
      final moving = await (select(
        wallets,
      )..where((w) => w.id.isIn(walletIds))).get();
      await (update(wallets)..where((w) => w.id.isIn(walletIds))).write(
        WalletsCompanion(
          accountId: Value(accountId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      for (final w in moving) {
        await _enqueueOutbox('wallets', w.syncId, 'update');
      }
    });
  }

  /// Deletes an account after reassigning its wallets to [moveWalletsToId].
  /// Wallets are never orphaned; callers must refuse the last account.
  Future<void> deleteAccount(int id, int moveWalletsToId) =>
      transaction(() async {
        final account = await (select(
          accounts,
        )..where((a) => a.id.equals(id))).getSingleOrNull();
        final moving = await (select(
          wallets,
        )..where((w) => w.accountId.equals(id))).get();
        await (update(wallets)..where((w) => w.accountId.equals(id))).write(
          WalletsCompanion(
            accountId: Value(moveWalletsToId),
            updatedAt: Value(DateTime.now()),
          ),
        );
        for (final w in moving) {
          await _enqueueOutbox('wallets', w.syncId, 'update');
        }
        await (delete(accounts)..where((a) => a.id.equals(id))).go();
        if (account != null) {
          await _enqueueOutbox('accounts', account.syncId, 'delete');
        }
      });

  Future<int> addCategory(CategoriesCompanion entry) {
    return transaction(() async {
      final syncId = _companionSyncId(entry.syncId);
      final id = await into(categories).insert(
        entry.copyWith(syncId: Value(syncId), updatedAt: Value(DateTime.now())),
      );
      await _enqueueOutbox('categories', syncId, 'insert');
      return id;
    });
  }

  /// Deletes a category and its subcategories. Every row that pointed
  /// at them — transactions, budgets, recurring rules, templates — is
  /// reassigned to the 'Uncategorized' fallback first, so the delete
  /// can never orphan history out of the joined lists (the old code
  /// deleted the rows and left orphans that inner joins dropped
  /// silently). Learned keyword rows for the deleted categories are
  /// dropped: they are derived data, and suggesting a dead category
  /// would be worse than relearning. The fallback itself is immortal:
  /// deleting it is a no-op, since reassigning to it and then deleting
  /// it would orphan everything again.
  Future<void> deleteCategory(int id) {
    return transaction(() async {
      final fallbackId = await uncategorizedCategoryId;
      if (id == fallbackId) return;
      final subIds = await (select(
        categories,
      )..where((c) => c.parentId.equals(id))).map((c) => c.id).get();
      final deadIds = [id, ...subIds];
      // Sync: the reassignments below change these rows, and the
      // deletions remove them — capture their sync ids first so the
      // outbox can describe every change in this transaction.
      final deadCategories = await (select(
        categories,
      )..where((c) => c.id.isIn(deadIds))).get();
      final reassignedTx = await (select(
        transactions,
      )..where((t) => t.categoryId.isIn(deadIds))).get();
      final reassignedBudgets = await (select(
        budgets,
      )..where((b) => b.categoryId.isIn(deadIds))).get();
      final reassignedRules = await (select(
        recurringTransactions,
      )..where((r) => r.categoryId.isIn(deadIds))).get();
      final reassignedTemplates = await (select(
        transactionTemplates,
      )..where((t) => t.categoryId.isIn(deadIds))).get();
      final deadKeywords = await (select(
        categoryKeywords,
      )..where((k) => k.categoryId.isIn(deadIds))).get();
      final now = DateTime.now();
      await (update(
        transactions,
      )..where((t) => t.categoryId.isIn(deadIds))).write(
        TransactionsCompanion(
          categoryId: Value(fallbackId),
          updatedAt: Value(now),
        ),
      );
      await (update(budgets)..where((b) => b.categoryId.isIn(deadIds))).write(
        BudgetsCompanion(categoryId: Value(fallbackId), updatedAt: Value(now)),
      );
      await (update(
        recurringTransactions,
      )..where((r) => r.categoryId.isIn(deadIds))).write(
        RecurringTransactionsCompanion(
          categoryId: Value(fallbackId),
          updatedAt: Value(now),
        ),
      );
      await (update(
        transactionTemplates,
      )..where((t) => t.categoryId.isIn(deadIds))).write(
        TransactionTemplatesCompanion(
          categoryId: Value(fallbackId),
          updatedAt: Value(now),
        ),
      );
      await (delete(
        categoryKeywords,
      )..where((k) => k.categoryId.isIn(deadIds))).go();
      await (delete(categories)..where((c) => c.parentId.equals(id))).go();
      await (delete(categories)..where((c) => c.id.equals(id))).go();
      for (final t in reassignedTx) {
        await _enqueueOutbox('transactions', t.syncId, 'update');
      }
      for (final b in reassignedBudgets) {
        await _enqueueOutbox('budgets', b.syncId, 'update');
      }
      for (final r in reassignedRules) {
        await _enqueueOutbox('recurring_transactions', r.syncId, 'update');
      }
      for (final t in reassignedTemplates) {
        await _enqueueOutbox('transaction_templates', t.syncId, 'update');
      }
      for (final k in deadKeywords) {
        await _enqueueOutbox('category_keywords', k.syncId, 'delete');
      }
      for (final c in deadCategories) {
        await _enqueueOutbox('categories', c.syncId, 'delete');
      }
    });
  }

  Future<int> addBudget(BudgetsCompanion entry) {
    return transaction(() async {
      final syncId = _companionSyncId(entry.syncId);
      final id = await into(budgets).insert(
        entry.copyWith(syncId: Value(syncId), updatedAt: Value(DateTime.now())),
      );
      await _enqueueOutbox('budgets', syncId, 'insert');
      return id;
    });
  }

  Future<void> updateBudgetLimit(int budgetId, int limit) {
    return transaction(() async {
      final row = await (select(
        budgets,
      )..where((b) => b.id.equals(budgetId))).getSingleOrNull();
      if (row == null) return;
      await (update(budgets)..where((b) => b.id.equals(budgetId))).write(
        BudgetsCompanion(limit: Value(limit), updatedAt: Value(DateTime.now())),
      );
      await _enqueueOutbox('budgets', row.syncId, 'update');
    });
  }

  Future<void> deleteBudget(int budgetId) async {
    final row = await (select(
      budgets,
    )..where((b) => b.id.equals(budgetId))).getSingleOrNull();
    if (row == null) return;
    await transaction(() async {
      await (delete(budgets)..where((b) => b.id.equals(budgetId))).go();
      await _enqueueOutbox('budgets', row.syncId, 'delete');
    });
  }

  Future<Budget?> getBudgetById(int id) =>
      (select(budgets)..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<int> addGoal(GoalsCompanion entry) {
    return transaction(() async {
      final syncId = _companionSyncId(entry.syncId);
      final id = await into(goals).insert(
        entry.copyWith(syncId: Value(syncId), updatedAt: Value(DateTime.now())),
      );
      await _enqueueOutbox('goals', syncId, 'insert');
      return id;
    });
  }

  Future<Goal?> getGoalById(int id) =>
      (select(goals)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<void> updateGoal({
    required int id,
    required String name,
    required int target,
    DateTime? deadline,
    String? colorHex,
  }) {
    return transaction(() async {
      final row = await (select(
        goals,
      )..where((g) => g.id.equals(id))).getSingleOrNull();
      if (row == null) return;
      await (update(goals)..where((g) => g.id.equals(id))).write(
        GoalsCompanion(
          name: Value(name),
          target: Value(target),
          deadline: Value(deadline),
          colorHex: colorHex == null ? const Value.absent() : Value(colorHex),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('goals', row.syncId, 'update');
    });
  }

  Future<void> deleteGoal(int id) {
    return transaction(() async {
      final goal = await getGoalById(id);
      final deposits = await (select(
        goalDeposits,
      )..where((d) => d.goalId.equals(id))).get();
      await (delete(goalDeposits)..where((d) => d.goalId.equals(id))).go();
      for (final d in deposits) {
        await _enqueueOutbox('goal_deposits', d.syncId, 'delete');
      }
      await (delete(goals)..where((g) => g.id.equals(id))).go();
      if (goal != null) {
        await _enqueueOutbox('goals', goal.syncId, 'delete');
      }
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
      final depositSyncId = _newSyncId();
      await into(goalDeposits).insert(
        GoalDepositsCompanion.insert(
          goalId: goalId,
          amount: amount,
          date: date,
          note: Value(note),
          syncId: Value(depositSyncId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('goal_deposits', depositSyncId, 'insert');
      await updateGoalSaved(goalId, goal.saved + amount);
    });
  }

  /// Deletes one deposit/withdrawal entry, reversing the saved total.
  Future<void> deleteGoalDeposit(GoalDeposit deposit) {
    return transaction(() async {
      final goal = await getGoalById(deposit.goalId);
      await (delete(goalDeposits)..where((d) => d.id.equals(deposit.id))).go();
      await _enqueueOutbox('goal_deposits', deposit.syncId, 'delete');
      if (goal != null) {
        await updateGoalSaved(deposit.goalId, goal.saved - deposit.amount);
      }
    });
  }

  /// No outbox entry: `saved` is derived from the goal_deposits rows
  /// (see concept doc section 7). The deposit rows carry the change.
  Future<void> updateGoalSaved(int id, int saved) => (update(
    goals,
  )..where((g) => g.id.equals(id))).write(GoalsCompanion(saved: Value(saved)));

  Future<int> addDebt(DebtsCompanion entry) {
    return transaction(() async {
      final syncId = _companionSyncId(entry.syncId);
      final id = await into(debts).insert(
        entry.copyWith(syncId: Value(syncId), updatedAt: Value(DateTime.now())),
      );
      await _enqueueOutbox('debts', syncId, 'insert');
      return id;
    });
  }

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
      final debtSyncId = _newSyncId();
      final id = await into(debts).insert(
        DebtsCompanion.insert(
          person: person,
          note: Value(note),
          amount: amount,
          direction: direction,
          dueDate: Value(dueDate),
          walletId: Value(walletId),
          colorHex: Value(colorHex),
          recordAsTransaction: Value(recordAsTransaction),
          createdAt: Value(now),
          syncId: Value(debtSyncId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('debts', debtSyncId, 'insert');
      if (walletId != null) {
        if (recordAsTransaction) {
          final catId = await debtCategoryId;
          final txSyncId = _newSyncId();
          await into(transactions).insert(
            TransactionsCompanion.insert(
              walletId: walletId,
              categoryId: catId,
              kind: direction == 'receivable' ? 'expense' : 'income',
              amount: amount,
              note: Value(_debtTxNote(direction, person, note, payment: false)),
              date: now,
              debtId: Value(id),
              syncId: Value(txSyncId),
              updatedAt: Value(DateTime.now()),
            ),
          );
          await _enqueueOutbox('transactions', txSyncId, 'insert');
        }
        await adjustWalletBalance(
          walletId,
          _debtWalletEffect(direction, amount),
        );
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
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('debts', old.syncId, 'update');

      // The creation entry is the debt-linked transaction without a
      // payment link; payment entries carry debtPaymentId.
      final linkedTx =
          await (select(transactions)
                ..where((t) => t.debtId.equals(id) & t.debtPaymentId.isNull()))
              .getSingleOrNull();

      // Undo the old wallet effect, however it was applied.
      if (linkedTx != null) {
        await _reverseBalanceEffect(linkedTx);
      } else if (old.walletId != null) {
        await adjustWalletBalance(
          old.walletId!,
          -_debtWalletEffect(old.direction, old.amount),
        );
      }

      // Apply the new wallet effect, with or without a history entry.
      if (recordAsTransaction && walletId != null) {
        final catId = await debtCategoryId;
        final kind = old.direction == 'receivable' ? 'expense' : 'income';
        final txNote = _debtTxNote(old.direction, person, note, payment: false);
        if (linkedTx != null) {
          await (update(
            transactions,
          )..where((t) => t.id.equals(linkedTx.id))).write(
            TransactionsCompanion(
              walletId: Value(walletId),
              categoryId: Value(catId),
              kind: Value(kind),
              amount: Value(amount),
              note: Value(txNote),
              date: Value(linkedTx.date),
              updatedAt: Value(DateTime.now()),
            ),
          );
          await _enqueueOutbox('transactions', linkedTx.syncId, 'update');
        } else {
          final txSyncId = _newSyncId();
          await into(transactions).insert(
            TransactionsCompanion.insert(
              walletId: walletId,
              categoryId: catId,
              kind: kind,
              amount: amount,
              note: Value(txNote),
              date: old.createdAt,
              debtId: Value(id),
              syncId: Value(txSyncId),
              updatedAt: Value(DateTime.now()),
            ),
          );
          await _enqueueOutbox('transactions', txSyncId, 'insert');
        }
        await adjustWalletBalance(
          walletId,
          _debtWalletEffect(old.direction, amount),
        );
      } else {
        if (linkedTx != null) {
          // The entry is no longer wanted — drop the orphaned row.
          await (delete(
            transactions,
          )..where((t) => t.id.equals(linkedTx.id))).go();
          await _enqueueOutbox('transactions', linkedTx.syncId, 'delete');
        }
        if (walletId != null) {
          await adjustWalletBalance(
            walletId,
            _debtWalletEffect(old.direction, amount),
          );
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
      final linked = await (select(
        transactions,
      )..where((t) => t.debtId.equals(id))).get();
      for (final t in linked) {
        await _reverseBalanceEffect(t);
      }
      if (linked.isNotEmpty) {
        await (delete(transactions)..where((t) => t.debtId.equals(id))).go();
        for (final t in linked) {
          await _enqueueOutbox('transactions', t.syncId, 'delete');
        }
      }
      // Legacy/manual path: reverse effects that have no history entry.
      final hasCreationTx = linked.any((t) => t.debtPaymentId == null);
      if (!hasCreationTx && debt.walletId != null) {
        await adjustWalletBalance(
          debt.walletId!,
          -_debtWalletEffect(debt.direction, debt.amount),
        );
      }
      final payments = await (select(
        debtPayments,
      )..where((p) => p.debtId.equals(id))).get();
      for (final p in payments) {
        final hasTx = linked.any((t) => t.debtPaymentId == p.id);
        if (!hasTx && p.walletId != null) {
          await adjustWalletBalance(
            p.walletId!,
            -_debtPaymentEffect(debt.direction, p.amount),
          );
        }
      }
      // Note: the linked transactions' photo rows are NOT deleted here
      // (pre-existing behaviour — they stay orphaned in the table),
      // so no photo outbox entries either; their rows still exist.
      await (delete(debtPayments)..where((p) => p.debtId.equals(id))).go();
      for (final p in payments) {
        await _enqueueOutbox('debt_payments', p.syncId, 'delete');
      }
      await (delete(debts)..where((d) => d.id.equals(id))).go();
      await _enqueueOutbox('debts', debt.syncId, 'delete');
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
      final paymentSyncId = _newSyncId();
      final paymentId = await into(debtPayments).insert(
        DebtPaymentsCompanion.insert(
          debtId: debt.id,
          amount: amount,
          date: date,
          note: Value(note),
          walletId: Value(walletId),
          syncId: Value(paymentSyncId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('debt_payments', paymentSyncId, 'insert');
      if (walletId != null) {
        if (debt.recordAsTransaction) {
          final catId = await debtCategoryId;
          final txSyncId = _newSyncId();
          await into(transactions).insert(
            TransactionsCompanion.insert(
              walletId: walletId,
              categoryId: catId,
              kind: debt.direction == 'receivable' ? 'income' : 'expense',
              amount: amount,
              note: Value(
                _debtTxNote(debt.direction, debt.person, note, payment: true),
              ),
              date: date,
              debtId: Value(debt.id),
              debtPaymentId: Value(paymentId),
              syncId: Value(txSyncId),
              updatedAt: Value(DateTime.now()),
            ),
          );
          await _enqueueOutbox('transactions', txSyncId, 'insert');
        }
        await adjustWalletBalance(
          walletId,
          _debtPaymentEffect(debt.direction, amount),
        );
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
      final linkedTx = await (select(
        transactions,
      )..where((t) => t.debtPaymentId.equals(payment.id))).getSingleOrNull();
      if (linkedTx != null) {
        await _reverseBalanceEffect(linkedTx);
        await (delete(
          transactions,
        )..where((t) => t.id.equals(linkedTx.id))).go();
        await _enqueueOutbox('transactions', linkedTx.syncId, 'delete');
      } else if (payment.walletId != null) {
        await adjustWalletBalance(
          payment.walletId!,
          -_debtPaymentEffect(debt.direction, payment.amount),
        );
      }
      await (delete(debtPayments)..where((p) => p.id.equals(payment.id))).go();
      await _enqueueOutbox('debt_payments', payment.syncId, 'delete');
      final paidTotal = await debtPaidTotal(debt.id);
      if (paidTotal < debt.amount && debt.isPaid) {
        await setDebtPaid(debt.id, false);
      }
    });
  }

  /// No outbox entry: `isPaid` is derived from the debt_payments
  /// rows (paid total >= amount). The payment rows carry the change.
  Future<void> setDebtPaid(int id, bool paid) => (update(
    debts,
  )..where((d) => d.id.equals(id))).write(DebtsCompanion(isPaid: Value(paid)));

  Future<List<TransactionWithDetails>> getTransactionsInRange(
    DateTime from,
    DateTime to,
  ) async {
    final q = _joinedTransactions()
      ..where(transactions.date.isBetweenValues(from, to));
    return _toDetails(await q.get());
  }

  /// Live version of [getTransactionsInRange]: joined transaction rows
  /// inside [from, to], newest first. Powers the month-grouped history.
  Stream<List<TransactionWithDetails>> watchTransactionsInRange(
    DateTime from,
    DateTime to, {
    int? accountId,
  }) {
    final q = _joinedTransactions()
      ..where(transactions.date.isBetweenValues(from, to));
    if (accountId != null) q.where(wallets.accountId.equals(accountId));
    return q.watch().map(_toDetails);
  }

  /// One transaction with its category + wallet, or null when missing.
  /// Prefer this over scanning [getTransactionsInRange] when only a
  /// single row is needed (detail screen, duplicate, delete).
  Future<TransactionWithDetails?> getTransactionDetailById(int id) async {
    final q = _joinedTransactions()..where(transactions.id.equals(id));
    final rows = await q.get();
    return rows.isEmpty ? null : _toDetails(rows).first;
  }

  // ------------------------- recurring transactions ----------------------

  Stream<List<RecurringTransaction>> watchRecurringTransactions() => (select(
    recurringTransactions,
  )..orderBy([(r) => OrderingTerm.asc(r.nextDue)])).watch();

  Future<int> addRecurringTransaction(RecurringTransactionsCompanion entry) {
    return transaction(() async {
      final syncId = _companionSyncId(entry.syncId);
      final id = await into(recurringTransactions).insert(
        entry.copyWith(syncId: Value(syncId), updatedAt: Value(DateTime.now())),
      );
      await _enqueueOutbox('recurring_transactions', syncId, 'insert');
      return id;
    });
  }

  Future<void> updateRecurringTransaction(
    int id,
    RecurringTransactionsCompanion entry,
  ) {
    return transaction(() async {
      final row = await (select(
        recurringTransactions,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      if (row == null) return;
      await (update(recurringTransactions)..where((r) => r.id.equals(id)))
          .write(entry.copyWith(updatedAt: Value(DateTime.now())));
      await _enqueueOutbox('recurring_transactions', row.syncId, 'update');
    });
  }

  Future<void> deleteRecurringTransaction(int id) async {
    final row = await (select(
      recurringTransactions,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await transaction(() async {
      await (delete(recurringTransactions)..where((r) => r.id.equals(id))).go();
      await _enqueueOutbox('recurring_transactions', row.syncId, 'delete');
    });
  }

  Future<void> setRecurringActive(int id, bool active) {
    return transaction(() async {
      final row = await (select(
        recurringTransactions,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      if (row == null) return;
      await (update(
        recurringTransactions,
      )..where((r) => r.id.equals(id))).write(
        RecurringTransactionsCompanion(
          active: Value(active),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('recurring_transactions', row.syncId, 'update');
    });
  }

  /// Materializes every due occurrence of active recurring rules as real
  /// transactions (linked via transactions.recurringId) and advances each
  /// rule's nextDue. Returns the number of generated transactions.
  /// Called on app start; safe to call repeatedly.
  ///
  /// Each rule runs in its own transaction: one broken rule (e.g. pointing
  /// at a wallet that no longer exists) is logged and skipped — it used to
  /// abort the shared transaction, silently blocking every other rule on
  /// every launch. A failed rule keeps its nextDue, so it is retried (and
  /// re-logged) on the next launch.
  Future<int> processDueRecurringTransactions() async {
    final now = DateTime.now();
    final rules =
        await (select(recurringTransactions)
              ..where((r) => r.active.equals(true))
              ..where((r) => r.nextDue.isSmallerOrEqualValue(now)))
            .get();
    var generated = 0;
    for (final rule in rules) {
      try {
        // Paylater income gate (defense in depth): an income rule on a
        // paylater wallet must never post — the same rule as
        // isIncomeToPaylaterBlocked, inlined here because paylater.dart
        // imports this file. A pre-existing bad rule is left alone:
        // it generates nothing and keeps its nextDue, so it is retried
        // (and re-logged) next launch instead of silently dropping
        // occurrences or blocking the batch.
        final wallet = await getWalletById(rule.walletId);
        if (wallet != null &&
            rule.kind == 'income' &&
            wallet.kind == 'paylater') {
          debugPrint(
            'processDueRecurringTransactions: rule ${rule.id} skipped: '
            'income to a paylater wallet is not allowed',
          );
          continue;
        }
        generated += await transaction(() async {
          var due = rule.nextDue;
          var count = 0;
          var guard = 0;
          // Catch up on missed occurrences (guarded against runaway rules).
          while (!due.isAfter(now) &&
              (rule.endDate == null || !due.isAfter(rule.endDate!)) &&
              guard < 36) {
            final txSyncId = _newSyncId();
            await into(transactions).insert(
              TransactionsCompanion.insert(
                walletId: rule.walletId,
                categoryId: rule.categoryId,
                kind: rule.kind,
                amount: rule.amount,
                note: Value(rule.note),
                date: due,
                recurringId: Value(rule.id),
                syncId: Value(txSyncId),
                updatedAt: Value(DateTime.now()),
              ),
            );
            await _enqueueOutbox('transactions', txSyncId, 'insert');
            await adjustWalletBalance(
              rule.walletId,
              rule.kind == 'income' ? rule.amount : -rule.amount,
            );
            count++;
            due = _advanceRecurring(due, rule.frequency);
            guard++;
          }
          await (update(
            recurringTransactions,
          )..where((r) => r.id.equals(rule.id))).write(
            RecurringTransactionsCompanion(
              nextDue: Value(due),
              updatedAt: Value(DateTime.now()),
            ),
          );
          // next_due syncs as a value (last-write-wins, see
          // 0001_init.sql) — never recomputed, or a stale device
          // would double-post an occurrence. P5 must pull before
          // generation runs on launch.
          await _enqueueOutbox('recurring_transactions', rule.syncId, 'update');
          return count;
        });
      } catch (e, st) {
        debugPrint(
          'processDueRecurringTransactions: rule ${rule.id} failed: $e\n$st',
        );
      }
    }
    return generated;
  }

  DateTime _advanceRecurring(DateTime d, String frequency) =>
      advanceRecurringDate(d, frequency);

  // ------------------------- transaction templates -----------------------

  Stream<List<TransactionTemplate>> watchTransactionTemplates() =>
      (select(transactionTemplates)..orderBy([
            (t) => OrderingTerm.desc(t.useCount),
            (t) => OrderingTerm.asc(t.name),
          ]))
          .watch();

  Future<int> addTransactionTemplate(TransactionTemplatesCompanion entry) {
    return transaction(() async {
      final syncId = _companionSyncId(entry.syncId);
      final id = await into(transactionTemplates).insert(
        entry.copyWith(syncId: Value(syncId), updatedAt: Value(DateTime.now())),
      );
      await _enqueueOutbox('transaction_templates', syncId, 'insert');
      return id;
    });
  }

  Future<void> deleteTransactionTemplate(int id) async {
    final row = await (select(
      transactionTemplates,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await transaction(() async {
      await (delete(transactionTemplates)..where((t) => t.id.equals(id))).go();
      await _enqueueOutbox('transaction_templates', row.syncId, 'delete');
    });
  }

  /// The server stores use_count and syncs it last-write-wins (see
  /// 0001_init.sql) — it may undercount slightly when two devices use
  /// the same template between syncs. Cosmetic only, but it is a real
  /// column change, so it gets an outbox entry like any other update.
  Future<void> bumpTemplateUse(int id) async {
    final row = await (select(
      transactionTemplates,
    )..where((t) => t.id.equals(id))).getSingle();
    await transaction(() async {
      await (update(transactionTemplates)..where((t) => t.id.equals(id))).write(
        TransactionTemplatesCompanion(
          useCount: Value(row.useCount + 1),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _enqueueOutbox('transaction_templates', row.syncId, 'update');
    });
  }

  // ------------------------- keyword learning -------------------------
  // Smart category suggestions: all learning happens on-device in the
  // category_keywords table. Callers tokenize the note themselves.

  /// Records that [tokens] were saved with [categoryId].
  Future<void> learnKeywords(Set<String> tokens, int categoryId) =>
      _bumpKeywords(tokens, categoryId, 1);

  /// Removes one learning record per token (floored at zero).
  Future<void> unlearnKeywords(Set<String> tokens, int categoryId) =>
      _bumpKeywords(tokens, categoryId, -1);

  Future<void> _bumpKeywords(Set<String> tokens, int categoryId, int by) async {
    if (tokens.isEmpty) return;
    await transaction(() async {
      for (final token in tokens) {
        await _bumpKeywordRaw(token, categoryId, by);
      }
    });
  }

  /// Bulk-learns accumulated keyword → category → count in one transaction
  /// (used by the one-time history backfill).
  Future<void> learnKeywordCounts(Map<String, Map<int, int>> counts) async {
    await transaction(() async {
      for (final e in counts.entries) {
        for (final ce in e.value.entries) {
          await _bumpKeywordRaw(e.key, ce.key, ce.value);
        }
      }
    });
  }

  /// Single UPDATE-or-INSERT; callers own the transaction. The row's
  /// deterministic sync id (see [_keywordSyncId]) is computed from
  /// its category, so two devices learning the same keyword agree.
  Future<void> _bumpKeywordRaw(String token, int categoryId, int by) async {
    final now = DateTime.now();
    final existing =
        await (select(categoryKeywords)
              ..where((k) => k.keyword.equals(token))
              ..where((k) => k.categoryId.equals(categoryId)))
            .getSingleOrNull();
    if (existing != null) {
      await customUpdate(
        by >= 0
            ? 'UPDATE category_keywords SET hits = hits + ?, '
                  'updated_at = ? WHERE keyword = ? AND category_id = ?'
            : 'UPDATE category_keywords SET hits = MAX(hits + ?, 0), '
                  'updated_at = ? WHERE keyword = ? AND category_id = ?',
        variables: [
          Variable.withInt(by),
          Variable.withDateTime(now),
          Variable.withString(token),
          Variable.withInt(categoryId),
        ],
        updates: {categoryKeywords},
      );
      await _enqueueOutbox('category_keywords', existing.syncId, 'update');
      return;
    }
    if (by <= 0) return;
    final category = await (select(
      categories,
    )..where((c) => c.id.equals(categoryId))).getSingleOrNull();
    final syncId = category == null
        ? _newSyncId()
        : _keywordSyncId(token, category.syncId);
    await into(categoryKeywords).insert(
      CategoryKeywordsCompanion.insert(
        keyword: token,
        categoryId: categoryId,
        hits: Value(by),
        syncId: Value(syncId),
        updatedAt: Value(now),
      ),
    );
    await _enqueueOutbox('category_keywords', syncId, 'insert');
  }

  /// keyword → {categoryId → hits} for the given tokens.
  Future<Map<String, Map<int, int>>> keywordHits(Set<String> tokens) async {
    final map = <String, Map<int, int>>{};
    if (tokens.isEmpty) return map;
    final rows = await (select(
      categoryKeywords,
    )..where((k) => k.keyword.isIn(tokens))).get();
    for (final r in rows) {
      map.putIfAbsent(r.keyword, () => {})[r.categoryId] = r.hits;
    }
    return map;
  }

  /// Transactions eligible for learning: income/expense, excluding
  /// transfers and debt-linked entries. (Empty notes are skipped by the
  /// tokenizer during backfill.)
  Future<List<Transaction>> learnableTransactions() =>
      (select(transactions)
            ..where((t) => t.kind.isIn(['income', 'expense']))
            ..where((t) => t.debtId.isNull())
            ..where((t) => t.debtPaymentId.isNull()))
          .get();

  Future<List<Category>> allCategories() => select(categories).get();

  // -------------------------------- internals ----------------------------

  JoinedSelectStatement _joinedTransactions() {
    final q = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      innerJoin(wallets, wallets.id.equalsExp(transactions.walletId)),
    ]);
    q.orderBy([OrderingTerm.desc(transactions.date)]);
    return q;
  }

  List<TransactionWithDetails> _toDetails(List<TypedResult> rows) {
    return rows
        .map(
          (row) => TransactionWithDetails(
            transaction: row.readTable(transactions),
            category: row.readTable(categories),
            wallet: row.readTable(wallets),
          ),
        )
        .toList();
  }

  // --------------------------------- seed --------------------------------

  Future<int> _categoryIdByName(String name) async {
    final row = await (select(
      categories,
    )..where((c) => c.name.equals(name))).getSingle();
    return row.id;
  }

  Future<void> _seed() async {
    // Fresh installs only get categories. Accounts and wallets are
    // created by the onboarding flow; sample transactions/budgets/
    // goals/debts are no longer seeded so new users start clean.
    Future<void> cat(String name, String icon, String color, String kind) =>
        into(categories).insert(
          CategoriesCompanion.insert(
            name: name,
            iconKey: Value(icon),
            colorHex: Value(color),
            kind: kind,
          ),
        );

    // Income (reference order).
    await cat('Allowance', 'payments', '#38BDF8', 'income');
    await cat('Award', 'award', '#2DD4BF', 'income');
    await cat('Bonus', 'paid', '#14B8A6', 'income');
    await cat('Dividend', 'trending_up', '#FACC15', 'income');
    await cat('Investment', 'savings', '#FB923C', 'income');
    await cat('Interest', 'account_balance', '#4ADE80', 'income');
    await cat('Lottery', 'lottery', '#F04444', 'income');
    await cat('Salary', 'salary', '#EC4899', 'income');
    await cat('Tips', 'tips', '#A78BFA', 'income');
    await cat('Others', 'other', '#8B5CF6', 'income');

    // Expense (reference order).
    await cat('Bills', 'bills', '#38BDF8', 'expense');
    await cat('Clothing', 'clothing', '#3B82F6', 'expense');
    await cat('Education', 'education', '#2DD4BF', 'expense');
    await cat('Entertainment', 'entertainment', '#14B8A6', 'expense');
    await cat('Fitness', 'fitness', '#84CC16', 'expense');
    await cat('Food', 'food', '#FACC15', 'expense');
    await into(categories).insert(
      CategoriesCompanion.insert(
        name: 'Coffee',
        iconKey: const Value('coffee'),
        colorHex: const Value('#B45309'),
        kind: 'expense',
        parentId: Value(await _categoryIdByName('Food')),
      ),
    );
    await cat('Gifts', 'gift', '#FB923C', 'expense');
    await cat('Health', 'health', '#F04444', 'expense');
    await cat('Furniture', 'furniture', '#D946EF', 'expense');
    await cat('Pet', 'pets', '#8B5CF6', 'expense');
    await cat('Shopping', 'shopping', '#A78BFA', 'expense');
    await cat('Transportation', 'bus', '#EC4899', 'expense');
    await cat('Travel', 'travel', '#A16207', 'expense');
    await cat('Other', 'other', '#9CA3AF', 'expense');

    // Hidden category used by wallet-to-wallet transfers (kind 'transfer').
    await into(categories).insert(
      CategoriesCompanion.insert(
        name: 'Transfer',
        iconKey: const Value('swap_horiz'),
        colorHex: const Value('#9CA3AF'),
        kind: 'transfer',
      ),
    );
  }
}

QueryExecutor _openConnection() => driftDatabase(name: 'money_manager');
