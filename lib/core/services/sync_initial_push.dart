import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/services/sync_photos.dart';
import 'package:dmoney_manager/core/services/sync_push_service.dart';
import 'package:dmoney_manager/core/services/sync_remote.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// Chunked initial push (P6, §11/§13): when a device signs in
/// with a large local backlog and an empty server, the first sync
/// must not be one giant drain — it pushes bounded chunks, one per
/// cycle, and a killed run resumes where it left off.
///
/// The resume state IS the outbox: every chunk acks its entries
/// as they land, so a fresh cycle re-reads the outbox and
/// continues with what is left — nothing is ever re-pushed. The
/// persisted marker ([AppPrefs.syncInitialPushTotal]) exists only
/// so the status UI can show progress ("X of Y rows") and the
/// triggers know to keep scheduling cycles until the backlog
/// drains. A new edit mid-push grows the remaining count; the
/// total only ever grows, never shrinks, until the marker clears.
///
/// Steady state never touches this path: the orchestrator only
/// calls it when the outbox holds more than [chunkSize] entries,
/// so a normal cycle's push is byte-for-byte the P2 behaviour.
///
/// The seed gap this also closes (found in P6): rows that predate
/// sync — the seed categories and every row the v18 backfill gave
/// a sync id — have NO outbox entry, so a plain drain would push
/// nothing and the first sync would silently upload an empty
/// library. The orchestrator seeds the outbox once (see
/// [AppDatabase.enqueueAllRowsForInitialPush]) before its first
/// push; this service only chunks what is already queued.
class SyncInitialPushService {
  SyncInitialPushService({
    required this.db,
    required this.remoteFactory,
    required this.currentUserId,
    PhotoUploadGate? photoGate,
  }) : _photoGate = photoGate;

  /// Entries per chunk (two P2 batches of 100).
  static const chunkSize = 200;

  final AppDatabase db;
  final SyncRemote Function() remoteFactory;
  final String? Function() currentUserId;
  final PhotoUploadGate? _photoGate;

  /// True while a chunked push is in progress (the marker is
  /// set). The trigger service schedules follow-up cycles while
  /// this is true.
  bool get isActive => AppPrefs.syncInitialPushTotal != null;

  /// Progress for the status UI, or null when no chunked push is
  /// in progress. `pushed` is the total minus the entries still
  /// queued, clamped at zero — new edits mid-push can only grow
  /// the remaining count, so progress may step back slightly.
  Future<({int pushed, int total})?> progress() async {
    final total = AppPrefs.syncInitialPushTotal;
    if (total == null) return null;
    final remaining = await db.outboxCount();
    final pushed = (total - remaining).clamp(0, total);
    return (pushed: pushed, total: total);
  }

  /// Pushes one bounded chunk. Records the total on the first
  /// chunk (the outbox size when the chunked push started) and
  /// clears the marker when the outbox drains. Never throws for
  /// remote failures — they are reported in the result, like
  /// [SyncPushService.pushNow].
  Future<SyncPushResult> pushNextChunk() async {
    final ownerId = currentUserId();
    if (ownerId == null) return const SyncPushResult(notSignedIn: true);
    final before = await db.outboxCount();
    if (before == 0) {
      await AppPrefs.setSyncInitialPushTotal(null);
      return const SyncPushResult();
    }
    final total = AppPrefs.syncInitialPushTotal;
    if (total == null || before > total) {
      await AppPrefs.setSyncInitialPushTotal(before);
    }
    final result = await SyncPushService(
      db: db,
      remote: remoteFactory(),
      ownerId: ownerId,
      photoGate: _photoGate,
    ).pushNow(maxEntries: chunkSize);
    if (result.remaining == 0) {
      await AppPrefs.setSyncInitialPushTotal(null);
    }
    return result;
  }
}
