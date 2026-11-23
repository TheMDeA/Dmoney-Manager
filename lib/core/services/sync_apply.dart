import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/database/app_database.dart';

/// Thrown by [SyncRowApplier] when a row's foreign key cannot be
/// resolved to a local row — the referenced row is gone or has not
/// arrived yet. The caller skips the row: the pull cursor holds it
/// back, so a later pull retries it once the parent lands.
class SyncUnresolvedException implements Exception {
  SyncUnresolvedException(this.table, this.syncId, this.missing);

  /// The table of the row that could not be applied.
  final String table;

  /// The row's sync id.
  final String syncId;

  /// Which reference is missing, e.g. `'wallet'`.
  final String missing;

  @override
  String toString() =>
      'SyncUnresolvedException: $table/$syncId needs a missing $missing';
}

/// Reverse lookup for pull: sync id → local int id, per table,
/// plus the two side maps the per-account toggle needs (wallet →
/// account, debt → wallet). Loaded once per pull run from the
/// local tables; rows applied mid-pull are added as they land,
/// and a targeted query covers anything the snapshot missed
/// (a parent applied earlier in the same page).
///
/// Transactions are not preloaded — only a transfer-fee row
/// references another transaction, and those are rare — so a
/// transfer id always resolves through the targeted query.
/// Category keywords have no integer id, so they are absent here;
/// nothing references them.
class PullReferenceMaps {
  PullReferenceMaps._({
    required Map<String, Map<String, int>> ids,
    required Map<int, int> walletAccounts,
    required Map<int, int> debtWallets,
    required this.db,
  }) : _ids = ids,
       _walletAccounts = walletAccounts,
       _debtWallets = debtWallets;

  static Future<PullReferenceMaps> load(AppDatabase db) async {
    final accounts = await db.select(db.accounts).get();
    final wallets = await db.select(db.wallets).get();
    final categories = await db.select(db.categories).get();
    final goals = await db.select(db.goals).get();
    final plans = await db.select(db.installmentPlans).get();
    final debts = await db.select(db.debts).get();
    final debtPayments = await db.select(db.debtPayments).get();
    final goalDeposits = await db.select(db.goalDeposits).get();
    final recurring = await db.select(db.recurringTransactions).get();
    final templates = await db.select(db.transactionTemplates).get();
    final budgets = await db.select(db.budgets).get();
    return PullReferenceMaps._(
      ids: {
        'accounts': {for (final r in accounts) r.syncId: r.id},
        'wallets': {for (final r in wallets) r.syncId: r.id},
        'categories': {for (final r in categories) r.syncId: r.id},
        'goals': {for (final r in goals) r.syncId: r.id},
        'installment_plans': {for (final r in plans) r.syncId: r.id},
        'debts': {for (final r in debts) r.syncId: r.id},
        'debt_payments': {for (final r in debtPayments) r.syncId: r.id},
        'goal_deposits': {for (final r in goalDeposits) r.syncId: r.id},
        'recurring_transactions': {
          for (final r in recurring) r.syncId: r.id,
        },
        'transaction_templates': {
          for (final r in templates) r.syncId: r.id,
        },
        'budgets': {for (final r in budgets) r.syncId: r.id},
        'transactions': <String, int>{},
        'transaction_photos': <String, int>{},
        'category_keywords': <String, int>{},
      },
      walletAccounts: {for (final w in wallets) w.id: w.accountId},
      debtWallets: {
        for (final d in debts)
          if (d.walletId != null) d.id: d.walletId!,
      },
      db: db,
    );
  }

  final AppDatabase db;
  final Map<String, Map<String, int>> _ids;

  /// Local wallet id → owning local account id.
  final Map<int, int> _walletAccounts;

  /// Local debt id → its wallet local id (debts with no wallet
  /// are absent — they have no account link and always sync).
  final Map<int, int> _debtWallets;

  /// Local id for [syncId] in [table], or null when no local row
  /// carries it. Falls back to a targeted query when the
  /// snapshot misses — a parent applied earlier in the same
  /// pull, or a transaction (never preloaded).
  Future<int?> resolve(String table, String syncId) async {
    final cached = _ids[table]?[syncId];
    if (cached != null) return cached;
    if (table == 'category_keywords') return null;
    final rows = await db.customSelect(
      'SELECT id FROM "$table" WHERE sync_id = ?',
      variables: [Variable.withString(syncId)],
      readsFrom: {},
    ).get();
    if (rows.isEmpty) return null;
    final id = rows.single.read<int>('id');
    _ids[table]?[syncId] = id;
    return id;
  }

  /// Records a row applied mid-pull, so later rows in the same
  /// pull resolve it without a query. For wallets pass the
  /// account id, for debts the wallet id, to keep the side maps
  /// fresh when a pulled update re-points the row.
  void add(
    String table,
    String syncId,
    int localId, {
    int? accountId,
    int? walletId,
  }) {
    _ids[table]?[syncId] = localId;
    if (table == 'wallets' && accountId != null) {
      _walletAccounts[localId] = accountId;
    }
    if (table == 'debts' && walletId != null) {
      _debtWallets[localId] = walletId;
    }
  }

  /// Forgets a row deleted mid-pull (tombstone applied), so a
  /// later row in the same pull cannot resolve to it.
  void remove(String table, String syncId) {
    final localId = _ids[table]?.remove(syncId);
    if (localId == null) return;
    if (table == 'wallets') _walletAccounts.remove(localId);
    if (table == 'debts') _debtWallets.remove(localId);
  }

  /// Owning local account id for a wallet sync id, or null when
  /// the wallet has not arrived yet.
  Future<int?> walletAccountId(String walletSyncId) async {
    final walletId = await resolve('wallets', walletSyncId);
    if (walletId == null) return null;
    return _walletAccounts[walletId];
  }

  /// Owning local account id for a transaction sync id, or null
  /// when the transaction has not arrived yet. Photos resolve
  /// their account through their transaction's wallet (one
  /// targeted query — transactions are never preloaded).
  Future<int?> accountIdForTransaction(String txSyncId) async {
    final rows = await db.customSelect(
      'SELECT wallet_id FROM transactions WHERE sync_id = ?',
      variables: [Variable.withString(txSyncId)],
      readsFrom: {},
    ).get();
    if (rows.isEmpty) return null;
    return _walletAccounts[rows.single.read<int>('wallet_id')];
  }

  /// Local wallet id for a debt sync id, or null when the debt
  /// has no wallet or has not arrived yet.
  Future<int?> walletIdForDebt(String debtSyncId) async {
    final debtId = await resolve('debts', debtSyncId);
    if (debtId == null) return null;
    return _debtWallets[debtId];
  }

  /// Owning local account id for a local wallet id.
  int? accountIdForWalletId(int walletId) => _walletAccounts[walletId];
}

/// The owning LOCAL account id for an incoming server row, or null
/// when the row has no account link and always syncs. Mirrors the
/// push-side resolution table in `SyncSerialiser`'s doc comment:
///
/// | table | owning account |
/// |---|---|---|
/// | accounts | the account itself (a brand-new account has no
/// | | local id yet and cannot have been toggled off — sync it) |
/// | wallets | `account_id` |
/// | transactions, installment_plans, recurring_transactions,
/// | transaction_templates | via `wallet_id` → account |
/// | debts | via `wallet_id` → account (no wallet → always sync) |
/// | debt_payments | via `wallet_id`, else via `debt_id` →
/// | | debt's wallet (neither → always sync) |
/// | transaction_photos | via `transaction_id` → wallet →
/// | | account |
/// | budgets, categories, goals, goal_deposits,
/// | category_keywords | none — always sync |
///
/// A null result ALSO covers "cannot determine right now" (the
/// owning wallet or account has not arrived yet). The caller then
/// treats the row as syncable and lets the apply fail on its
/// foreign key if the owner is truly missing — that holds the
/// cursor back instead of applying a row for an account that is
/// toggled off.
Future<int?> accountIdForIncomingRow(
  PullReferenceMaps maps,
  String table,
  Map<String, dynamic> row,
) async {
  switch (table) {
    case 'accounts':
      return maps.resolve('accounts', row['sync_id'] as String);
    case 'wallets':
      final accountSyncId = row['account_id'] as String?;
      if (accountSyncId == null) return null;
      return maps.resolve('accounts', accountSyncId);
    case 'transactions':
    case 'installment_plans':
    case 'recurring_transactions':
    case 'transaction_templates':
      final walletSyncId = row['wallet_id'] as String?;
      if (walletSyncId == null) return null;
      return maps.walletAccountId(walletSyncId);
    case 'debts':
      final walletSyncId = row['wallet_id'] as String?;
      if (walletSyncId == null) return null;
      return maps.walletAccountId(walletSyncId);
    case 'debt_payments':
      final walletSyncId = row['wallet_id'] as String?;
      if (walletSyncId != null) {
        return maps.walletAccountId(walletSyncId);
      }
      final debtSyncId = row['debt_id'] as String?;
      if (debtSyncId == null) return null;
      final walletId = await maps.walletIdForDebt(debtSyncId);
      if (walletId == null) return null;
      return maps.accountIdForWalletId(walletId);
    case 'transaction_photos':
      final txSyncId = row['transaction_id'] as String?;
      if (txSyncId == null) return null;
      return maps.accountIdForTransaction(txSyncId);
    default:
      return null;
  }
}

/// Orders one fetched page so rows whose self-reference is null
/// come first: a transfer-fee row must not land before its
/// transfer, a sub-category before its parent. Stable within
/// each group, so the server's (`server_updated_at`, `sync_id`)
/// order is kept otherwise.
List<Map<String, dynamic>> orderPageForApply(
  String table,
  List<Map<String, dynamic>> page,
) {
  final selfKey = switch (table) {
    'transactions' => 'transfer_id',
    'categories' => 'parent_id',
    _ => null,
  };
  if (selfKey == null) return page;
  final first = <Map<String, dynamic>>[];
  final rest = <Map<String, dynamic>>[];
  for (final row in page) {
    (row[selfKey] == null ? first : rest).add(row);
  }
  return [...first, ...rest];
}

// ---------------------------------------------------------------------------
// Row values (PostgREST decodes JSON: ints stay ints, doubles stay
// doubles, timestamptz arrives as an ISO-8601 string).
// ---------------------------------------------------------------------------

String _s(Map<String, dynamic> row, String key) => row[key] as String;

String? _sOrNull(Map<String, dynamic> row, String key) =>
    row[key] as String?;

int _i(Map<String, dynamic> row, String key) => (row[key] as num).toInt();

int? _iOrNull(Map<String, dynamic> row, String key) {
  final v = row[key];
  return v == null ? null : (v as num).toInt();
}

double? _dOrNull(Map<String, dynamic> row, String key) {
  final v = row[key];
  return v == null ? null : (v as num).toDouble();
}

bool _b(Map<String, dynamic> row, String key) => row[key] as bool;

DateTime _dt(Map<String, dynamic> row, String key) =>
    DateTime.parse(row[key] as String);

DateTime? _dtOrNull(Map<String, dynamic> row, String key) {
  final v = row[key];
  return v == null ? null : DateTime.parse(v as String);
}

/// Applies server rows to the local tables (P3 pull, and the
/// conflict keeper's Restore). One method per table, mirroring
/// the serialiser's per-table shape in reverse: foreign keys
/// arrive as sync ids and resolve through [PullReferenceMaps];
/// a missing reference throws [SyncUnresolvedException] and the
/// caller skips the row.
///
/// Derived columns (`wallets.balance`,
/// `installment_plans.paid_count`, `goals.saved`) are NEVER taken
/// from the server — the pull's derived-state reconcile
/// recomputes them after the apply. `updatedAt` is left alone: a
/// pull is not a local modification, so it must not look like
/// one. Nothing here touches the outbox — pulled rows are already
/// on the server, and Restore enqueues its own entry.
class SyncRowApplier {
  SyncRowApplier(this.db);

  final AppDatabase db;

  /// Applies one server row (a non-tombstone payload): inserts it
  /// when no local row carries the sync id, else updates the
  /// local row in place (keeping the local int id). Returns true
  /// when the row was inserted, false when updated. Throws
  /// [SyncUnresolvedException] when a foreign key cannot be
  /// resolved.
  Future<bool> applyServerRow(
    String table,
    Map<String, dynamic> row,
    PullReferenceMaps maps,
  ) async {
    switch (table) {
      case 'accounts':
        return _applyAccount(row, maps);
      case 'categories':
        return _applyCategory(row, maps);
      case 'wallets':
        return _applyWallet(row, maps);
      case 'goals':
        return _applyGoal(row, maps);
      case 'installment_plans':
        return _applyPlan(row, maps);
      case 'debts':
        return _applyDebt(row, maps);
      case 'debt_payments':
        return _applyDebtPayment(row, maps);
      case 'goal_deposits':
        return _applyGoalDeposit(row, maps);
      case 'recurring_transactions':
        return _applyRecurring(row, maps);
      case 'transaction_templates':
        return _applyTemplate(row, maps);
      case 'budgets':
        return _applyBudget(row, maps);
      case 'transactions':
        return _applyTransaction(row, maps);
      case 'category_keywords':
        return _applyKeyword(row, maps);
      case 'transaction_photos':
        return _applyPhoto(row, maps);
      default:
        throw ArgumentError('unknown sync table $table');
    }
  }

  /// Deletes the local row with [syncId], if one exists. Returns
  /// true when a row was deleted.
  Future<bool> applyTombstone(
    String table,
    String syncId,
    PullReferenceMaps maps,
  ) async {
    if (table == 'category_keywords') {
      // No integer id: delete by sync id directly.
      final deleted =
          await (db.delete(
            db.categoryKeywords,
          )..where((k) => k.syncId.equals(syncId))).go();
      return deleted > 0;
    }
    if (table == 'transaction_photos') {
      // The downloaded file goes with the row (best-effort, and
      // only inside our own receipts folder — the same safety
      // rule as AppDatabase.deletePhoto). The Storage object is
      // removed by the pull service, which has the key in hand.
      final existing = await (db.select(
        db.transactionPhotos,
      )..where((p) => p.syncId.equals(syncId))).getSingleOrNull();
      if (existing == null) return false;
      await (db.delete(
        db.transactionPhotos,
      )..where((p) => p.id.equals(existing.id))).go();
      maps.remove(table, syncId);
      await _deleteLocalPhotoFile(existing.path);
      return true;
    }
    final localId = await maps.resolve(table, syncId);
    if (localId == null) return false;
    if (!await _deleteById(table, localId)) return false;
    maps.remove(table, syncId);
    return true;
  }

  Future<bool> _deleteById(String table, int localId) async {
    final count = await switch (table) {
      'accounts' =>
        (db.delete(db.accounts)..where((r) => r.id.equals(localId))).go(),
      'categories' =>
        (db.delete(db.categories)..where((r) => r.id.equals(localId))).go(),
      'wallets' =>
        (db.delete(db.wallets)..where((r) => r.id.equals(localId))).go(),
      'goals' =>
        (db.delete(db.goals)..where((r) => r.id.equals(localId))).go(),
      'installment_plans' =>
        (db.delete(
          db.installmentPlans,
        )..where((r) => r.id.equals(localId))).go(),
      'debts' =>
        (db.delete(db.debts)..where((r) => r.id.equals(localId))).go(),
      'debt_payments' =>
        (db.delete(db.debtPayments)..where((r) => r.id.equals(localId)))
            .go(),
      'goal_deposits' =>
        (db.delete(db.goalDeposits)..where((r) => r.id.equals(localId)))
            .go(),
      'recurring_transactions' =>
        (db.delete(
          db.recurringTransactions,
        )..where((r) => r.id.equals(localId))).go(),
      'transaction_templates' =>
        (db.delete(
          db.transactionTemplates,
        )..where((r) => r.id.equals(localId))).go(),
      'budgets' =>
        (db.delete(db.budgets)..where((r) => r.id.equals(localId))).go(),
      'transactions' =>
        (db.delete(db.transactions)..where((r) => r.id.equals(localId)))
            .go(),
      _ => throw ArgumentError('unknown sync table $table'),
    };
    return count > 0;
  }

  Future<bool> _applyAccount(
    Map<String, dynamic> row,
    PullReferenceMaps maps,
  ) async {
    final syncId = _s(row, 'sync_id');
    final existingId = await maps.resolve('accounts', syncId);
    final companion = AccountsCompanion(
      name: Value(_s(row, 'name')),
      kind: Value(_s(row, 'kind')),
      colorHex: Value(_s(row, 'color_hex')),
    );
    if (existingId == null) {
      final id = await db.into(db.accounts).insert(
        companion.copyWith(syncId: Value(syncId)),
      );
      maps.add('accounts', syncId, id);
      return true;
    }
    await (db.update(
      db.accounts,
    )..where((a) => a.id.equals(existingId))).write(companion);
    return false;
  }

  Future<bool> _applyCategory(
    Map<String, dynamic> row,
    PullReferenceMaps maps,
  ) async {
    final syncId = _s(row, 'sync_id');
    final parentSyncId = _sOrNull(row, 'parent_id');
    int? parentId;
    if (parentSyncId != null) {
      parentId = await maps.resolve('categories', parentSyncId);
      if (parentId == null) {
        throw SyncUnresolvedException('categories', syncId, 'category');
      }
    }
    final existingId = await maps.resolve('categories', syncId);
    final companion = CategoriesCompanion(
      name: Value(_s(row, 'name')),
      iconKey: Value(_s(row, 'icon_key')),
      colorHex: Value(_s(row, 'color_hex')),
      kind: Value(_s(row, 'kind')),
      parentId: Value(parentId),
      sortOrder: Value(_i(row, 'sort_order')),
    );
    if (existingId == null) {
      final id = await db.into(db.categories).insert(
        companion.copyWith(syncId: Value(syncId)),
      );
      maps.add('categories', syncId, id);
      return true;
    }
    await (db.update(
      db.categories,
    )..where((c) => c.id.equals(existingId))).write(companion);
    return false;
  }

  Future<bool> _applyWallet(
    Map<String, dynamic> row,
    PullReferenceMaps maps,
  ) async {
    final syncId = _s(row, 'sync_id');
    final accountId = await maps.resolve(
      'accounts',
      _s(row, 'account_id'),
    );
    if (accountId == null) {
      throw SyncUnresolvedException('wallets', syncId, 'account');
    }
    final existingId = await maps.resolve('wallets', syncId);
    final companion = WalletsCompanion(
      accountId: Value(accountId),
      name: Value(_s(row, 'name')),
      kind: Value(_s(row, 'kind')),
      // balance is derived — never applied (see class doc).
      initialAmount: Value(_i(row, 'initial_amount')),
      colorHex: Value(_s(row, 'color_hex')),
      logoTemplate: Value(_sOrNull(row, 'logo_template')),
      sortOrder: Value(_i(row, 'sort_order')),
      creditLimit: Value(_iOrNull(row, 'credit_limit')),
      statementDay: Value(_iOrNull(row, 'statement_day')),
      dueDay: Value(_iOrNull(row, 'due_day')),
      interestRateMonthly: Value(
        _dOrNull(row, 'interest_rate_monthly'),
      ),
      interestRateAnnual: Value(_dOrNull(row, 'interest_rate_annual')),
    );
    if (existingId == null) {
      final id = await db.into(db.wallets).insert(
        companion.copyWith(syncId: Value(syncId)),
      );
      maps.add('wallets', syncId, id, accountId: accountId);
      return true;
    }
    await (db.update(
      db.wallets,
    )..where((w) => w.id.equals(existingId))).write(companion);
    maps.add('wallets', syncId, existingId, accountId: accountId);
    return false;
  }

  Future<bool> _applyGoal(
    Map<String, dynamic> row,
    PullReferenceMaps maps,
  ) async {
    final syncId = _s(row, 'sync_id');
    final existingId = await maps.resolve('goals', syncId);
    final companion = GoalsCompanion(
      name: Value(_s(row, 'name')),
      target: Value(_i(row, 'target')),
      // saved is derived — never applied (see class doc).
      colorHex: Value(_s(row, 'color_hex')),
      deadline: Value(_dtOrNull(row, 'deadline')),
    );
    if (existingId == null) {
      final id = await db.into(db.goals).insert(
        companion.copyWith(syncId: Value(syncId)),
      );
      maps.add('goals', syncId, id);
      return true;
    }
    await (db.update(
      db.goals,
    )..where((g) => g.id.equals(existingId))).write(companion);
    return false;
  }

  Future<bool> _applyPlan(
    Map<String, dynamic> row,
    PullReferenceMaps maps,
  ) async {
    final syncId = _s(row, 'sync_id');
    final walletId = await maps.resolve('wallets', _s(row, 'wallet_id'));
    if (walletId == null) {
      throw SyncUnresolvedException('installment_plans', syncId, 'wallet');
    }
    final existingId = await maps.resolve('installment_plans', syncId);
    final companion = InstallmentPlansCompanion(
      walletId: Value(walletId),
      name: Value(_s(row, 'name')),
      totalAmount: Value(_i(row, 'total_amount')),
      installmentAmount: Value(_i(row, 'installment_amount')),
      totalCount: Value(_i(row, 'total_count')),
      // paid_count is derived — never applied (see class doc).
      createdAt: Value(_dt(row, 'created_at')),
    );
    if (existingId == null) {
      final id = await db.into(db.installmentPlans).insert(
        companion.copyWith(syncId: Value(syncId)),
      );
      maps.add('installment_plans', syncId, id);
      return true;
    }
    await (db.update(
      db.installmentPlans,
    )..where((p) => p.id.equals(existingId))).write(companion);
    return false;
  }

  Future<bool> _applyDebt(
    Map<String, dynamic> row,
    PullReferenceMaps maps,
  ) async {
    final syncId = _s(row, 'sync_id');
    final walletSyncId = _sOrNull(row, 'wallet_id');
    int? walletId;
    if (walletSyncId != null) {
      walletId = await maps.resolve('wallets', walletSyncId);
      if (walletId == null) {
        throw SyncUnresolvedException('debts', syncId, 'wallet');
      }
    }
    final existingId = await maps.resolve('debts', syncId);
    final companion = DebtsCompanion(
      person: Value(_s(row, 'person')),
      note: Value(_s(row, 'note')),
      amount: Value(_i(row, 'amount')),
      direction: Value(_s(row, 'direction')),
      // is_paid is derived from the debt_payments rows — never
      // applied (see class doc); the reconcile recomputes it.
      dueDate: Value(_dtOrNull(row, 'due_date')),
      colorHex: Value(_s(row, 'color_hex')),
      walletId: Value(walletId),
      createdAt: Value(_dt(row, 'created_at')),
      recordAsTransaction: Value(_b(row, 'record_as_transaction')),
    );
    if (existingId == null) {
      final id = await db.into(db.debts).insert(
        companion.copyWith(syncId: Value(syncId)),
      );
      maps.add('debts', syncId, id, walletId: walletId);
      return true;
    }
    await (db.update(
      db.debts,
    )..where((d) => d.id.equals(existingId))).write(companion);
    maps.add('debts', syncId, existingId, walletId: walletId);
    return false;
  }

  Future<bool> _applyDebtPayment(
    Map<String, dynamic> row,
    PullReferenceMaps maps,
  ) async {
    final syncId = _s(row, 'sync_id');
    final debtId = await maps.resolve('debts', _s(row, 'debt_id'));
    if (debtId == null) {
      throw SyncUnresolvedException('debt_payments', syncId, 'debt');
    }
    final walletSyncId = _sOrNull(row, 'wallet_id');
    int? walletId;
    if (walletSyncId != null) {
      walletId = await maps.resolve('wallets', walletSyncId);
      if (walletId == null) {
        throw SyncUnresolvedException('debt_payments', syncId, 'wallet');
      }
    }
    final existingId = await maps.resolve('debt_payments', syncId);
    final companion = DebtPaymentsCompanion(
      debtId: Value(debtId),
      amount: Value(_i(row, 'amount')),
      date: Value(_dt(row, 'date')),
      note: Value(_s(row, 'note')),
      walletId: Value(walletId),
    );
    if (existingId == null) {
      final id = await db.into(db.debtPayments).insert(
        companion.copyWith(syncId: Value(syncId)),
      );
      maps.add('debt_payments', syncId, id);
      return true;
    }
    await (db.update(
      db.debtPayments,
    )..where((p) => p.id.equals(existingId))).write(companion);
    return false;
  }

  Future<bool> _applyGoalDeposit(
    Map<String, dynamic> row,
    PullReferenceMaps maps,
  ) async {
    final syncId = _s(row, 'sync_id');
    final goalId = await maps.resolve('goals', _s(row, 'goal_id'));
    if (goalId == null) {
      throw SyncUnresolvedException('goal_deposits', syncId, 'goal');
    }
    final existingId = await maps.resolve('goal_deposits', syncId);
    final companion = GoalDepositsCompanion(
      goalId: Value(goalId),
      amount: Value(_i(row, 'amount')),
      date: Value(_dt(row, 'date')),
      note: Value(_s(row, 'note')),
    );
    if (existingId == null) {
      final id = await db.into(db.goalDeposits).insert(
        companion.copyWith(syncId: Value(syncId)),
      );
      maps.add('goal_deposits', syncId, id);
      return true;
    }
    await (db.update(
      db.goalDeposits,
    )..where((d) => d.id.equals(existingId))).write(companion);
    return false;
  }

  Future<bool> _applyRecurring(
    Map<String, dynamic> row,
    PullReferenceMaps maps,
  ) async {
    final syncId = _s(row, 'sync_id');
    final walletId = await maps.resolve('wallets', _s(row, 'wallet_id'));
    final categoryId = await maps.resolve(
      'categories',
      _s(row, 'category_id'),
    );
    if (walletId == null) {
      throw SyncUnresolvedException(
        'recurring_transactions',
        syncId,
        'wallet',
      );
    }
    if (categoryId == null) {
      throw SyncUnresolvedException(
        'recurring_transactions',
        syncId,
        'category',
      );
    }
    final existingId = await maps.resolve('recurring_transactions', syncId);
    final companion = RecurringTransactionsCompanion(
      walletId: Value(walletId),
      categoryId: Value(categoryId),
      kind: Value(_s(row, 'kind')),
      amount: Value(_i(row, 'amount')),
      note: Value(_s(row, 'note')),
      frequency: Value(_s(row, 'frequency')),
      nextDue: Value(_dt(row, 'next_due')),
      endDate: Value(_dtOrNull(row, 'end_date')),
      active: Value(_b(row, 'active')),
    );
    if (existingId == null) {
      final id = await db.into(db.recurringTransactions).insert(
        companion.copyWith(syncId: Value(syncId)),
      );
      maps.add('recurring_transactions', syncId, id);
      return true;
    }
    await (db.update(
      db.recurringTransactions,
    )..where((r) => r.id.equals(existingId))).write(companion);
    return false;
  }

  Future<bool> _applyTemplate(
    Map<String, dynamic> row,
    PullReferenceMaps maps,
  ) async {
    final syncId = _s(row, 'sync_id');
    final walletId = await maps.resolve('wallets', _s(row, 'wallet_id'));
    final categoryId = await maps.resolve(
      'categories',
      _s(row, 'category_id'),
    );
    if (walletId == null) {
      throw SyncUnresolvedException(
        'transaction_templates',
        syncId,
        'wallet',
      );
    }
    if (categoryId == null) {
      throw SyncUnresolvedException(
        'transaction_templates',
        syncId,
        'category',
      );
    }
    final existingId = await maps.resolve('transaction_templates', syncId);
    final companion = TransactionTemplatesCompanion(
      name: Value(_s(row, 'name')),
      walletId: Value(walletId),
      categoryId: Value(categoryId),
      kind: Value(_s(row, 'kind')),
      amount: Value(_i(row, 'amount')),
      note: Value(_s(row, 'note')),
      useCount: Value(_i(row, 'use_count')),
    );
    if (existingId == null) {
      final id = await db.into(db.transactionTemplates).insert(
        companion.copyWith(syncId: Value(syncId)),
      );
      maps.add('transaction_templates', syncId, id);
      return true;
    }
    await (db.update(
      db.transactionTemplates,
    )..where((t) => t.id.equals(existingId))).write(companion);
    return false;
  }

  Future<bool> _applyBudget(
    Map<String, dynamic> row,
    PullReferenceMaps maps,
  ) async {
    final syncId = _s(row, 'sync_id');
    final categoryId = await maps.resolve(
      'categories',
      _s(row, 'category_id'),
    );
    if (categoryId == null) {
      throw SyncUnresolvedException('budgets', syncId, 'category');
    }
    final existingId = await maps.resolve('budgets', syncId);
    final companion = BudgetsCompanion(
      categoryId: Value(categoryId),
      month: Value(_s(row, 'month')),
      limit: Value(_i(row, 'limit')),
    );
    if (existingId == null) {
      final id = await db.into(db.budgets).insert(
        companion.copyWith(syncId: Value(syncId)),
      );
      maps.add('budgets', syncId, id);
      return true;
    }
    await (db.update(
      db.budgets,
    )..where((b) => b.id.equals(existingId))).write(companion);
    return false;
  }

  Future<bool> _applyTransaction(
    Map<String, dynamic> row,
    PullReferenceMaps maps,
  ) async {
    final syncId = _s(row, 'sync_id');
    final walletId = await maps.resolve('wallets', _s(row, 'wallet_id'));
    final categoryId = await maps.resolve(
      'categories',
      _s(row, 'category_id'),
    );
    if (walletId == null) {
      throw SyncUnresolvedException('transactions', syncId, 'wallet');
    }
    if (categoryId == null) {
      throw SyncUnresolvedException('transactions', syncId, 'category');
    }
    final toWalletId = await _resolveOptional(
      maps,
      'wallets',
      _sOrNull(row, 'to_wallet_id'),
      'transactions',
      syncId,
      'wallet',
    );
    final debtId = await _resolveOptional(
      maps,
      'debts',
      _sOrNull(row, 'debt_id'),
      'transactions',
      syncId,
      'debt',
    );
    final debtPaymentId = await _resolveOptional(
      maps,
      'debt_payments',
      _sOrNull(row, 'debt_payment_id'),
      'transactions',
      syncId,
      'debt payment',
    );
    final recurringId = await _resolveOptional(
      maps,
      'recurring_transactions',
      _sOrNull(row, 'recurring_id'),
      'transactions',
      syncId,
      'recurring rule',
    );
    final transferId = await _resolveOptional(
      maps,
      'transactions',
      _sOrNull(row, 'transfer_id'),
      'transactions',
      syncId,
      'transaction',
    );
    final planId = await _resolveOptional(
      maps,
      'installment_plans',
      _sOrNull(row, 'plan_id'),
      'transactions',
      syncId,
      'installment plan',
    );
    final existingId = await maps.resolve('transactions', syncId);
    final companion = TransactionsCompanion(
      walletId: Value(walletId),
      categoryId: Value(categoryId),
      kind: Value(_s(row, 'kind')),
      amount: Value(_i(row, 'amount')),
      note: Value(_s(row, 'note')),
      memo: Value(_s(row, 'memo')),
      date: Value(_dt(row, 'date')),
      createdAt: Value(_dt(row, 'created_at')),
      toWalletId: Value(toWalletId),
      debtId: Value(debtId),
      debtPaymentId: Value(debtPaymentId),
      recurringId: Value(recurringId),
      transferId: Value(transferId),
      planId: Value(planId),
    );
    if (existingId == null) {
      final id = await db.into(db.transactions).insert(
        companion.copyWith(syncId: Value(syncId)),
      );
      maps.add('transactions', syncId, id);
      return true;
    }
    await (db.update(
      db.transactions,
    )..where((t) => t.id.equals(existingId))).write(companion);
    return false;
  }

  /// Resolves an optional foreign key: null stays null, a present
  /// sync id that does not resolve throws [SyncUnresolvedException].
  Future<int?> _resolveOptional(
    PullReferenceMaps maps,
    String refTable,
    String? refSyncId,
    String table,
    String syncId,
    String missing,
  ) async {
    if (refSyncId == null) return null;
    final id = await maps.resolve(refTable, refSyncId);
    if (id == null) {
      throw SyncUnresolvedException(table, syncId, missing);
    }
    return id;
  }

  Future<bool> _applyKeyword(
    Map<String, dynamic> row,
    PullReferenceMaps maps,
  ) async {
    final syncId = _s(row, 'sync_id');
    final categoryId = await maps.resolve(
      'categories',
      _s(row, 'category_id'),
    );
    if (categoryId == null) {
      throw SyncUnresolvedException('category_keywords', syncId, 'category');
    }
    // No integer id: the existing row is found by sync id, and
    // updated by its composite primary key (keyword, categoryId).
    final existing =
        await (db.select(
          db.categoryKeywords,
        )..where((k) => k.syncId.equals(syncId))).getSingleOrNull();
    final companion = CategoryKeywordsCompanion(
      keyword: Value(_s(row, 'keyword')),
      categoryId: Value(categoryId),
      hits: Value(_i(row, 'hits')),
    );
    if (existing == null) {
      await db.into(db.categoryKeywords).insert(
        companion.copyWith(syncId: Value(syncId)),
      );
      return true;
    }
    await (db.update(db.categoryKeywords)
          ..where((k) => k.keyword.equals(existing.keyword))
          ..where((k) => k.categoryId.equals(existing.categoryId)))
        .write(companion);
    return false;
  }

  Future<bool> _applyPhoto(
    Map<String, dynamic> row,
    PullReferenceMaps maps,
  ) async {
    final syncId = _s(row, 'sync_id');
    final txId = await maps.resolve(
      'transactions',
      _s(row, 'transaction_id'),
    );
    if (txId == null) {
      throw SyncUnresolvedException(
        'transaction_photos',
        syncId,
        'transaction',
      );
    }
    final existingId = await maps.resolve('transaction_photos', syncId);
    // The server `path` is the Storage object key — it becomes
    // the row's remote key. The local `path` is the destination
    // the bytes are downloaded to on demand (lazy, §9): the file
    // does not exist yet, and the viewer fetches it when opened.
    // On an update, keep the existing local path when its file
    // is still there — a photo this device pushed echoes back
    // on the next pull, and re-pointing it at the deterministic
    // destination would orphan the file it already has and force
    // a pointless re-download.
    final remoteKey = _s(row, 'path');
    String localPath;
    if (existingId != null) {
      final existing = await (db.select(
        db.transactionPhotos,
      )..where((p) => p.id.equals(existingId))).getSingleOrNull();
      final existingPath = existing?.path;
      localPath =
          (existingPath != null && await File(existingPath).exists())
          ? existingPath
          : await _localPhotoPath(syncId);
    } else {
      localPath = await _localPhotoPath(syncId);
    }
    final companion = TransactionPhotosCompanion(
      transactionId: Value(txId),
      path: Value(localPath),
      remoteKey: Value(remoteKey),
    );
    if (existingId == null) {
      final id = await db.into(db.transactionPhotos).insert(
        companion.copyWith(syncId: Value(syncId)),
      );
      maps.add('transaction_photos', syncId, id);
      return true;
    }
    await (db.update(
      db.transactionPhotos,
    )..where((p) => p.id.equals(existingId))).write(companion);
    return false;
  }

  /// Local destination for a pulled photo's bytes: deterministic,
  /// so a re-pull lands on the same path and the backup service's
  /// basename path-rewrite keeps the shape. The file itself
  /// arrives lazily (see SyncPhotoService) — it does not exist
  /// yet. The `.jpg` suffix is part of the key layout, not a
  /// content promise — the bytes are whatever the capture
  /// produced (downscaled to 1600px/q85); image decoders sniff
  /// content, not the extension, so the suffix never affects
  /// display.
  Future<String> _localPhotoPath(String photoSyncId) async {
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/receipts/$photoSyncId.jpg';
  }

  /// Deletes a photo's local file, if it is inside our own
  /// receipts folder. Best-effort: a missing file (never
  /// downloaded — lazy rows have none) is normal, never an error.
  Future<void> _deleteLocalPhotoFile(String path) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File(path);
      if (file.path.startsWith('${docs.path}/receipts') &&
          await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // A missing file must never block applying the tombstone.
    }
  }
}
