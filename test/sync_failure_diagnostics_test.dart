/// Failure diagnostics (audit round 2, #15/#18/#25/#27): per-row
/// failures name their row, a missing photo file parks instead of
/// wedging the queue, tombstones carry owner_id, and the log
/// records duration/phase/skipped/first-failing-row.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/services/sync_dead_letters_service.dart';
import 'package:dmoney_manager/core/services/sync_orchestrator.dart';
import 'package:dmoney_manager/core/services/sync_photos.dart';
import 'package:dmoney_manager/core/services/sync_push_service.dart';
import 'package:dmoney_manager/core/services/sync_remote.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sync_diag_test');
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => root.path,
        );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await AppPrefs.init();
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(name: 'Personal', kind: 'personal'),
    );
  });

  tearDown(() async {
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<int> makeWallet(String name) => db.createWallet(
    accountId: 1,
    name: name,
    kind: 'cash',
  );

  Future<int> foodId() async {
    final cats = await db.select(db.categories).get();
    return cats.firstWhere((c) => c.name == 'Food').id;
  }

  Future<int> addExpense(int walletId, int amount) async => db.addTransaction(
    TransactionsCompanion.insert(
      walletId: walletId,
      categoryId: await foodId(),
      kind: 'expense',
      amount: amount,
      date: DateTime(2026, 11, 1),
    ),
  );

  Future<int> outboxCount() async =>
      (await db.select(db.syncOutbox).get()).length;

  Future<List<SyncDeadLetter>> deadLetters() =>
      db.select(db.syncDeadLetters).get();

  group('#27 tombstone owner_id', () {
    test('tombstone carries the owner id', () async {
      final remote = _DiagFakeRemote();
      final wallet = await makeWallet('Cash');
      final syncId = (await db.getWalletById(wallet))!.syncId;
      await SyncPushService(
        db: db,
        remote: remote,
        ownerId: 'test-owner',
      ).pushNow();
      expect(await outboxCount(), 0);

      expect(await db.deleteWallet(wallet), isTrue);
      final result = await SyncPushService(
        db: db,
        remote: remote,
        ownerId: 'test-owner',
      ).pushNow();

      expect(result.pushed, 1);
      expect(remote.tombstones, hasLength(1));
      expect(remote.tombstones.single.table, 'wallets');
      expect(remote.tombstones.single.syncIds, [syncId]);
      expect(remote.tombstones.single.ownerId, 'test-owner');
    });
  });

  group('#18 missing photo file parks as a dead letter', () {
    Future<({String photoSyncId, String storedPath})> addPhotoWithFile(
      int txId,
    ) async {
      final src = File('${root.path}/src.jpg')..writeAsBytesSync([1, 2, 3]);
      final storedPath = await db.addPhoto(txId, src.path);
      final photo = await (db.select(
        db.transactionPhotos,
      )..where((p) => p.path.equals(storedPath))).getSingle();
      return (photoSyncId: photo.syncId, storedPath: storedPath);
    }

    test('missing file parks the entry instead of failing the run',
        () async {
      final remote = _DiagFakeRemote();
      final wallet = await makeWallet('Cash');
      final txId = await addExpense(wallet, 5000);
      final photo = await addPhotoWithFile(txId);
      // The file is gone (backup restore without the receipt, app
      // storage cleared) — the row and its outbox entry remain.
      await File(photo.storedPath).delete();

      final result = await SyncPushService(
        db: db,
        remote: remote,
        ownerId: 'test-owner',
        photoGate: _AlwaysWifiGate(),
      ).pushNow();

      // Wallet + expense pushed; the photo parked, not failed.
      expect(result.pushed, 2);
      expect(result.failed, 0);
      expect(result.hasFailures, isFalse);
      expect(result.skippedMissingFiles, 1);
      expect(await outboxCount(), 0);
      final letters = await deadLetters();
      expect(letters, hasLength(1));
      expect(letters.single.targetTable, 'transaction_photos');
      expect(letters.single.syncId, photo.photoSyncId);
      expect(letters.single.reason, 'photo_file_missing');
      // The photo row itself stays local.
      expect(await db.select(db.transactionPhotos).get(), hasLength(1));

      // A second cycle does not re-fail or duplicate the letter.
      final again = await SyncPushService(
        db: db,
        remote: remote,
        ownerId: 'test-owner',
        photoGate: _AlwaysWifiGate(),
      ).pushNow();
      expect(again.failed, 0);
      expect(await deadLetters(), hasLength(1));
    });

    test('retry re-queues once the file is back, delete removes it',
        () async {
      final remote = _DiagFakeRemote();
      final wallet = await makeWallet('Cash');
      final txId = await addExpense(wallet, 5000);
      final photo = await addPhotoWithFile(txId);
      await File(photo.storedPath).delete();
      final pusher = SyncPushService(
        db: db,
        remote: remote,
        ownerId: 'test-owner',
        photoGate: _AlwaysWifiGate(),
      );
      await pusher.pushNow();
      final service = SyncDeadLetterService(db);
      var letter = (await deadLetters()).single;

      // Still missing: stays parked.
      expect(
        await service.retryDeadLetter(letter),
        SyncDeadLetterService.retryStillMissing,
      );
      expect(await deadLetters(), hasLength(1));

      // The file reappears (backup restore): retry re-queues.
      await File(photo.storedPath).writeAsBytes([1, 2, 3]);
      expect(
        await service.retryDeadLetter(letter),
        SyncDeadLetterService.retryQueued,
      );
      expect(await deadLetters(), isEmpty);
      expect(await outboxCount(), 1);
      final result = await pusher.pushNow();
      expect(result.failed, 0);
      expect(result.pushed, 1);
      expect(await outboxCount(), 0);
      expect(remote.uploadCalls, 1);

      // Park it again, then delete the photo instead.
      final photo2 = await addPhotoWithFile(txId);
      await File(photo2.storedPath).delete();
      await pusher.pushNow();
      letter = (await deadLetters()).single;
      await service.deleteDeadLetterPhoto(letter);
      expect(await deadLetters(), isEmpty);
      expect(await db.select(db.transactionPhotos).get(), hasLength(1));
      // The delete entry drops without a tombstone: the server
      // never saw the photo.
      final dropped = await pusher.pushNow();
      expect(dropped.droppedNeverPushed, 1);
      expect(await outboxCount(), 0);
    });
  });

  group('#15 per-row failures are named', () {
    test('push records the first failing row', () async {
      final remote = _DiagFakeRemote()..failUpserts = true;
      final walletA = await makeWallet('Cash');
      await makeWallet('Bank');
      final syncIdA = (await db.getWalletById(walletA))!.syncId;

      final result = await SyncPushService(
        db: db,
        remote: remote,
        ownerId: 'test-owner',
      ).pushNow();

      expect(result.failed, 2);
      expect(result.hasFailures, isTrue);
      expect(result.error, isNull);
      final first = result.firstFailure;
      expect(first, isNotNull);
      expect(first!.table, 'wallets');
      expect(first.syncId, syncIdA);
      expect(first.message, contains('upsert failed'));
    });

    test('orchestrator stores a partial mode and names the row',
        () async {
      final remote = _DiagFakeRemote()..failUpserts = true;
      final orchestrator = SyncOrchestrator(
        db: db,
        remote: remote,
        currentUserId: () => 'test-owner',
      );

      final result = await orchestrator.syncNow();

      expect(result.hasFailures, isTrue);
      expect(result.error, isNull);
      expect(AppPrefs.syncFailureMode, 'partial');
      final lastError = AppPrefs.syncLastError;
      expect(lastError, isNotNull);
      expect(lastError, isNotEmpty);
      expect(lastError, contains('/'));
      final logs = await db.select(db.syncLog).get();
      expect(logs, hasLength(1));
      final log = logs.single;
      expect(log.failed, greaterThan(0));
      expect(log.failureMode, 'partial');
      expect(log.error, lastError);
      expect(log.firstFailedTable, isNotNull);
      expect(log.firstFailedSyncId, isNotNull);
      expect(log.durationMs, isNotNull);
      expect(log.phase, 'both');
    });
  });

  group('#25 log diagnostics', () {
    test('recordSyncLog stores duration, phase, skipped and first failure',
        () async {
      await db.recordSyncLog(
        pushed: 3,
        pulled: 2,
        conflicts: 0,
        failed: 1,
        failureMode: 'partial',
        error: 'wallets/abc: upsert failed',
        durationMs: 123,
        phase: 'both',
        skipped: 2,
        firstFailedTable: 'wallets',
        firstFailedSyncId: 'abc',
      );
      final rows = await db.select(db.syncLog).get();
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.pushed, 3);
      expect(row.pulled, 2);
      expect(row.failed, 1);
      expect(row.failureMode, 'partial');
      expect(row.durationMs, 123);
      expect(row.phase, 'both');
      expect(row.skipped, 2);
      expect(row.firstFailedTable, 'wallets');
      expect(row.firstFailedSyncId, 'abc');
    });
  });
}

class _AlwaysWifiGate implements PhotoUploadGate {
  @override
  Future<bool> get canUploadPhotos async => true;
}

/// Minimal fake remote: records upserts, tombstones (with the
/// owner id) and photo uploads; optionally fails every upsert
/// with a data error (not a fatal one) so the push's per-row
/// fallback runs.
class _DiagFakeRemote implements SyncRemote {
  final upserts = <({String table, List<Map<String, dynamic>> rows})>[];
  final tombstones =
      <({String table, List<String> syncIds, String ownerId})>[];
  // Server rows (sync id → last upserted payload), so fetchRow
  // answers like the real server: a row the push sent is present,
  // anything else is missing.
  final serverRows = <String, Map<String, dynamic>>{};
  int uploadCalls = 0;
  bool failUpserts = false;

  @override
  Future<void> upsert(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    if (failUpserts) throw Exception('upsert failed');
    upserts.add((table: table, rows: rows));
    for (final row in rows) {
      serverRows[row['sync_id'] as String] = row;
    }
  }

  @override
  Future<void> tombstone(
    String table,
    List<String> syncIds,
    DateTime deletedAt,
    String ownerId,
  ) async {
    tombstones.add((table: table, syncIds: syncIds, ownerId: ownerId));
  }

  @override
  Future<List<Map<String, dynamic>>> pull(
    String table,
    String? updatedAfter,
    int offset,
    int limit,
  ) async => [];

  @override
  Future<void> uploadPhoto(String key, File file) async {
    uploadCalls++;
  }

  @override
  Future<Uint8List> downloadPhoto(String key) async => Uint8List(0);

  @override
  Future<void> deletePhotoObject(String key) async {}

  @override
  Future<Map<String, dynamic>?> fetchRow(
    String table,
    String syncId,
  ) async => serverRows[syncId];

  @override
  Future<int> countRows(String table) async => 0;

  @override
  Future<void> upsertDevice(Map<String, dynamic> row) async {}

  @override
  Future<List<Map<String, dynamic>>> listDevices() async => [];

  @override
  Future<Map<String, dynamic>?> fetchPrefs() async => null;

  @override
  Future<void> upsertPrefs(Map<String, dynamic> row) async {}

  @override
  Future<ServerWipeResult> wipeServerData(List<String> photoKeys) async =>
      const ServerWipeResult(deletedRows: {}, photosRemoved: 0, photosAttempted: 0);
}
