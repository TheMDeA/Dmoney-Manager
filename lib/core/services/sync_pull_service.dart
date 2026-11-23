import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import '../utils/sync_payload.dart';
import 'app_prefs.dart';
import 'sync_apply.dart';
import 'sync_remote.dart';
import 'sync_serialiser.dart';

/// What one pull run did. Skips are not failures: a row skipped
/// on purpose (account off, pending local edit, unresolvable
/// parent) stays on the server and is re-seen on a later pull —
/// the cursor never advances past it.
class SyncPullResult {
  const SyncPullResult({
    this.pulled = 0,
    this.applied = 0,
    this.tombstoned = 0,
    this.conflicts = 0,
    this.skippedAccountOff = 0,
    this.skippedPendingOutbox = 0,
    this.skippedUnresolved = 0,
    this.overwrittenWithoutRecord = 0,
    this.failed = 0,
    this.notSignedIn = false,
    this.error,
  });

  /// Rows fetched from the server (all tables).
  final int pulled;

  /// Rows upserted locally (inserts + updates).
  final int applied;

  /// Tombstones applied as local deletes.
  final int tombstoned;

  /// Overwrites that kept the loser in `sync_conflicts`.
  final int conflicts;

  /// Rows whose owning account is toggled off (idea #3) — not
  /// applied, and the cursor holds them back.
  final int skippedAccountOff;

  /// Rows with a pending outbox entry — the local edit wins, so
  /// the pull never overwrites them; the push sends them first.
  final int skippedPendingOutbox;

  /// Rows whose foreign key cannot be resolved right now — the
  /// parent has not arrived yet; a later pull retries them.
  final int skippedUnresolved;

  /// Overwrites whose loser could not be serialised (its foreign
  /// key is gone), so no conflict entry was kept.
  final int overwrittenWithoutRecord;

  /// Rows that failed to apply with an unexpected error.
  final int failed;

  /// True when there was no signed-in Supabase user — nothing
  /// was attempted.
  final bool notSignedIn;

  /// The error that aborted the run, if any (fetch or local
  /// database failure). Pages applied before the abort stay
  /// applied; the cursor does not advance, so the rest is
  /// re-fetched on the next run.
  final Object? error;

  bool get hasFailures => failed > 0 || error != null;
}

class _PullCounters {
  int pulled = 0;
  int applied = 0;
  int tombstoned = 0;
  int conflicts = 0;
  int skippedAccountOff = 0;
  int skippedPendingOutbox = 0;
  int skippedUnresolved = 0;
  int overwrittenWithoutRecord = 0;
  int failed = 0;

  /// Canonical (`...Z`) `server_updated_at` of every applied row.
  final appliedTimestamps = <String>[];

  /// Newest applied timestamp, or null when nothing applied.
  String? appliedMax;

  /// Oldest skipped row's timestamp, or null when nothing was
  /// skipped. The cursor never advances past this value.
  String? skippedMin;

  void noteApplied(String ts) {
    appliedTimestamps.add(ts);
    if (appliedMax == null || ts.compareTo(appliedMax!) > 0) {
      appliedMax = ts;
    }
  }

  void noteSkipped(String ts) {
    if (skippedMin == null || ts.compareTo(skippedMin!) < 0) {
      skippedMin = ts;
    }
  }
}

/// Pull-only sync (v3.0.0, P3): fetches rows newer than the pull
/// cursor, applies them parents-before-children inside one local
/// transaction per page, recomputes derived state, and advances
/// the cursor. A pull never touches the outbox — pulled rows are
/// already on the server.
///
/// Ordering contract (see the concept doc §6): the sync cycle
/// runs push BEFORE pull, so a row with a pending outbox entry is
/// never overwritten here — it is skipped and the push wins. The
/// skip is the safety net even if pull runs first: the local edit
/// survives in the outbox and the next push sends it.
///
/// Cursor rule: the cursor is a server timestamp, and a skipped
/// row must be re-seen on the next pull, so the cursor never
/// advances past the oldest skipped row. With no skipped rows it
/// advances to the newest applied timestamp; with skipped rows it
/// advances only to the newest applied timestamp strictly older
/// than the oldest skipped row (or does not move at all).
/// Re-fetching already-applied rows is harmless — the apply is an
/// idempotent upsert by sync id, and the conflict check only
/// fires when content actually differs.
///
/// No triggers, no status UI, no device heartbeat — those are P5.
class SyncPullService {
  SyncPullService({
    required this.db,
    required this.remote,
    required this.ownerId,
  });

  final AppDatabase db;
  final SyncRemote remote;

  /// The Supabase Auth user id. Null when signed out; the pull
  /// then does nothing.
  final String? ownerId;

  /// Server rows per page, per table.
  static const pageSize = 100;

  /// Pull priority per table (lower runs first) — the same
  /// parent-before-child order as the push (see
  /// `SyncPushService._tablePriority`): a plan lands before its
  /// purchase expense, a wallet before its transactions.
  /// `transaction_photos` runs last: its rows reference
  /// transactions, which must already have landed.
  static const _pullTables = [
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

  /// One pull run over every table. Never throws for remote or
  /// row errors — they are reported in the result.
  Future<SyncPullResult> pullNow() async {
    if (ownerId == null) {
      return const SyncPullResult(notSignedIn: true);
    }
    final state = await db.select(db.syncState).getSingle();
    final startCursor = state.lastPullCursor;
    final maps = await PullReferenceMaps.load(db);
    final serialiserMaps = await SyncReferenceMaps.load(db);
    final serialiser = SyncSerialiser(
      db: db,
      maps: serialiserMaps,
      ownerId: ownerId!,
    );
    final applier = SyncRowApplier(db);
    final c = _PullCounters();
    Object? fatalError;

    try {
      for (final table in _pullTables) {
        var offset = 0;
        while (true) {
          final page = await remote.pull(
            table,
            startCursor,
            offset,
            pageSize,
          );
          if (page.isEmpty) break;
          c.pulled += page.length;
          final photoObjectsToDelete = <String>[];
          await db.transaction(() async {
            final pending = await _pendingSyncIds(table);
            final ordered = orderPageForApply(table, page);
            for (final row in ordered) {
              await _applyPageRow(
                table,
                row,
                maps,
                serialiser,
                applier,
                pending,
                photoObjectsToDelete,
                c,
              );
            }
          });
          // Storage objects are removed after the page transaction
          // commits — a rollback above leaves both the row and its
          // bytes alone for the next pull.
          for (final key in photoObjectsToDelete) {
            await _deletePhotoObjectBestEffort(key);
          }
          if (page.length < pageSize) break;
          offset += page.length;
        }
      }
    } catch (e) {
      // A failed fetch or a failed page aborts the run. Pages
      // already applied stay applied (the apply is idempotent);
      // the cursor does not advance, so the rest is re-fetched
      // on the next run.
      fatalError = e;
    }

    if (c.applied + c.tombstoned > 0) {
      // Derived state is recomputed from the pulled ledger even
      // after a partial run — the applied subset must land on
      // consistent balances. A failure here is reported, not
      // thrown: the applied rows stay applied and the cursor
      // does not advance, so the next run re-fetches them.
      try {
        await db.reconcileDerivedState();
      } catch (e) {
        fatalError = e;
      }
    }

    if (fatalError == null) {
      final newCursor = _computeNewCursor(startCursor, c);
      await (db.update(
        db.syncState,
      )..where((s) => s.id.equals(1))).write(
        SyncStateCompanion(
          lastPullCursor: Value(newCursor),
          lastSyncAt: Value(DateTime.now()),
        ),
      );
    }

    return SyncPullResult(
      pulled: c.pulled,
      applied: c.applied,
      tombstoned: c.tombstoned,
      conflicts: c.conflicts,
      skippedAccountOff: c.skippedAccountOff,
      skippedPendingOutbox: c.skippedPendingOutbox,
      skippedUnresolved: c.skippedUnresolved,
      overwrittenWithoutRecord: c.overwrittenWithoutRecord,
      failed: c.failed,
      error: fatalError,
    );
  }

  /// Resets the pull cursor to the beginning (P5 first-run flow:
  /// after wiping the local tables, the next pull fetches
  /// everything from the server).
  Future<void> resetPullCursor() async {
    await (db.update(
      db.syncState,
    )..where((s) => s.id.equals(1))).write(
      const SyncStateCompanion(lastPullCursor: Value(null)),
    );
  }

  /// Removes one Storage object, best-effort: a failed delete must
  /// never fail the pull — the worst case is an orphaned object in
  /// a private bucket. Swallows everything, including
  /// [SyncFatalException].
  Future<void> _deletePhotoObjectBestEffort(String key) async {
    try {
      await remote.deletePhotoObject(key);
    } catch (_) {
      // Best-effort: see above.
    }
  }

  /// Sync ids with a pending outbox entry for [table], read fresh
  /// per page so a local edit made mid-pull is still honoured.
  Future<Set<String>> _pendingSyncIds(String table) async {
    final entries =
        await (db.select(
          db.syncOutbox,
        )..where((o) => o.targetTable.equals(table))).get();
    return {for (final e in entries) e.syncId};
  }

  /// Applies one fetched row inside the page transaction.
  /// Tombstoned photo rows append their Storage object key to
  /// [photoObjectsToDelete] — the objects are removed after the
  /// page transaction commits, never inside it.
  Future<void> _applyPageRow(
    String table,
    Map<String, dynamic> row,
    PullReferenceMaps maps,
    SyncSerialiser serialiser,
    SyncRowApplier applier,
    Set<String> pending,
    List<String> photoObjectsToDelete,
    _PullCounters c,
  ) async {
    final syncId = row['sync_id'] as String;
    final ts = _canonicalTs(row['server_updated_at'] as String);
    try {
      // Per-account toggle (idea #3): enforced at pull time,
      // like the push side — the row stays on the server and
      // is re-seen when the account is toggled back on.
      final accountId = await accountIdForIncomingRow(maps, table, row);
      if (accountId != null && !AppPrefs.isAccountSynced(accountId)) {
        c.skippedAccountOff++;
        c.noteSkipped(ts);
        return;
      }
      // A pending local edit wins: never overwrite a row the
      // push has not sent yet.
      if (pending.contains(syncId)) {
        c.skippedPendingOutbox++;
        c.noteSkipped(ts);
        return;
      }
      final deletedAt = row['deleted_at'] as String?;
      if (deletedAt != null) {
        if (await _localRowExists(table, syncId, maps)) {
          await _maybeRecordConflict(
            table,
            row,
            maps,
            serialiser,
            c,
            ignoreDeletedAt: true,
          );
          await applier.applyTombstone(table, syncId, maps);
        }
        // The Storage object outlives its row: the row's `path`
        // IS the object key. Collect it for deletion after the
        // page transaction commits (never a network call inside
        // the transaction) — the deleting device's push already
        // tried, this is the second chance.
        if (table == 'transaction_photos') {
          final key = row['path'] as String?;
          if (key != null && key.isNotEmpty) {
            photoObjectsToDelete.add(key);
          }
        }
        c.tombstoned++;
      } else {
        if (await _localRowExists(table, syncId, maps)) {
          await _maybeRecordConflict(table, row, maps, serialiser, c);
        }
        await applier.applyServerRow(table, row, maps);
        c.applied++;
      }
      c.noteApplied(ts);
    } on SyncUnresolvedException {
      // The parent has not arrived yet — a later pull retries
      // the row (the cursor holds it back).
      c.skippedUnresolved++;
      c.noteSkipped(ts);
    } catch (_) {
      // A malformed row must not nuke the page: skip it, hold
      // the cursor back, and surface the failure in the result.
      c.failed++;
      c.noteSkipped(ts);
    }
  }

  Future<bool> _localRowExists(
    String table,
    String syncId,
    PullReferenceMaps maps,
  ) async {
    if (table == 'category_keywords') {
      final existing =
          await (db.select(
            db.categoryKeywords,
          )..where((k) => k.syncId.equals(syncId))).getSingleOrNull();
      return existing != null;
    }
    return await maps.resolve(table, syncId) != null;
  }

  /// Records a conflict-keeper entry when the pull is about to
  /// overwrite a row this device previously pushed with different
  /// content. The loser is the local row's serialised payload —
  /// the same shape the push sends — kept as canonical JSON.
  ///
  /// The gate is the `sync_pushed` hash record ("previously
  /// pushed"); the content check compares the non-derived
  /// payloads. Derived columns (`wallets.balance`,
  /// `installment_plans.paid_count`, `goals.saved`) and usage
  /// counters (`use_count`, `hits`) are excluded — they
  /// legitimately differ between devices without any edit being
  /// lost, and including them would record a conflict for every
  /// routine overwrite. Timestamps compare as instants, so the
  /// server's `+00:00` form and the local `Z` form match.
  ///
  /// Known limitation: the gate cannot tell a row this device
  /// genuinely edited from one it only ever pushed as part of
  /// the initial bulk upload — the first remote edit to a
  /// never-locally-edited row records a conflict too. The entry
  /// is dismissible from the conflicts screen.
  Future<void> _maybeRecordConflict(
    String table,
    Map<String, dynamic> row,
    PullReferenceMaps maps,
    SyncSerialiser serialiser,
    _PullCounters c, {
    bool ignoreDeletedAt = false,
  }) async {
    final syncId = row['sync_id'] as String;
    final pushed =
        await (db.select(
          db.syncPushed,
        )..where((p) => p.syncId.equals(syncId))).getSingleOrNull();
    if (pushed == null) return;
    final outcome = await serialiser.serialise(table, syncId);
    if (outcome.payload == null) {
      // The local row cannot be serialised faithfully (a foreign
      // key it needs is gone) — there is nothing to keep.
      c.overwrittenWithoutRecord++;
      return;
    }
    if (_payloadsEqual(
      table,
      outcome.payload!,
      row,
      ignoreDeletedAt: ignoreDeletedAt,
    )) {
      return;
    }
    await db.recordSyncConflict(
      targetTable: table,
      syncId: syncId,
      losingJson: canonicalJson(outcome.payload!),
    );
    c.conflicts++;
  }

  /// New cursor for a completed run: with no skipped rows, the
  /// newest applied timestamp; with skipped rows, the newest
  /// applied timestamp strictly older than the oldest skipped
  /// row — or the old cursor, when no applied row is older.
  String? _computeNewCursor(String? startCursor, _PullCounters c) {
    if (c.skippedMin == null) {
      return c.appliedMax ?? startCursor;
    }
    String? best;
    for (final ts in c.appliedTimestamps) {
      if (ts.compareTo(c.skippedMin!) < 0 &&
          (best == null || ts.compareTo(best) > 0)) {
        best = ts;
      }
    }
    return best ?? startCursor;
  }
}

/// Server timestamps to one canonical form (UTC ISO with `Z`) so
/// string comparison is chronological: PostgREST returns
/// `+00:00` offsets, the local serialiser emits `Z`.
String _canonicalTs(String value) =>
    DateTime.parse(value).toUtc().toIso8601String();

/// Keys dropped from the conflict comparison on both sides:
/// server bookkeeping, not row content. `updated_at` is the last
/// local modification time — each device stamps its own edits,
/// so the values legitimately differ; the server's
/// `server_updated_at` is the only ordering authority.
const _ignoredKeys = {'server_updated_at', 'owner_id', 'updated_at'};

/// Derived columns and usage counters, dropped per table: they
/// differ between devices without any edit being lost.
const _derivedKeys = {
  'wallets': {'balance'},
  'installment_plans': {'paid_count'},
  'goals': {'saved'},
  'transaction_templates': {'use_count'},
  'category_keywords': {'hits'},
};

/// Timestamp columns, compared as instants rather than strings.
const _timestampKeys = {
  'date',
  'created_at',
  'due_date',
  'deadline',
  'next_due',
  'end_date',
  'deleted_at',
  'server_updated_at',
};

/// Double columns, compared as doubles (the server may return an
/// integral double as an int-looking JSON number).
const _doubleKeys = {'interest_rate_monthly', 'interest_rate_annual'};

bool _payloadsEqual(
  String table,
  Map<String, dynamic> local,
  Map<String, dynamic> incoming, {
  bool ignoreDeletedAt = false,
}) {
  final ignored = {
    ..._ignoredKeys,
    ...?_derivedKeys[table],
    if (ignoreDeletedAt) 'deleted_at',
  };
  final keys = {...local.keys, ...incoming.keys}
      .where((k) => !ignored.contains(k));
  for (final key in keys) {
    if (!_valuesEqual(key, local[key], incoming[key])) return false;
  }
  return true;
}

bool _valuesEqual(String key, Object? a, Object? b) {
  if (a == null || b == null) return a == b;
  if (_timestampKeys.contains(key) && a is String && b is String) {
    final da = DateTime.tryParse(a);
    final db = DateTime.tryParse(b);
    if (da != null && db != null) return da.toUtc() == db.toUtc();
  }
  if (_doubleKeys.contains(key) && a is num && b is num) {
    return a.toDouble() == b.toDouble();
  }
  return a == b;
}
