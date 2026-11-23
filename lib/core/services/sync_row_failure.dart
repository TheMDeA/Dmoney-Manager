/// The first row that failed to push or apply in a sync run
/// (audit round 2, #15/#25): per-row failures used to be swallowed
/// (`catch (_)` with only a counter incremented), so a poison row
/// re-failed every cycle with no trace of which table or row it
/// was. The push and pull services record the first one here; the
/// orchestrator stores it in the sync log and in the status error,
/// so Settings can name the row that blocks the queue.
class SyncRowFailure {
  const SyncRowFailure({
    required this.table,
    required this.syncId,
    required this.message,
  });

  /// The server/local table the row belongs to.
  final String table;

  /// The row's sync id — the identity the log and the user need.
  final String syncId;

  /// The failure, as the underlying error reported it. Kept short
  /// by the log's 500-character trim; never a payload.
  final String message;

  @override
  String toString() => '$table/$syncId: $message';
}
