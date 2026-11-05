import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../data/database/app_database.dart';
import '../utils/app_locale.dart';

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
  static Future<File> createBackup(AppDatabase db) async {
    final tmp = await getTemporaryDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;

    // A consistent snapshot while the database stays open.
    final snapshotPath = '${tmp.path}/dmoney_snapshot.sqlite';
    final snapshotFile = File(snapshotPath);
    if (await snapshotFile.exists()) await snapshotFile.delete();
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
    final out = File('${tmp.path}/dmoney-backup-$stamp.zip');
    await out.writeAsBytes(zipBytes);
    await snapshotFile.delete();
    return out;
  }

  /// Restores [zipFile] into the live database, replacing all current
  /// data. Throws [BackupException] on invalid files.
  static Future<void> restoreBackup(AppDatabase db, File zipFile) async {
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

      await _restoreDatabase(db, backupDb.path);
      await _restoreReceipts(db, workDir);
      await _restorePrefs(workDir);
    } finally {
      if (await workDir.exists()) {
        await workDir.delete(recursive: true);
      }
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
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    if (await backupReceipts.exists()) {
      await _copyDir(backupReceipts, staging);
    } else {
      await staging.create(recursive: true);
    }
    if (await receipts.exists()) {
      await receipts.delete(recursive: true);
    }
    await staging.rename(receipts.path);
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

  static Future<void> _restorePrefs(Directory workDir) async {
    final prefsFile = File('${workDir.path}/prefs.json');
    if (!await prefsFile.exists()) return;
    final map =
        jsonDecode(await prefsFile.readAsString()) as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    // These keys describe THIS device's Drive link, not user data —
    // restoring them would resurrect a stale account email and
    // backup timestamps over the current sign-in.
    const localOnlyKeys = {
      'drive_account_email',
      'drive_last_backup_at',
      'drive_auto_backup',
    };
    for (final entry in map.entries) {
      final key = entry.key;
      if (localOnlyKeys.contains(key)) continue;
      final value = entry.value;
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is List) {
        await prefs.setStringList(key, value.cast<String>());
      }
    }
  }

  static String _escape(String s) => s.replaceAll("'", "''");
}
