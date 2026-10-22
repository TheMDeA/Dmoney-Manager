import 'package:flutter_test/flutter_test.dart';
import 'package:dmoney_manager/core/services/drive_backup_service.dart';

DriveBackup _b(String id, String createdIso) => DriveBackup(
      id: id,
      name: 'dmoney-backup-$id.zip',
      createdAt: DateTime.parse(createdIso),
      sizeBytes: 100,
    );

void main() {
  group('backupFileName', () {
    test('uses the local backup stamp format', () {
      final name =
          DriveBackupService.backupFileName(DateTime(2026, 10, 22, 9, 50, 3));
      expect(name, 'dmoney-backup-2026-10-22T09-50-03.zip');
    });
  });

  group('backupsToPrune', () {
    test('nothing to prune at or below the keep count', () {
      final backups = [_b('a', '2026-10-20'), _b('b', '2026-10-21')];
      expect(DriveBackupService.backupsToPrune(backups, keep: 5), isEmpty);
      expect(DriveBackupService.backupsToPrune(backups, keep: 2), isEmpty);
    });

    test('prunes the oldest beyond the keep count regardless of order', () {
      final backups = [
        _b('mid', '2026-10-21'),
        _b('newest', '2026-10-22'),
        _b('oldest', '2026-10-19'),
        _b('old', '2026-10-20'),
      ];
      final prune = DriveBackupService.backupsToPrune(backups, keep: 2);
      expect(prune.map((b) => b.id), ['old', 'oldest']);
    });
  });

  group('findAutoBackup', () {
    test('finds the fixed-name auto file among manual backups', () {
      final backups = [
        _b('a', '2026-10-21'),
        DriveBackup(
          id: 'auto',
          name: DriveBackupService.autoFileName,
          createdAt: DateTime.parse('2026-10-22'),
          sizeBytes: 10,
        ),
      ];
      expect(DriveBackupService.findAutoBackup(backups)?.id, 'auto');
    });

    test('null when no auto file exists', () {
      expect(
          DriveBackupService.findAutoBackup([_b('a', '2026-10-21')]),
          isNull);
    });
  });

  group('DriveBackup.fromJson', () {
    test('parses id, name, createdTime and string size', () {
      final b = DriveBackup.fromJson({
        'id': 'xyz',
        'name': 'dmoney-backup-2026-10-22T09-50-03.zip',
        'createdTime': '2026-10-22T01:50:03.000Z',
        'size': '2048',
      });
      expect(b.id, 'xyz');
      expect(b.sizeBytes, 2048);
      expect(b.createdAt, DateTime.parse('2026-10-22T01:50:03.000Z'));
    });

    test('prefers modifiedTime over createdTime (overwritten files)', () {
      final b = DriveBackup.fromJson({
        'id': 'x',
        'name': 'n',
        'createdTime': '2026-10-20T01:00:00.000Z',
        'modifiedTime': '2026-10-22T01:00:00.000Z',
      });
      expect(b.createdAt, DateTime.parse('2026-10-22T01:00:00.000Z'));
    });

    test('missing size and bad date fall back safely', () {
      final b = DriveBackup.fromJson({'id': 'x', 'name': 'n'});
      expect(b.sizeBytes, 0);
      expect(b.createdAt.millisecondsSinceEpoch, 0);
    });
  });
}
