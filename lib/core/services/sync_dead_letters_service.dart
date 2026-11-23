import 'dart:io';

import '../../data/database/app_database.dart';

/// Retries and deletes parked sync entries (schema v19, audit
/// #18). The Settings screen uses this; it needs only the
/// database — no remote — because Retry is a local re-enqueue
/// that the next push sends, and Delete removes the local photo
/// row (which enqueues its own delete when the server saw it).
class SyncDeadLetterService {
  SyncDeadLetterService(this.db);

  final AppDatabase db;

  /// Outcome of a retry attempt, so the UI can say what happened.
  static const String retryQueued = 'queued';
  static const String retryStillMissing = 'still_missing';
  static const String retryGone = 'gone';

  /// Re-queues the parked entry for the next push. Returns
  /// [retryQueued] when the row is back in the outbox,
  /// [retryStillMissing] when its file is still gone (the entry
  /// stays parked), or [retryGone] when the row itself is gone
  /// (the entry is dropped).
  Future<String> retryDeadLetter(SyncDeadLetter letter) async {
    if (letter.targetTable == 'transaction_photos') {
      final photo = await (db.select(
        db.transactionPhotos,
      )..where((p) => p.syncId.equals(letter.syncId))).getSingleOrNull();
      if (photo == null) {
        await db.deleteDeadLetter(letter.id);
        return retryGone;
      }
      if (!await File(photo.path).exists()) return retryStillMissing;
      await db.transaction(() async {
        await db.enqueueOutbox(
          letter.targetTable,
          letter.syncId,
          'update',
        );
        // The parked upload never landed, so no hash can exist —
        // but a restored file may follow an earlier life of the
        // row. Drop any stale hash so the push sends it
        // unconditionally.
        await db.clearPushedHash(letter.syncId);
        await db.deleteDeadLetter(letter.id);
      });
      return retryQueued;
    }
    // Unknown table (a future reason): re-queue blindly — the
    // push's own checks decide whether the row can go.
    await db.transaction(() async {
      await db.enqueueOutbox(
        letter.targetTable,
        letter.syncId,
        'update',
      );
      await db.clearPushedHash(letter.syncId);
      await db.deleteDeadLetter(letter.id);
    });
    return retryQueued;
  }

  /// Deletes the parked photo row (and its dead letter). The
  /// row's own delete path enqueues a tombstone when the server
  /// saw the row, and drops the entry when it never did — the
  /// same outcome as deleting the photo anywhere else.
  Future<void> deleteDeadLetterPhoto(SyncDeadLetter letter) async {
    if (letter.targetTable != 'transaction_photos') {
      await db.deleteDeadLetter(letter.id);
      return;
    }
    final photo = await (db.select(
      db.transactionPhotos,
    )..where((p) => p.syncId.equals(letter.syncId))).getSingleOrNull();
    if (photo != null) {
      await db.deletePhoto(photo.id);
    }
    await db.deleteDeadLetter(letter.id);
  }
}
