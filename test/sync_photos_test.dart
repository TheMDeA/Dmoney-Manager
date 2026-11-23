import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/services/sync_photos.dart';
import 'package:dmoney_manager/core/services/sync_pull_service.dart';
import 'package:dmoney_manager/core/services/sync_push_service.dart';
import 'package:dmoney_manager/core/services/sync_remote.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// P4 photos to Storage (schema v18): the bytes upload to the
/// `receipts` bucket on Wi-Fi only, the row upserts with the
/// Storage object key, pull applies photo rows with lazy download,
/// and deletes remove the object. No real network in these tests —
/// a fake [SyncRemote] holds the objects in memory, and a fake
/// gate drives the Wi-Fi check without a radio.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sync_photos_test');
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => root.path,
        );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await AppPrefs.init();
    // The seed only creates categories — no account exists in a
    // fresh test DB, so wallets made against account id 1 would
    // dangle. Insert the default account directly (no outbox
    // entry, like the seeded categories); it takes id 1.
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

  /// Canonical server timestamp, ordered by [minute].
  String ts(int minute) =>
      '2026-11-23T10:${minute.toString().padLeft(2, '0')}:00.000Z';

  Future<int> makeWallet(
    String name,
    String kind, {
    int accountId = 1,
    int initialAmount = 0,
  }) => db.createWallet(
    accountId: accountId,
    name: name,
    kind: kind,
    initialAmount: initialAmount,
  );

  Future<int> foodId() async {
    final cats = await db.select(db.categories).get();
    return cats.firstWhere((c) => c.name == 'Food').id;
  }

  Future<String> categorySyncId(int categoryId) async {
    final row = await db.customSelect(
      'SELECT sync_id FROM "categories" WHERE id = ?',
      variables: [Variable.withInt(categoryId)],
      readsFrom: {},
    ).getSingle();
    return row.read<String>('sync_id');
  }

  Future<int> addExpense(int walletId, int categoryId, int amount) =>
      db.addTransaction(
        TransactionsCompanion.insert(
          walletId: walletId,
          categoryId: categoryId,
          kind: 'expense',
          amount: amount,
          date: DateTime(2026, 11, 1),
        ),
      );

  Future<List<SyncOutboxData>> outbox() => db.select(db.syncOutbox).get();

  Future<int> outboxCount() async => (await outbox()).length;

  Future<String?> pullCursor() async =>
      (await db.select(db.syncState).getSingle()).lastPullCursor;

  SyncPushService pusher(FakePhotoRemote remote, FakePhotoUploadGate gate) =>
      SyncPushService(
        db: db,
        remote: remote,
        ownerId: 'test-owner',
        photoGate: gate,
      );

  SyncPullService puller(FakePhotoRemote remote) =>
      SyncPullService(db: db, remote: remote, ownerId: 'test-owner');

  /// Creates a wallet + expense + one photo (real bytes on disk)
  /// and returns the photo row's sync id and local stored path.
  Future<({String photoSyncId, String storedPath, String txSyncId})>
  addPhotoWithFile() async {
    final wallet = await makeWallet('Cash', 'cash');
    final txId = await addExpense(wallet, await foodId(), 5000);
    final txSyncId =
        (await (db.select(
          db.transactions,
        )..where((t) => t.id.equals(txId))).getSingle()).syncId;
    final src = File('${root.path}/src.jpg')..writeAsBytesSync([1, 2, 3]);
    final storedPath = await db.addPhoto(txId, src.path);
    final photo = (await db.select(db.transactionPhotos).get()).single;
    return (
      photoSyncId: photo.syncId,
      storedPath: storedPath,
      txSyncId: txSyncId,
    );
  }

  // -- canned server rows (snake_case, as PostgREST returns them) --

  Map<String, dynamic> accountRow(
    String syncId,
    String timestamp, {
    String name = 'Personal',
    String? deletedAt,
  }) => {
    'sync_id': syncId,
    'owner_id': 'test-owner',
    'server_updated_at': timestamp,
    'deleted_at': deletedAt,
    'name': name,
    'kind': 'personal',
    'color_hex': '#C6FF4A',
  };

  Map<String, dynamic> walletRow(
    String syncId,
    String accountSyncId,
    String timestamp, {
    String name = 'Cash',
    String kind = 'cash',
    int initialAmount = 0,
    int balance = 0,
    String? deletedAt,
  }) => {
    'sync_id': syncId,
    'owner_id': 'test-owner',
    'server_updated_at': timestamp,
    'deleted_at': deletedAt,
    'account_id': accountSyncId,
    'name': name,
    'kind': kind,
    'balance': balance,
    'initial_amount': initialAmount,
    'color_hex': '#C6FF4A',
    'logo_template': null,
    'sort_order': 0,
    'credit_limit': null,
    'statement_day': null,
    'due_day': null,
    'interest_rate_monthly': null,
    'interest_rate_annual': null,
  };

  Map<String, dynamic> txRow(
    String syncId,
    String walletSyncId,
    String categorySyncId,
    String timestamp, {
    String kind = 'expense',
    int amount = 5000,
    String note = '',
    String? deletedAt,
    String date = '2026-11-01T00:00:00.000Z',
  }) => {
    'sync_id': syncId,
    'owner_id': 'test-owner',
    'server_updated_at': timestamp,
    'deleted_at': deletedAt,
    'wallet_id': walletSyncId,
    'category_id': categorySyncId,
    'kind': kind,
    'amount': amount,
    'note': note,
    'memo': '',
    'date': date,
    'created_at': date,
    'to_wallet_id': null,
    'debt_id': null,
    'debt_payment_id': null,
    'recurring_id': null,
    'transfer_id': null,
    'plan_id': null,
  };

  Map<String, dynamic> photoRow(
    String syncId,
    String txSyncId,
    String timestamp, {
    String? deletedAt,
  }) => {
    'sync_id': syncId,
    'owner_id': 'test-owner',
    'server_updated_at': timestamp,
    'deleted_at': deletedAt,
    'transaction_id': txSyncId,
    'path': 'receipts/test-owner/$txSyncId/$syncId.jpg',
  };

  /// Seeds the parent chain a photo row needs to apply: account,
  /// wallet, transaction (the photo itself is seeded per test).
  Future<void> seedParents(
    FakePhotoRemote remote,
    String txSyncId,
  ) async {
    remote.seed('accounts', [accountRow('srv-account-1', ts(1))]);
    remote.seed('wallets', [
      walletRow('srv-wallet-1', 'srv-account-1', ts(2)),
    ]);
    final foodSync = await categorySyncId(await foodId());
    remote.seed('transactions', [
      txRow(txSyncId, 'srv-wallet-1', foodSync, ts(15)),
    ]);
  }

  group('push: upload + Wi-Fi gate', () {
    test('upload key mapping + upsert with the key', () async {
      final remote = FakePhotoRemote();
      final gate = FakePhotoUploadGate(true);
      final photo = await addPhotoWithFile();

      final result = await pusher(remote, gate).pushNow();

      // 3 entries: wallet + expense + photo.
      expect(result.pushed, 3);
      expect(result.failed, 0);
      final key =
          'receipts/test-owner/${photo.txSyncId}/${photo.photoSyncId}.jpg';
      expect(key, photoObjectKey('test-owner', photo.txSyncId, photo.photoSyncId));
      expect(remote.objects[key], [1, 2, 3]);
      expect(remote.uploadCalls, 1);
      final photoUpsert = remote.upserts
          .firstWhere((u) => u.table == 'transaction_photos')
          .rows
          .single;
      expect(photoUpsert['path'], key);
      expect(photoUpsert['transaction_id'], photo.txSyncId);
      expect(
        (await db.select(db.transactionPhotos).get()).single.remoteKey,
        key,
      );
      expect(await outboxCount(), 0);
    });

    test('off Wi-Fi the photo entry stays queued and other rows still push',
        () async {
      final remote = FakePhotoRemote();
      final gate = FakePhotoUploadGate(false);
      await addPhotoWithFile();

      final offResult = await pusher(remote, gate).pushNow();

      expect(offResult.skippedPhotos, 1);
      expect(offResult.pushed, 2); // wallet + expense
      expect(offResult.failed, 0);
      expect(remote.uploadCalls, 0);
      expect(await outboxCount(), 1);
      expect((await outbox()).single.targetTable, 'transaction_photos');

      gate.onWifi = true;
      final onResult = await pusher(remote, gate).pushNow();

      expect(onResult.pushed, 1);
      expect(remote.uploadCalls, 1);
      expect(await outboxCount(), 0);
    });

    test('missing local file leaves the entry queued and fails only that entry',
        () async {
      final remote = FakePhotoRemote();
      final gate = FakePhotoUploadGate(true);
      final photo = await addPhotoWithFile();
      await File(photo.storedPath).delete();

      final result = await pusher(remote, gate).pushNow();

      expect(result.pushed, 2); // wallet + expense still push
      expect(result.failed, 1); // the photo entry, unsettled
      expect(remote.uploadCalls, 0);
      expect(await outboxCount(), 1);
      expect((await outbox()).single.targetTable, 'transaction_photos');
      // The row itself is untouched — sync never drops a photo.
      expect(await db.select(db.transactionPhotos).get(), hasLength(1));

      // The file reappears (e.g. after a backup restore) — the
      // next push uploads it.
      await File(photo.storedPath).writeAsBytes([1, 2, 3]);
      final retry = await pusher(remote, gate).pushNow();
      expect(retry.pushed, 1);
      expect(retry.failed, 0);
      expect(await outboxCount(), 0);
    });

    test('a fatal error during the upload aborts the run', () async {
      final remote = FakePhotoRemote()..fatalNextCount = 1;
      final gate = FakePhotoUploadGate(true);
      await addPhotoWithFile();

      final result = await pusher(remote, gate).pushNow();

      expect(result.error, isNotNull);
      expect(result.failed, 3); // nothing settled — the run aborted
      expect(await outboxCount(), 3);
      expect(remote.upserts, isEmpty);
    });

    test('no re-upload when the key is already set, across a restore reset',
        () async {
      final remote = FakePhotoRemote();
      final gate = FakePhotoUploadGate(true);
      await addPhotoWithFile();

      await pusher(remote, gate).pushNow();
      expect(remote.uploadCalls, 1);
      expect(await outboxCount(), 0);

      // A backup restore re-enqueues every row as an insert
      // (and clears the pushed hashes).
      await db.resetSyncAfterRestore();
      expect(await outboxCount(), greaterThan(0));

      final result = await pusher(remote, gate).pushNow();
      expect(remote.uploadCalls, 1); // the bytes are already there
      expect(result.failed, 0);
      expect(await outboxCount(), 0);
    });
  });

  group('pull: lazy download', () {
    test('lazy download on viewer miss, cached on the second view',
        () async {
      final remote = FakePhotoRemote();
      remote.objects['receipts/test-owner/srv-tx-1/srv-photo-1.jpg'] =
          Uint8List.fromList([9, 8, 7]);
      await seedParents(remote, 'srv-tx-1');
      remote.seed('transaction_photos', [
        photoRow('srv-photo-1', 'srv-tx-1', ts(16)),
      ]);

      final pullResult = await puller(remote).pullNow();

      expect(pullResult.applied, 4);
      expect(pullResult.failed, 0);
      // The photo row does not hold the cursor back.
      expect(await pullCursor(), ts(16));
      final photo = (await db.select(db.transactionPhotos).get()).single;
      expect(await File(photo.path).exists(), isFalse);

      final service = SyncPhotoService(db: db, remote: remote);
      expect(await service.ensureLocalFile(photo), isTrue);
      expect(await File(photo.path).readAsBytes(), [9, 8, 7]);
      expect(remote.downloadCalls, 1);

      // Second view: the file is there, no second download.
      expect(await service.ensureLocalFile(photo), isTrue);
      expect(remote.downloadCalls, 1);

      // A missing object is "unavailable", not an exception —
      // and nothing is written to disk for it.
      final gone = photo.copyWith(
        path: '${root.path}/receipts/nope.jpg',
        remoteKey: const Value(
          'receipts/test-owner/srv-tx-1/nope.jpg',
        ),
      );
      expect(await service.ensureLocalFile(gone), isFalse);
      expect(await File(gone.path).exists(), isFalse);
    });

    test('downloadMissingPhotos downloads the missing, skips the present, reports the failed',
        () async {
      final remote = FakePhotoRemote();
      remote.objects['receipts/test-owner/srv-tx-1/srv-photo-1.jpg'] =
          Uint8List.fromList([1]);
      remote.objects['receipts/test-owner/srv-tx-1/srv-photo-2.jpg'] =
          Uint8List.fromList([2]);
      // photo-3's object is absent on the server — it will fail.
      await seedParents(remote, 'srv-tx-1');
      remote.seed('transaction_photos', [
        photoRow('srv-photo-1', 'srv-tx-1', ts(16)),
        photoRow('srv-photo-2', 'srv-tx-1', ts(17)),
        photoRow('srv-photo-3', 'srv-tx-1', ts(18)),
      ]);

      await puller(remote).pullNow();
      final photos = await db.select(db.transactionPhotos).get();
      expect(photos, hasLength(3));
      final bySync = {for (final p in photos) p.syncId: p};
      // photo-2 is already on this device — pre-place its file.
      final photo2File = File(bySync['srv-photo-2']!.path);
      await photo2File.create(recursive: true);
      await photo2File.writeAsBytes([2]);

      final service = SyncPhotoService(db: db, remote: remote);
      final result = await service.downloadMissingPhotos();

      expect(result.downloaded, 1); // photo-1
      expect(result.failed, 1); // photo-3, object gone
      expect(
        await File(bySync['srv-photo-1']!.path).readAsBytes(),
        [1],
      );
      expect(remote.downloadCalls, 2); // photo-1 + photo-3 attempts
    });

    test('photo rows with a missing parent stay unresolved and hold the cursor',
        () async {
      final remote = FakePhotoRemote();
      remote.seed('transaction_photos', [
        photoRow('srv-photo-1', 'srv-tx-1', ts(16)),
      ]);

      final result = await puller(remote).pullNow();

      expect(result.skippedUnresolved, 1);
      expect(result.applied, 0);
      expect(await pullCursor(), isNull);
      expect(await db.select(db.transactionPhotos).get(), isEmpty);
    });
  });

  group('deletes remove the object', () {
    test('push: deleting a photo removes its Storage object', () async {
      final remote = FakePhotoRemote();
      final gate = FakePhotoUploadGate(true);
      final photo = await addPhotoWithFile();
      final key =
          'receipts/test-owner/${photo.txSyncId}/${photo.photoSyncId}.jpg';

      await pusher(remote, gate).pushNow();
      expect(remote.objects.containsKey(key), isTrue);

      final photoId =
          (await db.select(db.transactionPhotos).get()).single.id;
      await db.deletePhoto(photoId);
      expect(await File(photo.storedPath).exists(), isFalse);

      final result = await pusher(remote, gate).pushNow();

      expect(result.pushed, 1); // the tombstone
      expect(result.failed, 0);
      expect(
        remote.tombstones.any((t) => t.table == 'transaction_photos'),
        isTrue,
      );
      expect(remote.objects.containsKey(key), isFalse);
      expect(await outboxCount(), 0);
    });

    test('pull: a tombstoned photo deletes the local row, the file, and the object',
        () async {
      final remote = FakePhotoRemote();
      final key = 'receipts/test-owner/srv-tx-1/srv-photo-1.jpg';
      remote.objects[key] = Uint8List.fromList([9]);
      await seedParents(remote, 'srv-tx-1');
      remote.seed('transaction_photos', [
        photoRow('srv-photo-1', 'srv-tx-1', ts(16)),
      ]);

      await puller(remote).pullNow();
      final photo = (await db.select(db.transactionPhotos).get()).single;
      await SyncPhotoService(db: db, remote: remote).ensureLocalFile(photo);
      expect(await File(photo.path).exists(), isTrue);

      // The photo is deleted on another device.
      remote.seed('transaction_photos', [
        photoRow('srv-photo-1', 'srv-tx-1', ts(20), deletedAt: ts(20)),
      ]);
      final result = await puller(remote).pullNow();

      expect(result.tombstoned, 1);
      expect(result.failed, 0);
      expect(await db.select(db.transactionPhotos).get(), isEmpty);
      expect(await File(photo.path).exists(), isFalse);
      expect(remote.objects.containsKey(key), isFalse);
    });
  });
}

/// Fake [SyncRemote] with an in-memory Storage bucket and canned
/// server rows: pull serves the seeded rows with PostgREST
/// filter/order/page semantics; upsert records payloads and makes
/// them visible to [fetchRow]; Storage calls read/write [objects].
class FakePhotoRemote implements SyncRemote {
  final serverRows = <String, List<Map<String, dynamic>>>{};
  final upserts = <({String table, List<Map<String, dynamic>> rows})>[];
  final tombstones = <({String table, List<String> syncIds})>[];
  final objects = <String, Uint8List>{};
  int uploadCalls = 0;
  int downloadCalls = 0;
  int fatalNextCount = 0;

  void seed(String table, List<Map<String, dynamic>> rows) {
    serverRows[table] = rows;
  }

  @override
  Future<List<Map<String, dynamic>>> pull(
    String table,
    String? updatedAfter,
    int offset,
    int limit,
  ) async {
    var rows = <Map<String, dynamic>>[...(serverRows[table] ?? [])];
    if (updatedAfter != null) {
      rows = rows
          .where(
            (r) => (r['server_updated_at'] as String).compareTo(updatedAfter) > 0,
          )
          .toList();
    }
    rows.sort((a, b) {
      final byTs = (a['server_updated_at'] as String).compareTo(
        b['server_updated_at'] as String,
      );
      return byTs != 0
          ? byTs
          : (a['sync_id'] as String).compareTo(b['sync_id'] as String);
    });
    if (offset >= rows.length) return [];
    return rows.sublist(offset, min(offset + limit, rows.length));
  }

  @override
  Future<void> upsert(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    if (fatalNextCount > 0) {
      fatalNextCount--;
      throw SyncFatalException('fatal (test)');
    }
    upserts.add((table: table, rows: rows));
    final existing = serverRows.putIfAbsent(table, () => []);
    for (final row in rows) {
      final i = existing.indexWhere(
        (r) => r['sync_id'] == row['sync_id'],
      );
      if (i >= 0) {
        existing[i] = row;
      } else {
        existing.add(row);
      }
    }
  }

  @override
  Future<void> tombstone(
    String table,
    List<String> syncIds,
    DateTime deletedAt,
  ) async {
    if (fatalNextCount > 0) {
      fatalNextCount--;
      throw SyncFatalException('fatal (test)');
    }
    tombstones.add((table: table, syncIds: syncIds));
  }

  @override
  Future<void> uploadPhoto(String key, File file) async {
    if (fatalNextCount > 0) {
      fatalNextCount--;
      throw SyncFatalException('fatal (test)');
    }
    uploadCalls++;
    objects[key] = await file.readAsBytes();
  }

  @override
  Future<Uint8List> downloadPhoto(String key) async {
    downloadCalls++;
    final bytes = objects[key];
    if (bytes == null) throw Exception('object not found');
    return bytes;
  }

  @override
  Future<void> deletePhotoObject(String key) async {
    objects.remove(key);
  }

  @override
  Future<Map<String, dynamic>?> fetchRow(
    String table,
    String syncId,
  ) async {
    final rows = serverRows[table] ?? const [];
    for (final row in rows) {
      if (row['sync_id'] == syncId) return row;
    }
    return null;
  }

  // P5: in-memory devices + prefs rows, and counts from the seeded
  // server rows (tombstoned rows don't count).
  final devices = <Map<String, dynamic>>[];
  Map<String, dynamic>? prefsRow;

  @override
  Future<int> countRows(String table) async {
    final rows = serverRows[table] ?? const [];
    return rows.where((r) => r['deleted_at'] == null).length;
  }

  @override
  Future<void> upsertDevice(Map<String, dynamic> row) async {
    devices.removeWhere((d) => d['device_id'] == row['device_id']);
    devices.add(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<Map<String, dynamic>>> listDevices() async {
    final sorted = [...devices];
    sorted.sort(
      (a, b) => (b['last_seen_at'] as String).compareTo(
        a['last_seen_at'] as String,
      ),
    );
    return sorted;
  }

  @override
  Future<Map<String, dynamic>?> fetchPrefs() async => prefsRow;

  @override
  Future<void> upsertPrefs(Map<String, dynamic> row) async {
    prefsRow = {
      ...row,
      'server_updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

/// Wi-Fi gate the test drives directly: no radio involved.
class FakePhotoUploadGate implements PhotoUploadGate {
  FakePhotoUploadGate(this.onWifi);
  bool onWifi;
  @override
  Future<bool> get canUploadPhotos async => onWifi;
}
