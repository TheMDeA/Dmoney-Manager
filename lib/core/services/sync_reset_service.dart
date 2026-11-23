import 'package:dmoney_manager/core/services/backup_service.dart';
import 'package:dmoney_manager/core/services/sync_orchestrator.dart';
import 'package:dmoney_manager/core/services/sync_remote.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// The outcome of a sync reset.
class SyncResetResult {
  const SyncResetResult({
    required this.backupPath,
    required this.wipe,
    required this.queued,
    required this.pushed,
    required this.pulled,
    this.cycleError,
  });

  /// Where the auto local backup was written (before the wipe).
  final String backupPath;

  /// What the wipe removed from the server.
  final ServerWipeResult wipe;

  /// Local rows re-enqueued for upload.
  final int queued;

  /// Rows the first cycle pushed (a large book uploads in 200-row
  /// chunks — the rest follows in background cycles).
  final int pushed;

  /// Server rows the first cycle pulled back.
  final int pulled;

  /// The first cycle's fatal error, if any. The reset itself still
  /// succeeded — the queued rows stay queued and the trigger
  /// service retries them — but the upload is not finished yet.
  final Object? cycleError;
}

/// "Reset sync data" (Settings → Online sync): the in-app version
/// of the manual server wipe — clear the owner's Supabase data and
/// re-upload this device's book, so a corrupted or duplicated
/// server copy can be rebuilt from one phone without the dashboard.
///
/// Steps: (a) auto local backup first — never wipe without one;
/// (b) wipe the server (16 tables + receipt photos);
/// (c) re-enqueue every local row for upload and reset the pull
/// cursors; (d) run one sync cycle, which pushes the first chunk.
/// A large book uploads in 200-row chunks (P6): the trigger
/// service schedules follow-up cycles until the outbox drains, so
/// the reset returns before the upload finishes — the caller must
/// tell the user to wait for the pending count to hit zero before
/// another device does "Replace this device's data".
///
/// Race safety: a cycle running concurrently with the wipe can
/// push rows the wipe then deletes — but the re-enqueue in (c)
/// runs after the wipe and re-queues EVERYTHING, so those rows
/// are pushed again. And a wipe that fails halfway still
/// re-enqueues first (see below), so the wiped rows are never
/// stranded without a queued re-upload.
class SyncResetService {
  SyncResetService({required this.db, required this.orchestrator});

  final AppDatabase db;

  /// The orchestrator — its [SyncOrchestrator.remote] is the
  /// remote for the wipe and the first cycle.
  final SyncOrchestrator orchestrator;

  /// Runs the reset. Throws when the backup fails (nothing was
  /// wiped) or when the wipe fails (the local book is re-enqueued
  /// first, so the next cycles re-push the wiped rows; the local
  /// backup file stays on disk and can be restored from
  /// Settings → Backup). The first cycle never throws for remote
  /// failures — they land in [SyncResetResult.cycleError] instead.
  Future<SyncResetResult> runReset({
    void Function(String step)? onStep,
  }) async {
    final ownerId = orchestrator.currentUserId;
    if (ownerId == null) throw StateError('not signed in');
    onStep?.call('backup');
    final backup = await BackupService.createBackup(db);
    final photoKeys = await _photoKeys();
    ServerWipeResult wipe;
    try {
      onStep?.call('wipe');
      wipe = await orchestrator.remote.wipeServerData(photoKeys);
    } catch (e) {
      // A wipe that fails halfway leaves a partial server: the
      // rows it deleted must be re-enqueued before reporting, or
      // they would never be pushed back (their outbox entries are
      // gone and their pushed hashes say "already sent").
      await _requeueAll();
      rethrow;
    }
    onStep?.call('requeue');
    final queued = await _requeueAll();
    onStep?.call('push');
    final cycle = await orchestrator.syncNow();
    return SyncResetResult(
      backupPath: backup.path,
      wipe: wipe,
      queued: queued,
      pushed: cycle.pushed,
      pulled: cycle.pulled,
      cycleError: cycle.error,
    );
  }

  /// The Storage object keys of this device's receipt photos —
  /// the local rows are the only record of which objects exist.
  Future<List<String>> _photoKeys() async {
    final photos = await (db.select(db.transactionPhotos)
          ..where((p) => p.remoteKey.isNotNull()))
        .get();
    return [for (final p in photos) p.remoteKey!];
  }

  /// Re-enqueues every local row for upload and resets the pull
  /// cursors (global + per-table), so the next cycles re-push the
  /// whole book and pull from the beginning. Returns the queued
  /// outbox count.
  Future<int> _requeueAll() async {
    await db.transaction(() async {
      await db.resetSyncAfterRestore();
    });
    return db.outboxCount();
  }
}
