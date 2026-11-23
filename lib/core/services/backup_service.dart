import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../data/database/app_database.dart';
import '../utils/app_locale.dart';
import 'app_prefs.dart';
import 'notification_service.dart';
import 'paylater_reminder_sync.dart';

/// Thrown when a backup file is not a valid Dmoney Manager backup.
class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => 'BackupException: $message';
}

/// Full backup & restore: the SQLite database (consistent snapshot via
/// `VACUUM INTO`), receipt photos, and app preferences, packed into a
/// single zip file.
///
/// Restore copies rows into the live database (no close/reopen needed),
/// so every stream in the UI refreshes automatically.
class BackupService {
  static const _appId = 'dmoney_manager';
  static const _formatVersion = 1;

  /// In-process guard so a backup, a restore, and a Drive auto-backup
  /// can never run at the same time: they share the temp snapshot
  /// path and the receipts folder, so interleaving them could corrupt
  /// a zip or mix two restores' data. Dart is single-threaded and
  /// [_tryAcquire] has no await between the check and the set, so a
  /// plain boolean is enough — every holder releases in a `finally`.
  static bool _busy = false;

  /// True while a backup or restore is running in this process.
  static bool get isBusy => _busy;

  static bool _tryAcquire() {
    if (_busy) return false;
    _busy = true;
    return true;
  }

  static void _release() {
    _busy = false;
  }

  /// Makes each backup run's temp paths unique (millis + a counter),
  /// so two runs can never share a snapshot file or zip name — even
  /// across a crashed run that left stale temp files behind.
  static int _runCounter = 0;

  /// Tables in parent-before-child order for the restore copy.
  /// Every table in the schema belongs here — this list used to
  /// silently skip installment plans, recurring rules, templates
  /// and category keywords, so a restore lost them (and on the same
  /// device left stale rows behind for restored transactions to
  /// point at). Transactions come after the tables they reference
  /// (plans via planId, recurring rules via recurringId).
  static const _insertOrder = [
    'accounts',
    'wallets',
    'categories',
    'category_keywords',
    'recurring_transactions',
    'transaction_templates',
    'installment_plans',
    'transactions',
    'transaction_photos',
    'budgets',
    'goals',
    'goal_deposits',
    'debts',
    'debt_payments',
  ];

  /// Creates a backup zip in the temp directory and returns it.
  /// Throws [BackupException] when another backup or restore is
  /// already running in this process.
  static Future<File> createBackup(AppDatabase db) async {
    if (!_tryAcquire()) {
      throw BackupException(
        localizedOrFallback(
          (l) => l.backupBusy,
          'A backup or restore is already running. Try again in a moment.',
        ),
      );
    }
    try {
      return await _createBackup(db);
    } finally {
      _release();
    }
  }

  static Future<File> _createBackup(AppDatabase db) async {
    final tmp = await getTemporaryDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    _runCounter++;
    final runId = '${DateTime.now().millisecondsSinceEpoch}_$_runCounter';

    // A consistent snapshot while the database stays open.
    final snapshotPath = '${tmp.path}/dmoney_snapshot_$runId.sqlite';
    final snapshotFile = File(snapshotPath);
    await db.customStatement("VACUUM INTO '${_escape(snapshotPath)}'");

    final archive = Archive();
    final dbBytes = await snapshotFile.readAsBytes();
    archive.addFile(ArchiveFile('database.sqlite', dbBytes.length, dbBytes));

    final manifest = jsonEncode({
      'app': _appId,
      'format': _formatVersion,
      'schemaVersion': db.schemaVersion,
      'createdAt': DateTime.now().toIso8601String(),
    });
    final manifestBytes = utf8.encode(manifest);
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    // Receipt photos.
    final docs = await getApplicationDocumentsDirectory();
    final receipts = Directory('${docs.path}/receipts');
    if (await receipts.exists()) {
      await for (final entity in receipts.list(recursive: true)) {
        if (entity is File) {
          final rel = entity.path.substring(receipts.path.length + 1);
          final bytes = await entity.readAsBytes();
          archive.addFile(ArchiveFile('receipts/$rel', bytes.length, bytes));
        }
      }
    }

    // App preferences (currency, theme, name, ...).
    final prefs = await SharedPreferences.getInstance();
    final prefsMap = <String, Object?>{};
    for (final key in prefs.getKeys()) {
      prefsMap[key] = prefs.get(key);
    }
    final prefsBytes = utf8.encode(jsonEncode(prefsMap));
    archive.addFile(ArchiveFile('prefs.json', prefsBytes.length, prefsBytes));

    final zipBytes = ZipEncoder().encode(archive)!;
    final out = File('${tmp.path}/dmoney-backup-$stamp-$runId.zip');
    await out.writeAsBytes(zipBytes);
    await snapshotFile.delete();
    return out;
  }

  /// Restores [zipFile] into the live database, replacing all current
  /// data. Throws [BackupException] on invalid files, or when another
  /// backup or restore is already running in this process.
  static Future<void> restoreBackup(AppDatabase db, File zipFile) async {
    if (!_tryAcquire()) {
      throw BackupException(
        localizedOrFallback(
          (l) => l.backupBusy,
          'A backup or restore is already running. Try again in a moment.',
        ),
      );
    }
    try {
      await _restoreBackup(db, zipFile);
    } finally {
      _release();
    }
  }

  static Future<void> _restoreBackup(AppDatabase db, File zipFile) async {
    final tmp = await getTemporaryDirectory();
    final workDir = Directory(
      '${tmp.path}/dmoney_restore_${DateTime.now().millisecondsSinceEpoch}',
    );
    try {
      await workDir.create(recursive: true);

      final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
      for (final entry in archive) {
        if (!entry.isFile) continue;
        // Zip-slip: a crafted entry must never write outside the
        // restore work directory. Real backups never contain such
        // names, so reject the file outright.
        final rel = entry.name.replaceAll('\\', '/');
        if (rel.startsWith('/') || rel.split('/').contains('..')) {
          throw BackupException(
            localizedOrFallback(
              (l) => l.backupNotDmoneyFile,
              'Not a Dmoney Manager backup file.',
            ),
          );
        }
        final out = File('${workDir.path}/$rel');
        await out.parent.create(recursive: true);
        await out.writeAsBytes(entry.content as List<int>);
      }

      final manifestFile = File('${workDir.path}/manifest.json');
      if (!await manifestFile.exists()) {
        throw BackupException(
          localizedOrFallback(
            (l) => l.backupNotDmoneyFile,
            'Not a Dmoney Manager backup file.',
          ),
        );
      }
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      if (manifest['app'] != _appId) {
        throw BackupException(
          localizedOrFallback(
            (l) => l.backupNotDmoneyFile,
            'Not a Dmoney Manager backup file.',
          ),
        );
      }

      if (manifest['format'] != _formatVersion) {
        throw BackupException(
          localizedOrFallback(
            (l) => l.backupNotDmoneyFile,
            'Not a Dmoney Manager backup file.',
          ),
        );
      }
      final backupSchema = manifest['schemaVersion'];
      if (backupSchema is! int) {
        throw BackupException(
          localizedOrFallback(
            (l) => l.backupNotDmoneyFile,
            'Not a Dmoney Manager backup file.',
          ),
        );
      }
      if (backupSchema > db.schemaVersion) {
        throw BackupException(
          localizedOrFallback(
            (l) => l.backupFromNewerApp,
            'This backup was made by a newer version of Dmoney Manager. '
            'Update the app first.',
          ),
        );
      }

      final backupDb = File('${workDir.path}/database.sqlite');
      if (!await backupDb.exists()) {
        throw BackupException(
          localizedOrFallback(
            (l) => l.backupMissingDatabase,
            'Backup is missing its database.',
          ),
        );
      }
      // A truncated or foreign file must fail here, before any live
      // data is touched: every SQLite database starts with this
      // header; an empty or random file used to sail past the probe
      // inside _restoreDatabase and the restore then wiped the live
      // tables and reported success.
      final header = await backupDb
          .openRead(0, 16)
          .fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
      if (header.length < 16 ||
          String.fromCharCodes(header.sublist(0, 15)) != 'SQLite format 3') {
        throw BackupException(
          localizedOrFallback(
            (l) => l.backupDatabaseCorrupt,
            'The database inside this backup is damaged or missing.',
          ),
        );
      }

      // Prefs must parse before any live data is touched: a malformed
      // prefs.json used to throw inside _restorePrefs, after the live
      // database was already wiped and replaced, so the restore
      // reported "failed" while the data was in fact replaced — and
      // the notification resync below never ran.
      final backupPrefs = await _readBackupPrefs(workDir);

      // Snapshot the reminder-bearing ids before the restore wipes
      // the tables — a wallet or debt the restore removes must stop
      // firing, and only a pre-restore list can name it.
      final prevPaylaterWalletIds = {
        for (final w in await db.select(db.wallets).get())
          if (w.kind == 'paylater') w.id,
      };
      final prevDebtIds = {
        for (final d in await db.select(db.debts).get()) d.id,
      };

      await _restoreDatabase(db, backupDb.path);
      await _restoreReceipts(db, workDir);
      // Prefs are cosmetic next to the ledger: a prefs failure must
      // never fail the restore or skip the notification resync below.
      try {
        await _restorePrefs(backupPrefs);
        await _pruneStaleRestorePrefs(db, backupPrefs);
      } catch (_) {
        debugPrint('BackupService: prefs restore failed; continuing');
      }
      // Reminders must reflect the restored data, not the pre-restore
      // state. Best-effort only — a notification failure must never
      // fail the restore itself (and the calls no-op entirely when
      // notifications were never initialized).
      try {
        await _resyncNotifications(
          db,
          prevPaylaterWalletIds: prevPaylaterWalletIds,
          prevDebtIds: prevDebtIds,
        );
      } catch (_) {
        // Best-effort only.
      }
    } finally {
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
    }
  }

  /// Brings due-date reminders in line with the restored data.
  ///
  /// Paylater: reschedule (or cancel) for every restored wallet via
  /// the shared helper, and cancel reminders for wallets the restore
  /// removed. Debts: same shape — reschedule with the restored
  /// person/amount/due date, cancel for debts that are paid, dateless,
  /// have reminders off, or are gone entirely. Mirrors the add/edit/
  /// swipe call sites (which all schedule with the full debt amount).
  static Future<void> _resyncNotifications(
    AppDatabase db, {
    required Set<int> prevPaylaterWalletIds,
    required Set<int> prevDebtIds,
  }) async {
    final wallets = await db.select(db.wallets).get();
    final currentPaylaterIds = <int>{};
    for (final w in wallets) {
      if (w.kind != 'paylater') continue;
      currentPaylaterIds.add(w.id);
      await syncPaylaterReminder(db, w.id);
    }
    for (final id in prevPaylaterWalletIds.difference(currentPaylaterIds)) {
      await NotificationService.cancelPaylaterReminder(id);
    }

    final debts = await db.select(db.debts).get();
    final currentDebtIds = <int>{};
    for (final d in debts) {
      currentDebtIds.add(d.id);
      if (!d.isPaid && d.dueDate != null && AppPrefs.debtReminders) {
        await NotificationService.scheduleDebtReminder(
          debtId: d.id,
          person: d.person,
          amount: d.amount,
          payable: d.direction == 'payable',
          dueDate: d.dueDate!,
        );
      } else {
        await NotificationService.cancelDebtReminder(d.id);
      }
    }
    for (final id in prevDebtIds.difference(currentDebtIds)) {
      await NotificationService.cancelDebtReminder(id);
    }
  }

  /// Copies every table from the backup file into the live database,
  /// matching columns by name so minor schema drift doesn't break the
  /// restore. The backup is read through its own read-only connection —
  /// no ATTACH/DETACH, so a failed restore can never leave the live
  /// database in a half-attached state.
  static Future<void> _restoreDatabase(
    AppDatabase db,
    String backupPath,
  ) async {
    final liveTables = {for (final t in db.allTables) t.actualTableName};
    final tables = _insertOrder.where(liveTables.contains).toList();

    final backup = sqlite3.open(backupPath, mode: OpenMode.readOnly);
    try {
      // Fail fast, before anything is deleted, if the core tables
      // every Dmoney database has are missing — a foreign SQLite
      // file with a forged manifest must not empty the live data.
      final present = {
        for (final r in backup.select(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        ))
          r['name'] as String,
      };
      const coreTables = {'accounts', 'wallets', 'categories', 'transactions'};
      if (!coreTables.every(present.contains)) {
        throw BackupException(
          localizedOrFallback(
            (l) => l.backupDatabaseCorrupt,
            'The database inside this backup is damaged or missing.',
          ),
        );
      }
      await db.transaction(() async {
        // Children first on the way out.
        for (final t in tables.reversed) {
          await db.customStatement('DELETE FROM "$t"');
        }
        for (final t in tables) {
          final liveCols = await _columns(db, t);
          final backupCols = [
            for (final r in backup.select('PRAGMA table_info("$t")'))
              r['name'] as String,
          ];
          final common = liveCols.where(backupCols.contains).toList();
          if (common.isEmpty) continue;
          final cols = common.map((c) => '"$c"').join(', ');
          final placeholders = List.filled(common.length, '?').join(', ');
          final rows = backup.select('SELECT $cols FROM "$t"');
          for (final row in rows) {
            final args = [for (final c in common) row[c]];
            await db.customStatement(
              'INSERT INTO "$t" ($cols) VALUES ($placeholders)',
              args,
            );
          }
        }
        // Keep autoincrement counters in sync.
        try {
          await db.customStatement('DELETE FROM sqlite_sequence');
          final seqRows = backup.select(
            'SELECT name, seq FROM sqlite_sequence',
          );
          for (final row in seqRows) {
            final name = row['name'] as String;
            final seq = row['seq'] as int;
            if (liveTables.contains(name)) {
              await db.customStatement(
                "INSERT INTO sqlite_sequence (name, seq) VALUES ('${_escape(name)}', $seq)",
              );
            }
          }
        } catch (_) {
          // Backup has no autoincrement counters — nothing to sync.
        }
        // Pre-v18 backups have no sync ids: their rows land with the
        // '' default, which would break the unique sync_id indexes
        // and leave the rows unsyncable. Backfill them now, inside
        // this transaction, before anything else reads the data.
        await db.backfillMissingSyncIds();
        // Sync state after a restore (P2 decision — concept doc §5):
        // the restored rows replace everything, so the pre-restore
        // outbox describes states that no longer exist. Clear it,
        // re-enqueue every restored row as the new seed, and reset
        // the pull cursor, all inside this transaction.
        await db.resetSyncAfterRestore();
        // Backups from before schema 17 have no plan_id column, so
        // every restored transaction lands unlinked — reconnect each
        // plan to its purchase (and payments) from their fingerprints
        // before this transaction commits.
        final backupTxCols = [
          for (final r in backup.select('PRAGMA table_info("transactions")'))
            r['name'] as String,
        ];
        if (!backupTxCols.contains('plan_id')) {
          await _backfillPlanLinks(db);
        }
      });
    } finally {
      backup.close();
    }

    // Raw SQL is invisible to drift's stream tracking — refresh manually.
    db.notifyUpdates({
      for (final t in db.allTables) TableUpdate(t.actualTableName),
    });
  }

  static Future<List<String>> _columns(AppDatabase db, String table) async {
    final rows = await db.customSelect('PRAGMA table_info("$table")').get();
    return [for (final r in rows) r.read<String>('name')];
  }

  /// Reconnects installment plans to their purchase expense (and
  /// installment payments) after restoring a backup whose transactions
  /// table predates the plan_id column (backups from before 2.7.2,
  /// schema older than 17). Without this, every restored plan loses its
  /// history and deleting a plan leaves its purchase orphaned.
  ///
  /// Matching is deliberately conservative. A purchase must be an
  /// expense on the plan's wallet for exactly the plan total, dated at
  /// or shortly before the plan was created — manual plans record the
  /// purchase under the plan's name, which wins ties. A payment must
  /// be a transfer into the plan wallet with the exact
  /// `Installment payment: <name>` note and the monthly amount, capped
  /// at the plan's paid count. Each transaction is claimed by at most
  /// one plan, so a wrong guess can at worst link a plan to a
  /// same-amount purchase — never duplicate a link. Plans with no
  /// matching purchase stay unlinked, exactly as before.
  static Future<void> _backfillPlanLinks(AppDatabase db) async {
    final plans = await db.select(db.installmentPlans).get();
    if (plans.isEmpty) return;
    final unlinked = (await db.select(db.transactions).get())
        .where((t) => t.planId == null)
        .toList();
    if (unlinked.isEmpty) return;
    final claimed = <int>{};

    Future<void> link(int transactionId, int planId) =>
        db.customStatement(
          'UPDATE "transactions" SET "plan_id" = ? WHERE "id" = ?',
          [planId, transactionId],
        );

    for (final plan in plans) {
      if (plan.totalAmount <= 0) continue;
      // --- purchase expense ---
      final purchases = unlinked.where((t) {
        if (t.kind != 'expense' ||
            t.walletId != plan.walletId ||
            t.amount != plan.totalAmount ||
            claimed.contains(t.id)) {
          return false;
        }
        // The purchase predates (or coincides with) the plan's
        // creation; allow an hour of clock skew the other way and up
        // to 90 days back for a backdated purchase.
        final age = plan.createdAt.difference(t.date);
        return age >= const Duration(hours: -1) &&
            age <= const Duration(days: 90);
      }).toList();
      if (purchases.isNotEmpty) {
        purchases.sort((a, b) {
          final aName = a.note == plan.name ? 0 : 1;
          final bName = b.note == plan.name ? 0 : 1;
          if (aName != bName) return aName - bName;
          final aAge = plan.createdAt.difference(a.date).abs();
          final bAge = plan.createdAt.difference(b.date).abs();
          return aAge.compareTo(bAge);
        });
        final purchase = purchases.first;
        claimed.add(purchase.id);
        await link(purchase.id, plan.id);
      }
      // --- installment payments ---
      if (plan.installmentAmount > 0 && plan.paidCount > 0) {
        final payments = unlinked
            .where(
              (t) =>
                  t.kind == 'transfer' &&
                  t.toWalletId == plan.walletId &&
                  t.amount == plan.installmentAmount &&
                  t.note == 'Installment payment: ${plan.name}' &&
                  !claimed.contains(t.id),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        for (final p in payments.take(plan.paidCount)) {
          claimed.add(p.id);
          await link(p.id, plan.id);
        }
      }
    }
  }

  static Future<void> _restoreReceipts(
    AppDatabase db,
    Directory workDir,
  ) async {
    final docs = await getApplicationDocumentsDirectory();
    final receipts = Directory('${docs.path}/receipts');
    final backupReceipts = Directory('${workDir.path}/receipts');
    // Stage the restored photos next to the live folder and swap
    // only once the new set is fully on disk — the old code deleted
    // every live receipt first, so a failure mid-copy lost them all.
    final staging = Directory('${docs.path}/receipts_staging');
    final oldDir = Directory('${docs.path}/receipts_old');
    // A leftover receipts_old means a previous swap was interrupted
    // after the live folder was moved aside. If the live folder is
    // back in place, the old set is stale — the live folder is
    // authoritative, delete it. If the live folder is missing, the
    // swap crashed mid-way: put the old photos back so the folder
    // exists again (the new set is staged below either way).
    if (await oldDir.exists()) {
      if (await receipts.exists()) {
        await oldDir.delete(recursive: true);
      } else {
        await oldDir.rename(receipts.path);
      }
    }
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    if (await backupReceipts.exists()) {
      await _copyDir(backupReceipts, staging);
    } else {
      await staging.create(recursive: true);
    }
    // Swap by renaming, never by deleting: move the live folder
    // aside first, so a crash between the two renames leaves the
    // old photos recoverable in receipts_old instead of deleted.
    if (await receipts.exists()) {
      await receipts.rename(oldDir.path);
    }
    try {
      await staging.rename(receipts.path);
    } catch (_) {
      // The restore failed — put the old photos back so the
      // previous live set survives.
      if (await oldDir.exists()) {
        await oldDir.rename(receipts.path);
      }
      rethrow;
    }
    // Best-effort cleanup of the superseded set; a failure here must
    // not fail the restore — a leftover receipts_old is stale but
    // harmless and is cleared at the start of the next restore.
    try {
      if (await oldDir.exists()) {
        await oldDir.delete(recursive: true);
      }
    } catch (_) {}
    // Photo paths are absolute — point them at this device's folder.
    final rows = await db
        .customSelect('SELECT id, path FROM transaction_photos')
        .get();
    for (final row in rows) {
      final id = row.read<int>('id');
      final fileName = row.read<String>('path').split('/').last;
      final newPath = '${docs.path}/receipts/$fileName';
      await db.customStatement(
        "UPDATE transaction_photos SET path = '${_escape(newPath)}' WHERE id = $id",
      );
    }
    if (rows.isNotEmpty) {
      db.notifyUpdates({TableUpdate('transaction_photos')});
    }
  }

  static Future<void> _copyDir(Directory src, Directory dst) async {
    await dst.create(recursive: true);
    await for (final entity in src.list(recursive: true)) {
      final rel = entity.path.substring(src.path.length + 1);
      if (entity is File) {
        final out = File('${dst.path}/$rel');
        await out.parent.create(recursive: true);
        await entity.copy(out.path);
      }
    }
  }

  /// Reads and validates the backup's prefs.json. Returns null when
  /// the backup has no prefs file (older backups). Throws
  /// [BackupException] when the file is not a JSON object — failing
  /// fast here, before any live data is touched.
  ///
  /// Individual bad values do NOT fail the file: they are dropped
  /// here, so a backup with one malformed prefs value still restores
  /// the data and the remaining prefs instead of refusing the whole
  /// restore for a cosmetic key.
  static Future<Map<String, dynamic>?> _readBackupPrefs(
    Directory workDir,
  ) async {
    final prefsFile = File('${workDir.path}/prefs.json');
    if (!await prefsFile.exists()) return null;
    final Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(await prefsFile.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw BackupException(
          localizedOrFallback(
            (l) => l.backupNotDmoneyFile,
            'Not a Dmoney Manager backup file.',
          ),
        );
      }
      map = decoded;
    } on BackupException {
      rethrow;
    } on FormatException {
      throw BackupException(
        localizedOrFallback(
          (l) => l.backupNotDmoneyFile,
          'Not a Dmoney Manager backup file.',
        ),
      );
    }
    final invalidKeys = <String>[];
    for (final key in map.keys.toList()) {
      if (!_isRestorablePrefValue(map[key])) {
        invalidKeys.add(key);
        map.remove(key);
      }
    }
    if (invalidKeys.isNotEmpty) {
      debugPrint('BackupService: dropping unrestorable prefs: $invalidKeys');
    }
    return map;
  }

  /// A prefs value is restorable only in the shapes
  /// SharedPreferences understands: bool, int, double, String, or a
  /// list of Strings. Anything else (null, nested objects, mixed
  /// lists) has no pref equivalent.
  static bool _isRestorablePrefValue(Object? value) {
    if (value is bool ||
        value is int ||
        value is double ||
        value is String) {
      return true;
    }
    if (value is List) return value.every((e) => e is String);
    return false;
  }

  /// Writes the backup's preferences over the live ones. Keys in the
  /// local-only set describe this device, not user data, and are
  /// never restored. Best-effort per key: one bad value (or a failed
  /// write) skips that key only, never the rest of the prefs.
  static Future<void> _restorePrefs(Map<String, dynamic>? map) async {
    if (map == null) return;
    final prefs = await SharedPreferences.getInstance();
    // These keys describe THIS device, not user data — restoring
    // them would resurrect a stale Drive account email and backup
    // timestamps over the current sign-in, or an old app-lock PIN
    // over a changed one (and lock the user out with a PIN they may
    // no longer remember). The lock switch itself belongs here too:
    // a backup made on a locked device must never enable the lock
    // on a device with no PIN, or the app boots to a lock screen
    // no passcode can open.
    const localOnlyKeys = {
      'drive_account_email',
      'drive_last_backup_at',
      'drive_auto_backup',
      'pinHash',
      'lockEnabled',
    };
    for (final entry in map.entries) {
      final key = entry.key;
      if (localOnlyKeys.contains(key)) continue;
      try {
        await _writePref(prefs, key, entry.value);
      } catch (_) {
        debugPrint('BackupService: skipping unrestorable pref $key');
      }
    }
  }

  static Future<void> _writePref(
    SharedPreferences prefs,
    String key,
    Object? value,
  ) async {
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is List) {
      // Only an all-string list is a valid StringList pref.
      if (value.every((e) => e is String)) {
        await prefs.setStringList(key, value.cast<String>());
      }
    }
    // Any other shape (null, nested object) has no pref equivalent
    // and is skipped.
  }

  /// _restorePrefs is additive-only, so keys the backup never
  /// mentions survive — and a few of them go stale against the
  /// restored data. Prune exactly those, nothing else:
  ///
  /// - The selected account must exist in the restored accounts
  ///   table. A backup made on "All accounts" has no
  ///   selectedAccountId key, so the device's old selection survives
  ///   — and if the restored database has no such account, every
  ///   account-scoped query comes back empty after a "successful"
  ///   restore.
  /// - Budget-alert flags (`budgetNotified_<id>_<month>_<level>`)
  ///   and the dismissed update version describe the old data; a
  ///   backup that doesn't mention them must not leave them
  ///   suppressing alerts or prompts for the restored data.
  static Future<void> _pruneStaleRestorePrefs(
    AppDatabase db,
    Map<String, dynamic>? backupPrefs,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final selectedId = prefs.getInt('selectedAccountId');
    if (selectedId != null) {
      final account = await (db.select(db.accounts)
            ..where((a) => a.id.equals(selectedId)))
          .getSingleOrNull();
      if (account == null) {
        await prefs.remove('selectedAccountId');
      }
    }

    if (backupPrefs == null) return;

    if (!backupPrefs.containsKey('dismissedUpdateVersion')) {
      await prefs.remove('dismissedUpdateVersion');
    }
    final staleFlags = prefs
        .getKeys()
        .where(
          (k) =>
              k.startsWith('budgetNotified_') &&
              !backupPrefs.containsKey(k),
        )
        .toList();
    for (final key in staleFlags) {
      await prefs.remove(key);
    }
  }

  static String _escape(String s) => s.replaceAll("'", "''");
}
