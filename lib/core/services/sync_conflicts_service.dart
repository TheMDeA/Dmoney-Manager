import 'dart:convert';

import '../../data/database/app_database.dart';
import 'sync_apply.dart';

/// Restores and dismisses conflict-keeper entries (P3, idea #1).
/// The screen in Settings uses this; it needs only the database —
/// no remote — because Restore is a local edit that the next push
/// sends.
class SyncConflictService {
  SyncConflictService(this.db);

  final AppDatabase db;

  /// Restores the kept (losing) version of [conflict] as a new
  /// local edit: the kept payload is re-applied through the
  /// pull-apply path, an outbox entry is enqueued so the next
  /// push sends it as the newest change, derived state is
  /// recomputed, and the conflict entry is deleted. The apply,
  /// the outbox entry and the delete land in one transaction.
  /// Returns false when the kept copy cannot be applied (a
  /// record it references is gone) — the entry is left in place.
  Future<bool> restoreConflict(SyncConflict conflict) async {
    final payload =
        jsonDecode(conflict.losingJson) as Map<String, dynamic>;
    final maps = await PullReferenceMaps.load(db);
    final applier = SyncRowApplier(db);
    final created = await db.transaction(() async {
      bool createdRow;
      try {
        createdRow = await applier.applyServerRow(
          conflict.targetTable,
          payload,
          maps,
        );
      } on SyncUnresolvedException {
        // A record the kept copy references is gone — leave the
        // entry in place instead of restoring half a row.
        return null;
      }
      await db.enqueueOutbox(
        conflict.targetTable,
        conflict.syncId,
        createdRow ? 'insert' : 'update',
      );
      // The restored content is byte-identical to what this
      // device last pushed, so the push's unchanged-skip would
      // swallow it — but the server holds the winner's version,
      // not this one. Drop the stale hash so the next push sends
      // the restored edit unconditionally.
      await db.clearPushedHash(conflict.syncId);
      await db.deleteSyncConflict(conflict.id);
      return createdRow;
    });
    if (created == null) return false;
    await db.reconcileDerivedState();
    return true;
  }

  /// Drops one conflict-keeper entry without restoring it.
  Future<void> dismissConflict(int id) => db.deleteSyncConflict(id);
}
