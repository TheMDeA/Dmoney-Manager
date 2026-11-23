import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import '../utils/sync_payload.dart';
import 'app_prefs.dart';
import 'sync_photos.dart';
import 'sync_remote.dart';
import 'sync_row_failure.dart';
import 'sync_serialiser.dart';

/// What one push run did. Entries that were skipped on purpose
/// (photos, account off, unresolvable FK) stay queued and are NOT
/// failures — the next run retries them.
class SyncPushResult {
  const SyncPushResult({
    this.pushed = 0,
    this.skippedUnchanged = 0,
    this.skippedAccountOff = 0,
    this.skippedPhotos = 0,
    this.skippedUnresolved = 0,
    this.skippedStale = 0,
    this.droppedNeverPushed = 0,
    this.skippedMissingFiles = 0,
    this.failed = 0,
    this.remaining = 0,
    this.notSignedIn = false,
    this.error,
    this.firstFailure,
  });

  /// Rows upserted or tombstoned on the server.
  final int pushed;

  /// Entries whose current payload hashes exactly what was last
  /// pushed — acked without a server call.
  final int skippedUnchanged;

  /// Rows whose owning account is toggled off (idea #3) — left
  /// queued so toggling the account on later syncs the backlog.
  final int skippedAccountOff;

  /// `transaction_photos` rows whose bytes are still waiting for
  /// Wi-Fi (idea #4) — left queued so the next run on Wi-Fi uploads
  /// them. Not failures.
  final int skippedPhotos;

  /// Rows whose foreign key cannot be resolved right now — left
  /// queued; a later pull may restore the referenced row.
  final int skippedUnresolved;

  /// Entries whose row is gone with no delete entry to follow — acked.
  final int skippedStale;

  /// Delete entries for rows the server never saw (created and
  /// deleted before their first push) — dropped, no tombstone sent.
  final int droppedNeverPushed;

  /// `transaction_photos` rows whose local file is gone — parked
  /// as dead letters (audit #18) instead of failing every cycle.
  /// The photo row stays local, so the entry can be retried or
  /// deleted from Settings. Not failures.
  final int skippedMissingFiles;

  /// Entries left queued by an error (per-row failures, or never
  /// attempted because a fatal error aborted the run).
  final int failed;

  /// Outbox entries still queued after the run: unprocessed
  /// because of the [maxEntries] cap, skipped on purpose, or
  /// failed. Zero on a complete drain — the chunked initial push
  /// (P6) reads this to know whether another chunk is due.
  final int remaining;

  /// True when there was no signed-in Supabase user — nothing was
  /// attempted.
  final bool notSignedIn;

  /// The fatal error that aborted the run, if any (auth or transport).
  final Object? error;

  /// The first row that failed this run, when any did — the
  /// identity the log and the status UI name (audit #15/#25).
  /// Null on a clean run.
  final SyncRowFailure? firstFailure;

  bool get hasFailures => failed > 0 || error != null;

  /// Entries deliberately left queued this run (not failures):
  /// the reason a pending count may not drain.
  int get skipped =>
      skippedAccountOff +
      skippedPhotos +
      skippedUnresolved +
      skippedMissingFiles;
}

typedef _PendingUpsert = ({
  SyncOutboxData entry,
  Map<String, dynamic> payload,
  String hash,
});

class _Counters {
  int pushed = 0;
  int skippedUnchanged = 0;
  int skippedAccountOff = 0;
  int skippedPhotos = 0;
  int skippedUnresolved = 0;
  int skippedStale = 0;
  int droppedNeverPushed = 0;
  int skippedMissingFiles = 0;

  /// The first row that failed this run (audit #15/#25) — kept
  /// for the result so the log and the status UI can name it.
  SyncRowFailure? firstFailure;

  /// Entries that reached a terminal decision this run — acked, or
  /// deliberately left queued. `failed` is derived from this: every
  /// entry that is neither settled nor skipped on purpose is one the
  /// run failed to push.
  int settled = 0;
}

/// Push-only sync (v3.0.0, P2+P4): drains `sync_outbox` in queued
/// order, ~100 rows per batch, upserts by `sync_id`, and removes
/// entries on server ack. On failure the entries stay queued and the
/// next trigger retries — nothing is ever dropped on a failed push.
///
/// Ordering: entries are grouped by table, parents before children
/// (a plan before its purchase expense, a transfer before its fee
/// row), with queued order kept inside each table — the server's
/// foreign keys are checked as rows land, so a child must never
/// arrive before its parent.
///
/// Photo bytes (P4) upload before their row, on Wi-Fi only (idea
/// #4) — the row upsert references the Storage object key.
///
/// No pull, no UI triggers, no device heartbeat — those are P3/P5.
class SyncPushService {
  SyncPushService({
    required this.db,
    required this.remote,
    required this.ownerId,
    PhotoUploadGate? photoGate,
  }) : _photoGate = photoGate ?? ConnectivityPhotoUploadGate();

  final AppDatabase db;
  final SyncRemote remote;

  /// The Supabase Auth user id — every pushed row's `owner_id`.
  /// Null when signed out; the push then does nothing.
  final String? ownerId;

  /// The Wi-Fi gate for photo uploads (idea #4). Injectable so
  /// tests can drive it without a radio; the real gate is the
  /// default.
  final PhotoUploadGate _photoGate;

  /// Outbox entries per batch.
  static const batchSize = 100;

  /// Push priority per table (lower runs first). Transactions come
  /// last: they reference wallets, categories, debts, plans and
  /// each other (transfer-fee rows).
  static const _tablePriority = {
    'accounts': 0,
    'categories': 1,
    'wallets': 2,
    'goals': 3,
    'installment_plans': 4,
    'debts': 5,
    'debt_payments': 6,
    'goal_deposits': 7,
    'recurring_transactions': 8,
    'transaction_templates': 9,
    'budgets': 10,
    'transactions': 11,
    'category_keywords': 12,
    'transaction_photos': 13,
  };

  /// One push attempt over the whole outbox. Never throws for
  /// remote errors — they are reported in the result.
  ///
  /// [maxEntries] bounds the run (P6 chunked initial push): at
  /// most that many outbox entries are processed, in queued
  /// order, and the rest stay queued for the next cycle. Null
  /// (the default) drains the whole outbox, exactly like P2.
  Future<SyncPushResult> pushNow({int? maxEntries}) async {
    if (ownerId == null) {
      return const SyncPushResult(notSignedIn: true);
    }
    final allEntries = await (db.select(db.syncOutbox)
          ..orderBy([(o) => OrderingTerm.asc(o.id)]))
        .get();
    if (allEntries.isEmpty) return const SyncPushResult();
    final entries = maxEntries == null
        ? allEntries
        : allEntries.take(maxEntries).toList();

    final maps = await SyncReferenceMaps.load(db);
    final serialiser = SyncSerialiser(
      db: db,
      maps: maps,
      ownerId: ownerId!,
    );
    final c = _Counters();
    Object? fatalError;

    for (var start = 0;
        start < entries.length && fatalError == null;
        start += batchSize) {
      final chunk = entries.sublist(
        start,
        min(start + batchSize, entries.length),
      );
      final upserts = <_PendingUpsert>[];
      final tombstones = <SyncOutboxData>[];

      for (final entry in chunk) {
        // P4: a photo's bytes must be in Storage before its row
        // can be upserted — the server `path` holds the Storage
        // object key, never a local filesystem path. The upload
        // waits for Wi-Fi (idea #4); while off Wi-Fi the entry
        // stays queued and the other rows still push. A missing
        // local file leaves the entry queued and unsettled
        // (counted as failed) — the file may reappear, e.g. after
        // a backup restore, and sync must never silently drop a
        // photo. Delete entries skip the upload: the row is gone,
        // the object is removed with the tombstone instead.
        if (entry.targetTable == 'transaction_photos' &&
            entry.op != 'delete') {
          bool ready;
          try {
            ready = await _ensurePhotoUploaded(entry, c);
          } on SyncFatalException catch (e) {
            // Auth/transport failure during the upload: abort the
            // run (the group pushes below are skipped too).
            fatalError = e;
            break;
          }
          if (!ready) continue;
          // Falls through to the generic serialise path below.
        }
        if (entry.op == 'delete') {
          final pushedHash = await _pushedHash(entry.syncId);
          if (pushedHash == null) {
            // Created and deleted before its first push: the server
            // never saw the row, so there is nothing to tombstone.
            await _ack([entry.id]);
            c.droppedNeverPushed++;
            c.settled++;
          } else {
            tombstones.add(entry);
          }
          continue;
        }
        final outcome = await serialiser.serialise(
          entry.targetTable,
          entry.syncId,
        );
        if (outcome.payload == null) {
          if (outcome.rowGone) {
            // Stale: the row is gone and no delete entry can follow
            // (deletes always enqueue one). Ack it so it can never
            // block the queue.
            await _ack([entry.id]);
            c.skippedStale++;
            c.settled++;
          } else {
            c.skippedUnresolved++;
            c.settled++;
          }
          continue;
        }
        // Per-account toggle (idea #3): enforced at push time, not
        // capture — the entry stays queued until the account is
        // toggled back on.
        if (outcome.accountId != null &&
            !AppPrefs.isAccountSynced(outcome.accountId!)) {
          c.skippedAccountOff++;
          c.settled++;
          continue;
        }
        final hash = payloadHash(outcome.payload!);
        final stored = await _pushedHash(entry.syncId);
        if (stored == hash) {
          // Unchanged since the last push — ack without a server
          // call, or the server trigger would bump
          // `server_updated_at` and churn every other device's
          // pull cursor for a row that never changed.
          await _ack([entry.id]);
          c.skippedUnchanged++;
          c.settled++;
          continue;
        }
        upserts.add((
          entry: entry,
          payload: outcome.payload!,
          hash: hash,
        ));
      }

      // Parents before children; queued order inside each table
      // (List.sort is stable), so a transfer stays ahead of its fee
      // row and a plan ahead of its purchase expense.
      upserts.sort((a, b) {
        final byTable =
            (_tablePriority[a.entry.targetTable] ?? 99) -
            (_tablePriority[b.entry.targetTable] ?? 99);
        return byTable != 0
            ? byTable
            : a.entry.id.compareTo(b.entry.id);
      });
      final upsertGroups = <String, List<_PendingUpsert>>{};
      for (final u in upserts) {
        upsertGroups.putIfAbsent(u.entry.targetTable, () => []).add(u);
      }
      final tombstoneGroups = <String, List<SyncOutboxData>>{};
      for (final e in tombstones) {
        tombstoneGroups.putIfAbsent(e.targetTable, () => []).add(e);
      }

      // A fatal error during the collection loop (a photo upload
      // hitting auth/transport failure) skips the group pushes for
      // this chunk — they would fail the same way.
      if (fatalError == null) {
        try {
          for (final group in upsertGroups.values) {
            await _pushUpsertGroup(group, c);
          }
          for (final group in tombstoneGroups.values) {
            await _pushTombstoneGroup(group, c);
          }
        } on SyncFatalException catch (e) {
          // Auth or transport failure: abort the run. Everything not
          // settled stays queued for the next trigger.
          fatalError = e;
        }
      }
    }

    if (fatalError == null) {
      try {
        await _markSynced();
      } catch (_) {
        // Best-effort stamp: the push already landed, and the
        // pull stamps lastSyncAt too. A failed stamp must not
        // fail the run.
      }
    }
    return SyncPushResult(
      pushed: c.pushed,
      skippedUnchanged: c.skippedUnchanged,
      skippedAccountOff: c.skippedAccountOff,
      skippedPhotos: c.skippedPhotos,
      skippedUnresolved: c.skippedUnresolved,
      skippedStale: c.skippedStale,
      droppedNeverPushed: c.droppedNeverPushed,
      skippedMissingFiles: c.skippedMissingFiles,
      failed: entries.length - c.settled,
      remaining: await db.outboxCount(),
      error: fatalError,
      firstFailure: c.firstFailure,
    );
  }

  /// Uploads a photo's bytes when its outbox entry is about to be
  /// collected, so the row upsert can reference the Storage object
  /// key. Returns true when the row is ready to serialise (its
  /// [TransactionPhoto.remoteKey] is set). Returns false when the
  /// entry must stay queued: off Wi-Fi (counted as `skippedPhotos`,
  /// deliberately settled — a deferral, not a failure), its
  /// transaction gone, or a Storage error (both NOT settled —
  /// counted as failed and retried next run). A row that is gone
  /// is acked as stale. A missing local file is parked as a dead
  /// letter instead (audit #18): the entry is acked and counted
  /// as `skippedMissingFiles`, so one lost file can no longer
  /// wedge the queue, block the heartbeat, or pin the
  /// initial-push marker — the photo row stays local, and the
  /// dead letter is retried or deleted from Settings. Throws
  /// [SyncFatalException] for auth/transport failures during the
  /// upload.
  Future<bool> _ensurePhotoUploaded(SyncOutboxData entry, _Counters c) async {
    final photo = await (db.select(
      db.transactionPhotos,
    )..where((p) => p.syncId.equals(entry.syncId))).getSingleOrNull();
    if (photo == null) {
      // Row gone with no delete entry to follow — ack as stale.
      await _ack([entry.id]);
      c.skippedStale++;
      c.settled++;
      return false;
    }
    if (photo.remoteKey != null) return true;
    bool onWifi;
    try {
      onWifi = await _photoGate.canUploadPhotos;
    } catch (_) {
      // The gate could not tell — assume not on Wi-Fi rather
      // than uploading on a connection the user did not allow.
      onWifi = false;
    }
    if (!onWifi) {
      c.skippedPhotos++;
      c.settled++;
      return false;
    }
    final file = File(photo.path);
    if (!await file.exists()) {
      // Parked, not failed: the bytes are gone, so no retry can
      // ever succeed until the file reappears — and the queue
      // must not fail on it every cycle meanwhile.
      await db.recordDeadLetter(
        targetTable: 'transaction_photos',
        syncId: entry.syncId,
        reason: 'photo_file_missing',
      );
      await _ack([entry.id]);
      c.skippedMissingFiles++;
      c.settled++;
      return false;
    }
    // The owning transaction's sync id is part of the object key.
    final tx = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(photo.transactionId))).getSingleOrNull();
    if (tx == null) {
      // Orphaned photo row (its transaction is gone): a real
      // inconsistency, not a transient failure — keep it visible
      // as a failure with its identity, instead of hiding it.
      c.firstFailure ??= SyncRowFailure(
        table: 'transaction_photos',
        syncId: entry.syncId,
        message: 'owning transaction is gone',
      );
      return false;
    }
    final key = photoObjectKey(ownerId!, tx.syncId, photo.syncId);
    try {
      await remote.uploadPhoto(key, file);
    } on SyncFatalException {
      rethrow;
    } catch (e) {
      // A Storage error (not auth/transport): leave the entry
      // queued and unsettled — counted as failed, retried next run.
      c.firstFailure ??= SyncRowFailure(
        table: 'transaction_photos',
        syncId: entry.syncId,
        message: e.toString(),
      );
      return false;
    }
    await db.setPhotoRemoteKey(photo.id, key);
    return true;
  }

  /// Retries [pushNow] with exponential backoff after a fatal error
  /// (auth/transport), up to [maxAttempts] attempts. Data errors do
  /// not retry — a bad row fails the same way every time.
  Future<SyncPushResult> pushWithRetry({int maxAttempts = 3}) async {
    var failures = 0;
    while (true) {
      final result = await pushNow();
      if (result.error == null ||
          result.notSignedIn ||
          failures + 1 >= maxAttempts) {
        return result;
      }
      failures++;
      await Future.delayed(retryDelayForAttempt(failures - 1));
    }
  }

  /// Backoff between push attempts: 1 s, 2 s, 4 s, 8 s, … capped at
  /// 60 s. Pure helper (see test/sync_push_test.dart).
  static Duration retryDelayForAttempt(int attempt) {
    final seconds = min(1 << attempt, 60);
    return Duration(seconds: seconds);
  }

  /// Upserts one table's group. A group failure falls back to
  /// per-row upserts so one bad row cannot block its siblings; a
  /// fatal error aborts the whole run.
  Future<void> _pushUpsertGroup(
    List<_PendingUpsert> group,
    _Counters c,
  ) async {
    final table = group.first.entry.targetTable;
    try {
      await remote.upsert(table, [for (final p in group) p.payload]);
    } on SyncFatalException {
      rethrow;
    } catch (_) {
      for (final p in group) {
        try {
          await remote.upsert(table, [p.payload]);
          await _ackAndRecordHash(p);
          c.pushed++;
          c.settled++;
        } on SyncFatalException {
          rethrow;
        } catch (e) {
          // Stays queued and unsettled — counted as failed.
          // Keep the first failure's identity for the log and
          // the status UI (audit #15/#25): a poison row must be
          // nameable, not just counted.
          c.firstFailure ??= SyncRowFailure(
            table: table,
            syncId: p.entry.syncId,
            message: e.toString(),
          );
        }
      }
      return;
    }
    await db.transaction(() async {
      await _ack([for (final p in group) p.entry.id]);
      for (final p in group) {
        await db.into(db.syncPushed).insertOnConflictUpdate(
          SyncPushedCompanion.insert(
            syncId: p.entry.syncId,
            targetTable: p.entry.targetTable,
            hash: p.hash,
          ),
        );
      }
    });
    c.pushed += group.length;
    c.settled += group.length;
  }

  /// Tombstones one table's group, with the same per-row fallback.
  /// A tombstoned row's hash record is deleted: the row is gone, so
  /// no later entry may skip on its hash.
  Future<void> _pushTombstoneGroup(
    List<SyncOutboxData> group,
    _Counters c,
  ) async {
    final table = group.first.targetTable;
    final stamp = DateTime.now();
    try {
      await remote.tombstone(
        table,
        [for (final e in group) e.syncId],
        stamp,
        ownerId!,
      );
    } on SyncFatalException {
      rethrow;
    } catch (_) {
      for (final e in group) {
        try {
          await remote.tombstone(table, [e.syncId], stamp, ownerId!);
          if (table == 'transaction_photos') {
            await _deletePhotoObjectBestEffort(e.syncId);
          }
          await _ackTombstone(e);
          c.pushed++;
          c.settled++;
        } on SyncFatalException {
          rethrow;
        } catch (err) {
          // Stays queued and unsettled — counted as failed.
          // Keep the first failure's identity for the log and
          // the status UI (audit #15/#25).
          c.firstFailure ??= SyncRowFailure(
            table: table,
            syncId: e.syncId,
            message: err.toString(),
          );
        }
      }
      return;
    }
    await db.transaction(() async {
      await _ack([for (final e in group) e.id]);
      for (final e in group) {
        await (db.delete(
          db.syncPushed,
        )..where((p) => p.syncId.equals(e.syncId))).go();
      }
    });
    if (table == 'transaction_photos') {
      for (final e in group) {
        await _deletePhotoObjectBestEffort(e.syncId);
      }
    }
    c.pushed += group.length;
    c.settled += group.length;
  }

  /// Removes the Storage object of a tombstoned photo. The local
  /// row is gone by push time, so the key is recovered from the
  /// server row (its `path`). Best-effort by design: a failed
  /// delete must never fail the run or resurrect the tombstone —
  /// the worst case is an orphaned object in a private bucket.
  /// Swallows everything, including [SyncFatalException].
  Future<void> _deletePhotoObjectBestEffort(String syncId) async {
    try {
      final row = await remote.fetchRow('transaction_photos', syncId);
      final key = row?['path'] as String?;
      if (key != null && key.isNotEmpty) {
        await remote.deletePhotoObject(key);
      }
    } catch (_) {
      // Best-effort: see above.
    }
  }

  Future<void> _ackAndRecordHash(_PendingUpsert p) async {
    await db.transaction(() async {
      await _ack([p.entry.id]);
      await db.into(db.syncPushed).insertOnConflictUpdate(
        SyncPushedCompanion.insert(
          syncId: p.entry.syncId,
          targetTable: p.entry.targetTable,
          hash: p.hash,
        ),
      );
    });
  }

  Future<void> _ackTombstone(SyncOutboxData entry) async {
    await db.transaction(() async {
      await _ack([entry.id]);
      await (db.delete(
        db.syncPushed,
      )..where((p) => p.syncId.equals(entry.syncId))).go();
    });
  }

  Future<void> _ack(List<int> outboxIds) async {
    await (db.delete(
      db.syncOutbox,
    )..where((o) => o.id.isIn(outboxIds))).go();
  }

  Future<String?> _pushedHash(String syncId) async {
    final row = await (db.select(
      db.syncPushed,
    )..where((p) => p.syncId.equals(syncId))).getSingleOrNull();
    return row?.hash;
  }

  /// Records that a sync ran (even one that pushed nothing — an
  /// unchanged outbox is still a successful sync). Only after a run
  /// that was not aborted by a fatal error.
  Future<void> _markSynced() async {
    await (db.update(
      db.syncState,
    )..where((s) => s.id.equals(1))).write(
      SyncStateCompanion(lastSyncAt: Value(DateTime.now())),
    );
  }
}
