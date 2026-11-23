import '../../data/database/app_database.dart';
import '../utils/sync_payload.dart';

/// Outcome of serialising one outbox entry.
///
/// [payload] is null when the row cannot be pushed: [rowGone] means
/// the row no longer exists locally (a stale entry — safe to ack);
/// otherwise a foreign key the row needs cannot be resolved (the
/// referenced row is gone — keep the entry queued, a later pull may
/// restore it).
typedef SerialiseOutcome = ({
  Map<String, dynamic>? payload,
  int? accountId,
  bool rowGone,
});

/// Everything the serialiser needs to resolve local integer foreign
/// keys into the sync ids the server stores, loaded once per push
/// run. Small tables only — transactions are resolved lazily (only a
/// transfer-fee row references another transaction).
class SyncReferenceMaps {
  const SyncReferenceMaps({
    required this.accountSyncIds,
    required this.walletSyncIds,
    required this.walletAccounts,
    required this.categorySyncIds,
    required this.goalSyncIds,
    required this.debtSyncIds,
    required this.debtWallets,
    required this.debtPaymentSyncIds,
    required this.debtPaymentWallets,
    required this.debtPaymentDebts,
    required this.recurringSyncIds,
    required this.planSyncIds,
  });

  static Future<SyncReferenceMaps> load(AppDatabase db) async {
    final accounts = await db.select(db.accounts).get();
    final wallets = await db.select(db.wallets).get();
    final categories = await db.select(db.categories).get();
    final goals = await db.select(db.goals).get();
    final debts = await db.select(db.debts).get();
    final debtPayments = await db.select(db.debtPayments).get();
    final recurring =
        await db.select(db.recurringTransactions).get();
    final plans = await db.select(db.installmentPlans).get();
    return SyncReferenceMaps(
      accountSyncIds: {for (final a in accounts) a.id: a.syncId},
      walletSyncIds: {for (final w in wallets) w.id: w.syncId},
      walletAccounts: {for (final w in wallets) w.id: w.accountId},
      categorySyncIds: {for (final c in categories) c.id: c.syncId},
      goalSyncIds: {for (final g in goals) g.id: g.syncId},
      debtSyncIds: {for (final d in debts) d.id: d.syncId},
      debtWallets: {
        for (final d in debts)
          if (d.walletId != null) d.id: d.walletId!,
      },
      debtPaymentSyncIds: {for (final p in debtPayments) p.id: p.syncId},
      debtPaymentWallets: {
        for (final p in debtPayments)
          if (p.walletId != null) p.id: p.walletId!,
      },
      debtPaymentDebts: {for (final p in debtPayments) p.id: p.debtId},
      recurringSyncIds: {for (final r in recurring) r.id: r.syncId},
      planSyncIds: {for (final p in plans) p.id: p.syncId},
    );
  }

  final Map<int, String> accountSyncIds;
  final Map<int, String> walletSyncIds;

  /// Wallet local id → owning account local id.
  final Map<int, int> walletAccounts;
  final Map<int, String> categorySyncIds;
  final Map<int, String> goalSyncIds;
  final Map<int, String> debtSyncIds;

  /// Debt local id → its wallet local id (debts with no wallet are
  /// absent — they have no account link and always sync).
  final Map<int, int> debtWallets;
  final Map<int, String> debtPaymentSyncIds;
  final Map<int, int> debtPaymentWallets;
  final Map<int, int> debtPaymentDebts;
  final Map<int, String> recurringSyncIds;
  final Map<int, String> planSyncIds;
}

/// Turns local rows into the server's snake_case payloads (mirror
/// `supabase/migrations/0001_init.sql` exactly — including
/// `budgets."limit"`, a reserved word in Postgres that travels as a
/// plain JSON key). Foreign keys become the referenced row's sync id,
/// never the local int id; `owner_id` is the Supabase Auth user.
///
/// The owning account (for the per-account toggle, idea #3) resolves
/// per table — enforcement is at push time, not capture:
///
/// | table | owning account |
/// |---|---|---|
/// | accounts | the account itself |
/// | wallets | `accountId` |
/// | transactions, installment_plans, recurring_transactions, transaction_templates | via `walletId` → account |
/// | debts | via `walletId` → account (no wallet → always sync) |
/// | debt_payments | via `walletId`, else via `debtId` → debt's wallet (neither → always sync) |
/// | budgets | none — budgets have no `accountId` column, locally or on the server — always sync |
/// | categories, goals, goal_deposits, category_keywords | none — always sync |
/// | transaction_photos | via the transaction → wallet (P4) |
///
/// A null `accountId` in the outcome means "no account link — always
/// sync".
class SyncSerialiser {
  SyncSerialiser({
    required this.db,
    required this.maps,
    required this.ownerId,
  });

  final AppDatabase db;
  final SyncReferenceMaps maps;
  final String ownerId;

  Future<SerialiseOutcome> serialise(String table, String syncId) async {
    switch (table) {
      case 'accounts':
        return _serialiseAccount(syncId);
      case 'categories':
        return _serialiseCategory(syncId);
      case 'goals':
        return _serialiseGoal(syncId);
      case 'wallets':
        return _serialiseWallet(syncId);
      case 'installment_plans':
        return _serialisePlan(syncId);
      case 'debts':
        return _serialiseDebt(syncId);
      case 'debt_payments':
        return _serialiseDebtPayment(syncId);
      case 'goal_deposits':
        return _serialiseGoalDeposit(syncId);
      case 'recurring_transactions':
        return _serialiseRecurring(syncId);
      case 'transactions':
        return _serialiseTransaction(syncId);
      case 'budgets':
        return _serialiseBudget(syncId);
      case 'transaction_templates':
        return _serialiseTemplate(syncId);
      case 'category_keywords':
        return _serialiseKeyword(syncId);
      case 'transaction_photos':
        return _serialisePhoto(syncId);
      default:
        // Anything unknown: not serialisable.
        return (payload: null, accountId: null, rowGone: false);
    }
  }

  SerialiseOutcome _ready(Map<String, dynamic> payload, int? accountId) =>
      (payload: payload, accountId: accountId, rowGone: false);

  SerialiseOutcome _gone() =>
      (payload: null, accountId: null, rowGone: true);

  SerialiseOutcome _unresolved() =>
      (payload: null, accountId: null, rowGone: false);

  /// Base columns every server row carries.
  Map<String, dynamic> _base(String syncId, DateTime? deletedAt) => {
    'sync_id': syncId,
    'owner_id': ownerId,
    'deleted_at': isoUtc(deletedAt),
  };

  Future<SerialiseOutcome> _serialiseAccount(String syncId) async {
    final row = await (db.select(
      db.accounts,
    )..where((a) => a.syncId.equals(syncId))).getSingleOrNull();
    if (row == null) return _gone();
    return _ready({
      ..._base(row.syncId, row.deletedAt),
      'name': row.name,
      'kind': row.kind,
      'color_hex': row.colorHex,
    }, row.id);
  }

  Future<SerialiseOutcome> _serialiseCategory(String syncId) async {
    final row = await (db.select(
      db.categories,
    )..where((c) => c.syncId.equals(syncId))).getSingleOrNull();
    if (row == null) return _gone();
    final parentSyncId = row.parentId == null
        ? null
        : maps.categorySyncIds[row.parentId];
    if (row.parentId != null && parentSyncId == null) {
      return _unresolved();
    }
    return _ready({
      ..._base(row.syncId, row.deletedAt),
      'name': row.name,
      'icon_key': row.iconKey,
      'color_hex': row.colorHex,
      'kind': row.kind,
      'parent_id': parentSyncId,
      'sort_order': row.sortOrder,
    }, null);
  }

  Future<SerialiseOutcome> _serialiseGoal(String syncId) async {
    final row = await (db.select(
      db.goals,
    )..where((g) => g.syncId.equals(syncId))).getSingleOrNull();
    if (row == null) return _gone();
    return _ready({
      ..._base(row.syncId, row.deletedAt),
      'name': row.name,
      'target': row.target,
      // Derived locally after pull (concept §7); mirrored for
      // schema completeness, never applied by the client.
      'saved': row.saved,
      'color_hex': row.colorHex,
      'deadline': isoUtc(row.deadline),
    }, null);
  }

  Future<SerialiseOutcome> _serialiseWallet(String syncId) async {
    final row = await (db.select(
      db.wallets,
    )..where((w) => w.syncId.equals(syncId))).getSingleOrNull();
    if (row == null) return _gone();
    final accountSyncId = maps.accountSyncIds[row.accountId];
    if (accountSyncId == null) return _unresolved();
    return _ready({
      ..._base(row.syncId, row.deletedAt),
      'account_id': accountSyncId,
      'name': row.name,
      'kind': row.kind,
      // Derived locally after pull (concept §7); mirrored for
      // schema completeness, never applied by the client.
      'balance': row.balance,
      'initial_amount': row.initialAmount,
      'color_hex': row.colorHex,
      'logo_template': row.logoTemplate,
      'sort_order': row.sortOrder,
      'credit_limit': row.creditLimit,
      'statement_day': row.statementDay,
      'due_day': row.dueDay,
      'interest_rate_monthly': row.interestRateMonthly,
      'interest_rate_annual': row.interestRateAnnual,
    }, row.accountId);
  }

  Future<SerialiseOutcome> _serialisePlan(String syncId) async {
    final row = await (db.select(
      db.installmentPlans,
    )..where((p) => p.syncId.equals(syncId))).getSingleOrNull();
    if (row == null) return _gone();
    final walletSyncId = maps.walletSyncIds[row.walletId];
    if (walletSyncId == null) return _unresolved();
    return _ready({
      ..._base(row.syncId, row.deletedAt),
      'wallet_id': walletSyncId,
      'name': row.name,
      'total_amount': row.totalAmount,
      'installment_amount': row.installmentAmount,
      'total_count': row.totalCount,
      // Derived locally after pull (concept §7); mirrored for
      // schema completeness, never applied by the client.
      'paid_count': row.paidCount,
      'created_at': isoUtc(row.createdAt),
    }, maps.walletAccounts[row.walletId]);
  }

  Future<SerialiseOutcome> _serialiseDebt(String syncId) async {
    final row = await (db.select(
      db.debts,
    )..where((d) => d.syncId.equals(syncId))).getSingleOrNull();
    if (row == null) return _gone();
    final walletSyncId = row.walletId == null
        ? null
        : maps.walletSyncIds[row.walletId];
    if (row.walletId != null && walletSyncId == null) {
      return _unresolved();
    }
    return _ready({
      ..._base(row.syncId, row.deletedAt),
      'person': row.person,
      'note': row.note,
      'amount': row.amount,
      'direction': row.direction,
      'is_paid': row.isPaid,
      'due_date': isoUtc(row.dueDate),
      'color_hex': row.colorHex,
      'wallet_id': walletSyncId,
      'created_at': isoUtc(row.createdAt),
      'record_as_transaction': row.recordAsTransaction,
    }, row.walletId == null ? null : maps.walletAccounts[row.walletId]);
  }

  Future<SerialiseOutcome> _serialiseDebtPayment(String syncId) async {
    final row = await (db.select(
      db.debtPayments,
    )..where((p) => p.syncId.equals(syncId))).getSingleOrNull();
    if (row == null) return _gone();
    final debtSyncId = maps.debtSyncIds[row.debtId];
    if (debtSyncId == null) return _unresolved();
    final walletSyncId = row.walletId == null
        ? null
        : maps.walletSyncIds[row.walletId];
    if (row.walletId != null && walletSyncId == null) {
      return _unresolved();
    }
    final walletId = row.walletId ?? maps.debtWallets[row.debtId];
    return _ready({
      ..._base(row.syncId, row.deletedAt),
      'debt_id': debtSyncId,
      'amount': row.amount,
      'date': isoUtc(row.date),
      'note': row.note,
      'wallet_id': walletSyncId,
    }, walletId == null ? null : maps.walletAccounts[walletId]);
  }

  Future<SerialiseOutcome> _serialiseGoalDeposit(String syncId) async {
    final row = await (db.select(
      db.goalDeposits,
    )..where((d) => d.syncId.equals(syncId))).getSingleOrNull();
    if (row == null) return _gone();
    final goalSyncId = maps.goalSyncIds[row.goalId];
    if (goalSyncId == null) return _unresolved();
    return _ready({
      ..._base(row.syncId, row.deletedAt),
      'goal_id': goalSyncId,
      'amount': row.amount,
      'date': isoUtc(row.date),
      'note': row.note,
    }, null);
  }

  Future<SerialiseOutcome> _serialiseRecurring(String syncId) async {
    final row = await (db.select(
      db.recurringTransactions,
    )..where((r) => r.syncId.equals(syncId))).getSingleOrNull();
    if (row == null) return _gone();
    final walletSyncId = maps.walletSyncIds[row.walletId];
    final categorySyncId = maps.categorySyncIds[row.categoryId];
    if (walletSyncId == null || categorySyncId == null) {
      return _unresolved();
    }
    return _ready({
      ..._base(row.syncId, row.deletedAt),
      'wallet_id': walletSyncId,
      'category_id': categorySyncId,
      'kind': row.kind,
      'amount': row.amount,
      'note': row.note,
      'frequency': row.frequency,
      'next_due': isoUtc(row.nextDue),
      'end_date': isoUtc(row.endDate),
      'active': row.active,
    }, maps.walletAccounts[row.walletId]);
  }

  Future<SerialiseOutcome> _serialiseTransaction(String syncId) async {
    final row = await (db.select(
      db.transactions,
    )..where((t) => t.syncId.equals(syncId))).getSingleOrNull();
    if (row == null) return _gone();
    final walletSyncId = maps.walletSyncIds[row.walletId];
    final categorySyncId = maps.categorySyncIds[row.categoryId];
    if (walletSyncId == null || categorySyncId == null) {
      return _unresolved();
    }
    final toWalletSyncId = row.toWalletId == null
        ? null
        : maps.walletSyncIds[row.toWalletId];
    if (row.toWalletId != null && toWalletSyncId == null) {
      return _unresolved();
    }
    final debtSyncId = row.debtId == null
        ? null
        : maps.debtSyncIds[row.debtId];
    if (row.debtId != null && debtSyncId == null) return _unresolved();
    final debtPaymentSyncId = row.debtPaymentId == null
        ? null
        : maps.debtPaymentSyncIds[row.debtPaymentId];
    if (row.debtPaymentId != null && debtPaymentSyncId == null) {
      return _unresolved();
    }
    final recurringSyncId = row.recurringId == null
        ? null
        : maps.recurringSyncIds[row.recurringId];
    if (row.recurringId != null && recurringSyncId == null) {
      return _unresolved();
    }
    final planSyncId = row.planId == null
        ? null
        : maps.planSyncIds[row.planId];
    if (row.planId != null && planSyncId == null) return _unresolved();
    // A transfer-fee row points at its transfer. Fee rows are rare,
    // so resolve the transfer's sync id with a targeted query
    // instead of loading every transaction's map up front.
    String? transferSyncId;
    if (row.transferId != null) {
      final transfer = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(row.transferId!))).getSingleOrNull();
      if (transfer == null) return _unresolved();
      transferSyncId = transfer.syncId;
    }
    return _ready({
      ..._base(row.syncId, row.deletedAt),
      'wallet_id': walletSyncId,
      'category_id': categorySyncId,
      'kind': row.kind,
      'amount': row.amount,
      'note': row.note,
      'memo': row.memo,
      'date': isoUtc(row.date),
      'created_at': isoUtc(row.createdAt),
      'to_wallet_id': toWalletSyncId,
      'debt_id': debtSyncId,
      'debt_payment_id': debtPaymentSyncId,
      'recurring_id': recurringSyncId,
      'transfer_id': transferSyncId,
      'plan_id': planSyncId,
    }, maps.walletAccounts[row.walletId]);
  }

  Future<SerialiseOutcome> _serialiseBudget(String syncId) async {
    final row = await (db.select(
      db.budgets,
    )..where((b) => b.syncId.equals(syncId))).getSingleOrNull();
    if (row == null) return _gone();
    final categorySyncId = maps.categorySyncIds[row.categoryId];
    if (categorySyncId == null) return _unresolved();
    return _ready({
      ..._base(row.syncId, row.deletedAt),
      'category_id': categorySyncId,
      'month': row.month,
      // `limit` is a reserved word in Postgres — it travels as a
      // plain JSON key and the server quotes it; the local column
      // is named the same way for the same reason.
      'limit': row.limit,
    }, null);
  }

  Future<SerialiseOutcome> _serialiseTemplate(String syncId) async {
    final row = await (db.select(
      db.transactionTemplates,
    )..where((t) => t.syncId.equals(syncId))).getSingleOrNull();
    if (row == null) return _gone();
    final walletSyncId = maps.walletSyncIds[row.walletId];
    final categorySyncId = maps.categorySyncIds[row.categoryId];
    if (walletSyncId == null || categorySyncId == null) {
      return _unresolved();
    }
    return _ready({
      ..._base(row.syncId, row.deletedAt),
      'name': row.name,
      'wallet_id': walletSyncId,
      'category_id': categorySyncId,
      'kind': row.kind,
      'amount': row.amount,
      'note': row.note,
      'use_count': row.useCount,
    }, maps.walletAccounts[row.walletId]);
  }

  Future<SerialiseOutcome> _serialiseKeyword(String syncId) async {
    final row = await (db.select(
      db.categoryKeywords,
    )..where((k) => k.syncId.equals(syncId))).getSingleOrNull();
    if (row == null) return _gone();
    final categorySyncId = maps.categorySyncIds[row.categoryId];
    if (categorySyncId == null) return _unresolved();
    return _ready({
      ..._base(row.syncId, row.deletedAt),
      'keyword': row.keyword,
      'category_id': categorySyncId,
      'hits': row.hits,
    }, null);
  }

  Future<SerialiseOutcome> _serialisePhoto(String syncId) async {
    final row = await (db.select(
      db.transactionPhotos,
    )..where((p) => p.syncId.equals(syncId))).getSingleOrNull();
    if (row == null) return _gone();
    // The bytes must be in Storage before the row can reference
    // them: the push uploads first (see SyncPushService), so a
    // missing key here means the upload was deferred (off Wi-Fi)
    // or failed — stay queued, never upsert a row pointing at
    // bytes that are not there.
    final key = row.remoteKey;
    if (key == null) return _unresolved();
    // Photos resolve via transaction → wallet. Transactions are
    // not preloaded in the maps, so one targeted query (the same
    // pattern as a transfer-fee row's transfer lookup).
    final tx = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(row.transactionId))).getSingleOrNull();
    if (tx == null) return _unresolved();
    return _ready({
      ..._base(row.syncId, row.deletedAt),
      'transaction_id': tx.syncId,
      'path': key,
    }, maps.walletAccounts[tx.walletId]);
  }
}
