import 'package:dmoney_manager/core/services/backup_service.dart';
import 'package:dmoney_manager/core/services/sync_failure_mode.dart';
import 'package:dmoney_manager/core/services/sync_orchestrator.dart';
import 'package:dmoney_manager/core/services/sync_prefs.dart';
import 'package:dmoney_manager/core/services/sync_pull_service.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// The server row counts per synced table (P5, idea #7).
/// Tombstoned rows are not counted — the preview shows what will
/// actually arrive.
class SyncPreview {
  const SyncPreview({required this.counts});

  /// Non-deleted server rows per table (server table names).
  final Map<String, int> counts;

  int get total => counts.values.fold(0, (a, b) => a + b);

  int count(String table) => counts[table] ?? 0;
}

/// The outcome of a first-run migration.
class SyncMigrationResult {
  const SyncMigrationResult({
    required this.backupPath,
    required this.pulled,
    required this.prefs,
  });

  /// Where the auto local backup was written (before the wipe).
  final String backupPath;

  /// Server rows applied locally (inserts + tombstones).
  final int pulled;

  /// The prefs round that ran after the pull.
  final SyncPrefsResult prefs;
}

/// First-run migration (§11, P5): a fresh install with an existing
/// Supabase account (signed in, server has data, local DB is
/// empty/seed-only) can adopt the server copy. The flow is explicit
/// — the user confirms after seeing the preview — and it never
/// runs on a device that already has local data unless the user
/// asks for it (the Settings "Replace this device's data" action
/// runs the same migration).
///
/// Steps: (a) auto local backup first — never wipe without one;
/// (b) show the preview; (c) wipe local tables + reset the pull
/// cursor; (d) full pull. Chunked initial push for the opposite
/// direction (local data, empty server) is P6, not this flow.
class SyncFirstRunService {
  SyncFirstRunService({required this.db, required this.orchestrator});

  final AppDatabase db;

  /// The orchestrator — its [SyncOrchestrator.remote] is the
  /// remote for the preview and the migration pull, and its
  /// [SyncOrchestrator.prefsService] / [SyncOrchestrator.deviceService]
  /// run the prefs round and the heartbeat after the pull.
  final SyncOrchestrator orchestrator;

  /// The 14 synced tables, in the pull's parent-before-child order
  /// (see `SyncPullService._pullTables`). The preview counts them
  /// all; the counts the screen shows first are the ones with rows.
  static const previewTables = [
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

  /// Server row counts per table. Throws for auth/transport
  /// failures — without the counts there is nothing to confirm.
  Future<SyncPreview> fetchPreview() async {
    final counts = <String, int>{};
    for (final table in previewTables) {
      counts[table] = await orchestrator.remote.countRows(table);
    }
    return SyncPreview(counts: counts);
  }

  /// Whether the local database holds anything beyond the seed.
  /// The seed creates categories only (no account), so a fresh
  /// install has no accounts, no wallets and no transactions.
  /// A single account with nothing in it already counts as local
  /// data — the user started setting the app up here.
  Future<bool> isLocalEmpty() async {
    final hasAccount =
        await (db.select(db.accounts)..limit(1)).get().then(
          (r) => r.isNotEmpty,
        );
    if (hasAccount) return false;
    final hasWallet =
        await (db.select(db.wallets)..limit(1)).get().then(
          (r) => r.isNotEmpty,
        );
    if (hasWallet) return false;
    final hasTransaction =
        await (db.select(db.transactions)..limit(1)).get().then(
          (r) => r.isNotEmpty,
        );
    return !hasTransaction;
  }

  /// Whether the automatic first-run offer applies: signed in,
  /// local empty, server has data. Returns the preview when
  /// eligible so the screen can show it without a second fetch.
  Future<({bool eligible, SyncPreview? preview})> checkFirstRun() async {
    if (orchestrator.currentUserId == null) {
      return (eligible: false, preview: null);
    }
    if (!await isLocalEmpty()) {
      return (eligible: false, preview: null);
    }
    final preview = await fetchPreview();
    if (preview.total == 0) {
      return (eligible: false, preview: null);
    }
    return (eligible: true, preview: preview);
  }

  /// Runs the migration. Throws when the backup fails (local data
  /// is untouched — the wipe only starts after the backup lands)
  /// or when the pull reports a fatal error (the local backup at
  /// [SyncMigrationResult.backupPath] is the way back). The pull
  /// reconciles derived state itself when it applies rows.
  ///
  /// [onStep] reports progress for the dialog ("Backing up…",
  /// "Clearing…", "Downloading…"). The caller applies a pulled
  /// language immediately via the locale notifier when
  /// [SyncMigrationResult.prefs].languageChanged is true — the
  /// first-run screen is the configuration moment, so the
  /// mid-session rule does not apply there.
  Future<SyncMigrationResult> runMigration({
    void Function(String step)? onStep,
  }) async {
    final ownerId = orchestrator.currentUserId;
    if (ownerId == null) throw StateError('not signed in');
    try {
      onStep?.call('backup');
      final backup = await BackupService.createBackup(db);
      onStep?.call('wipe');
      await db.wipeLocalDataForSync();
      onStep?.call('pull');
      final pull = await SyncPullService(
        db: db,
        remote: orchestrator.remote,
        ownerId: ownerId,
      ).pullNow();
      if (pull.error != null) throw pull.error!;
      onStep?.call('prefs');
      final prefs = await orchestrator.prefsService.syncPrefs(ownerId);
      // The heartbeat marks this device as seen with its new data.
      await orchestrator.deviceService.heartbeat(ownerId);
      final result = SyncMigrationResult(
        backupPath: backup.path,
        pulled: pull.applied + pull.tombstoned,
        prefs: prefs,
      );
      // The migration is a sync run — it belongs in the log.
      try {
        await db.recordSyncLog(
          pushed: 0,
          pulled: result.pulled,
          conflicts: pull.conflicts,
          failed: pull.failed,
        );
      } catch (_) {
        // Best-effort: see above.
      }
      return result;
    } catch (e) {
      // Log the failed migration, then rethrow — the caller
      // shows the error and the local backup is the way back.
      try {
        final mode = classifySyncError(e);
        await db.recordSyncLog(
          pushed: 0,
          pulled: 0,
          conflicts: 0,
          failed: 1,
          failureMode: syncFailureModeKey(mode),
          error: e.toString(),
        );
      } catch (_) {
        // Best-effort: see above.
      }
      rethrow;
    }
  }
}
