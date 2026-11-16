import 'dart:convert';

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

  group('resumableChunkRanges', () {
    test('empty file has no chunks', () {
      expect(DriveBackupService.resumableChunkRanges(0), isEmpty);
    });

    test('single partial chunk', () {
      expect(
        DriveBackupService.resumableChunkRanges(100),
        [(start: 0, end: 99)],
      );
    });

    test('exact multiples split evenly', () {
      const chunk = DriveBackupService.resumableChunkSize;
      expect(
        DriveBackupService.resumableChunkRanges(2 * chunk),
        [(start: 0, end: chunk - 1), (start: chunk, end: 2 * chunk - 1)],
      );
    });

    test('remainder goes in a final short chunk', () {
      expect(
        DriveBackupService.resumableChunkRanges(600000),
        [
          (start: 0, end: 262143),
          (start: 262144, end: 524287),
          (start: 524288, end: 599999),
        ],
      );
    });

    test('custom chunk size is honored', () {
      expect(
        DriveBackupService.resumableChunkRanges(25, chunkSize: 10),
        [(start: 0, end: 9), (start: 10, end: 19), (start: 20, end: 24)],
      );
    });

    test('ranges are contiguous and cover every byte', () {
      const total = 1000000;
      final ranges = DriveBackupService.resumableChunkRanges(total);
      expect(ranges.first.start, 0);
      expect(ranges.last.end, total - 1);
      for (var i = 1; i < ranges.length; i++) {
        expect(ranges[i].start, ranges[i - 1].end + 1);
      }
    });
  });

  group('resumeOffsetFromRangeHeader', () {
    test('missing or empty header means nothing received', () {
      expect(DriveBackupService.resumeOffsetFromRangeHeader(null), 0);
      expect(DriveBackupService.resumeOffsetFromRangeHeader(''), 0);
    });

    test('next byte after the received range', () {
      expect(
          DriveBackupService.resumeOffsetFromRangeHeader('bytes=0-262143'),
          262144);
      expect(
          DriveBackupService.resumeOffsetFromRangeHeader('bytes=0-0'), 1);
      expect(
          DriveBackupService.resumeOffsetFromRangeHeader('bytes=0-524287'),
          524288);
    });

    test('malformed header restarts from zero', () {
      expect(DriveBackupService.resumeOffsetFromRangeHeader('garbage'), 0);
      expect(DriveBackupService.resumeOffsetFromRangeHeader('bytes=0-'), 0);
      expect(DriveBackupService.resumeOffsetFromRangeHeader('bytes=-5'), 0);
    });
  });

  group('resumableInitRequest', () {
    test('create: new file in appDataFolder with name and length', () {
      final req = DriveBackupService.resumableInitRequest(
        name: 'dmoney-backup-2026-11-16T09-00-00.zip',
        totalBytes: 1234567,
      );
      expect(req.uri.host, 'www.googleapis.com');
      expect(req.uri.path, '/upload/drive/v3/files');
      expect(req.uri.queryParameters['uploadType'], 'resumable');
      expect(req.uri.queryParameters['fields'],
          'id,name,createdTime,modifiedTime,size');
      expect(req.headers['X-Upload-Content-Type'], 'application/zip');
      expect(req.headers['X-Upload-Content-Length'], '1234567');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['name'], 'dmoney-backup-2026-11-16T09-00-00.zip');
      expect(body['parents'], ['appDataFolder']);
      expect(body['mimeType'], 'application/zip');
    });

    test('update: targets the existing file, no parents or name', () {
      final req = DriveBackupService.resumableInitRequest(
        fileId: 'abc123',
        totalBytes: 42,
      );
      expect(req.uri.path, '/upload/drive/v3/files/abc123');
      expect(req.uri.queryParameters['uploadType'], 'resumable');
      expect(req.headers['X-Upload-Content-Length'], '42');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['mimeType'], 'application/zip');
      expect(body.containsKey('parents'), isFalse);
      expect(body.containsKey('name'), isFalse);
    });
  });
}
