import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';

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
  static const _insertOrder = [
    'accounts',
    'wallets',
    'categories',
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
    await db.customStatement(
        "VACUUM INTO '${_escape(snapshotPath)}'");

    final archive = Archive();
    final dbBytes = await snapshotFile.readAsBytes();
    archive.addFile(ArchiveFile(
        'database.sqlite', dbBytes.length, dbBytes));

    final manifest = jsonEncode({
      'app': _appId,
      'format': _formatVersion,
      'schemaVersion': db.schemaVersion,
      'createdAt': DateTime.now().toIso8601String(),
    });
    final manifestBytes = utf8.encode(manifest);
    archive.addFile(ArchiveFile(
        'manifest.json', manifestBytes.length, manifestBytes));

    // Receipt photos.
    final docs = await getApplicationDocumentsDirectory();
    final receipts = Directory('${docs.path}/receipts');
    if (await receipts.exists()) {
      await for (final entity in receipts.list(recursive: true)) {
        if (entity is File) {
          final rel =
              entity.path.substring(receipts.path.length + 1);
          final bytes = await entity.readAsBytes();
          archive.addFile(ArchiveFile(
              'receipts/$rel', bytes.length, bytes));
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
    archive.addFile(
        ArchiveFile('prefs.json', prefsBytes.length, prefsBytes));

    final zipBytes = ZipEncoder().encode(archive)!;
    final out =
        File('${tmp.path}/dmoney-backup-$stamp.zip');
    await out.writeAsBytes(zipBytes);
    await snapshotFile.delete();
    return out;
  }

  /// Restores [zipFile] into the live database, replacing all current
  /// data. Throws [BackupException] on invalid files.
  static Future<void> restoreBackup(
      AppDatabase db, File zipFile) async {
    final tmp = await getTemporaryDirectory();
    final workDir = Directory(
        '${tmp.path}/dmoney_restore_${DateTime.now().millisecondsSinceEpoch}');
    try {
      await workDir.create(recursive: true);

      final archive =
          ZipDecoder().decodeBytes(await zipFile.readAsBytes());
      for (final entry in archive) {
        if (!entry.isFile) continue;
        final out = File('${workDir.path}/${entry.name}');
        await out.parent.create(recursive: true);
        await out.writeAsBytes(entry.content as List<int>);
      }

      final manifestFile = File('${workDir.path}/manifest.json');
      if (!await manifestFile.exists()) {
        throw BackupException('Not a Dmoney Manager backup file.');
      }
      final manifest =
          jsonDecode(await manifestFile.readAsString())
              as Map<String, dynamic>;
      if (manifest['app'] != _appId) {
        throw BackupException('Not a Dmoney Manager backup file.');
      }

      final backupDb = File('${workDir.path}/database.sqlite');
      if (!await backupDb.exists()) {
        throw BackupException('Backup is missing its database.');
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

  /// Copies every table from the backup file into the live database
  /// via ATTACH, matching columns by name so minor schema drift
  /// doesn't break the restore.
  static Future<void> _restoreDatabase(
      AppDatabase db, String backupPath) async {
    final liveTables = {
      for (final t in db.allTables) t.actualTableName
    };
    final tables =
        _insertOrder.where(liveTables.contains).toList();

    await db.transaction(() async {
      await db.customStatement(
          "ATTACH DATABASE '${_escape(backupPath)}' AS backup");
      try {
        // Children first on the way out.
        for (final t in tables.reversed) {
          await db.customStatement('DELETE FROM "$t"');
        }
        for (final t in tables) {
          final liveCols = await _columns(db, null, t);
          final backupCols = await _columns(db, 'backup', t);
          final common =
              liveCols.where(backupCols.contains).toList();
          if (common.isEmpty) continue;
          final cols = common.map((c) => '"$c"').join(', ');
          await db.customStatement(
              'INSERT INTO "$t" ($cols) SELECT $cols FROM backup."$t"');
        }
        // Keep autoincrement counters in sync.
        try {
          await db.customStatement('DELETE FROM sqlite_sequence');
          final seqRows = await db
              .customSelect(
                  'SELECT name, seq FROM backup.sqlite_sequence')
              .get();
          for (final row in seqRows) {
            final name = row.read<String>('name');
            final seq = row.read<int>('seq');
            if (liveTables.contains(name)) {
              await db.customStatement(
                  "INSERT INTO sqlite_sequence (name, seq) VALUES ('${_escape(name)}', $seq)");
            }
          }
        } catch (_) {
          // Backup has no autoincrement counters — nothing to sync.
        }
      } finally {
        await db.customStatement('DETACH DATABASE backup');
      }
    });

    // Raw SQL is invisible to drift's stream tracking — refresh manually.
    db.notifyUpdates({
      for (final t in db.allTables) TableUpdate(t.actualTableName),
    });
  }

  static Future<List<String>> _columns(
      AppDatabase db, String? schema, String table) async {
    final prefix = schema == null ? '' : '$schema.';
    final rows = await db
        .customSelect('PRAGMA ${prefix}table_info("$table")')
        .get();
    return [for (final r in rows) r.read<String>('name')];
  }

  static Future<void> _restoreReceipts(
      AppDatabase db, Directory workDir) async {
    final docs = await getApplicationDocumentsDirectory();
    final receipts = Directory('${docs.path}/receipts');
    if (await receipts.exists()) {
      await receipts.delete(recursive: true);
    }
    final backupReceipts = Directory('${workDir.path}/receipts');
    if (await backupReceipts.exists()) {
      await _copyDir(backupReceipts, receipts);
    }
    // Photo paths are absolute — point them at this device's folder.
    final rows = await db
        .customSelect('SELECT id, path FROM transaction_photos')
        .get();
    for (final row in rows) {
      final id = row.read<int>('id');
      final fileName = row.read<String>('path').split('/').last;
      final newPath = '${docs.path}/receipts/$fileName';
      await db.customStatement(
          "UPDATE transaction_photos SET path = '${_escape(newPath)}' WHERE id = $id");
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
    final map = jsonDecode(await prefsFile.readAsString())
        as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    for (final entry in map.entries) {
      final key = entry.key;
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
