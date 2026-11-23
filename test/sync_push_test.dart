import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/services/sync_photos.dart';
import 'package:dmoney_manager/core/services/sync_push_service.dart';
import 'package:dmoney_manager/core/services/sync_remote.dart';
import 'package:dmoney_manager/core/services/sync_serialiser.dart';
import 'package:dmoney_manager/core/utils/sync_payload.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// P2 push-only sync (schema v18): the push drains the outbox in
/// queued order, upserts by sync_id in parent-before-child order,
/// acks entries on success, and never drops anything on failure.
/// No real network in these tests — a fake [SyncRemote] records
/// every call.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sync_push_test');
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
    // dangle and their serialise would come back unresolved. Insert
    // the default account directly (no outbox entry, like the seeded
    // categories); it takes id 1, so makeWallet's default accountId
    // resolves, and makeAccount's accounts start at id 2.
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

  Future<int> makeAccount(String name) =>
      db.addAccount(AccountsCompanion.insert(name: name, kind: 'personal'));

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

  Future<String> walletSyncId(int walletId) async =>
      (await db.getWalletById(walletId))!.syncId;

  Future<String> accountSyncId(int accountId) async =>
      (await (db.select(
        db.accounts,
      )..where((a) => a.id.equals(accountId))).getSingle()).syncId;

  Future<List<SyncOutboxData>> outbox() => db.select(db.syncOutbox).get();

  Future<int> outboxCount() async => (await outbox()).length;

  Future<List<SyncPushedData>> pushedHashes() =>
      db.select(db.syncPushed).get();

  Future<int> addExpense(
    int walletId,
    int categoryId,
    int amount,
  ) => db.addTransaction(
    TransactionsCompanion.insert(
      walletId: walletId,
      categoryId: categoryId,
      kind: 'expense',
      amount: amount,
      date: DateTime(2026, 11, 1),
    ),
  );

  SyncPushService pusher(
    FakeSyncRemote remote, {
    PhotoUploadGate? photoGate,
  }) => SyncPushService(
    db: db,
    remote: remote,
    ownerId: 'test-owner',
    photoGate: photoGate,
  );

  group('push drain', () {
    test('plan before purchase, transfer before fee row, all acked',
        () async {
      final remote = FakeSyncRemote();
      final walletA = await makeWallet('Cash', 'cash');
      final walletB = await makeWallet('Bank', 'bank');
      final food = await foodId();
      await db.addPlanWithPurchase(
        walletId: walletA,
        name: 'Phone',
        totalAmount: 1200000,
        installmentAmount: 100000,
        totalCount: 12,
        categoryId: food,
      );
      await db.addTransfer(
        fromWalletId: walletA,
        toWalletId: walletB,
        amount: 10000,
        fee: 500,
      );

      final result = await pusher(remote).pushNow();

      // 7 entries: 2 wallets + plan + purchase + transfer + fee row
      // + the "Transfer fee" category, lazily created on first use
      // by feeCategoryId (it is not seeded).
      expect(result.pushed, 7);
      expect(result.failed, 0);
      expect(result.error, isNull);
      expect(await outboxCount(), 0);
      expect((await pushedHashes()).length, 7);
      // Parents before children: categories, wallets, then plans,
      // then transactions.
      expect(remote.upserts.map((u) => u.table).toList(), [
        'categories',
        'wallets',
        'installment_plans',
        'transactions',
      ]);
      final txRows = remote.upserts
          .firstWhere((u) => u.table == 'transactions')
          .rows;
      expect(txRows.length, 3);
      final transferIndex = txRows.indexWhere(
        (r) => r['kind'] == 'transfer',
      );
      final feeIndex = txRows.indexWhere(
        (r) => r['note'] == 'Transfer fee',
      );
      expect(transferIndex, isNot(-1));
      expect(feeIndex, isNot(-1));
      expect(feeIndex, greaterThan(transferIndex));
      // The purchase expense references its plan by sync id.
      final purchase = txRows.firstWhere((r) => r['note'] == 'Phone');
      final planRow = remote.upserts
          .firstWhere((u) => u.table == 'installment_plans')
          .rows
          .single;
      expect(purchase['plan_id'], planRow['sync_id']);
      // The last sync stamp was recorded.
      final state = await db.select(db.syncState).getSingle();
      expect(state.lastSyncAt, isNotNull);
    });

    test('batches of 100 outbox entries', () async {
      final remote = FakeSyncRemote();
      final wallet = await makeWallet('Cash', 'cash');
      final food = await foodId();
      await db.transaction(() async {
        for (var i = 0; i < 105; i++) {
          final syncId = 'seed-tx-$i';
          await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              walletId: wallet,
              categoryId: food,
              kind: 'expense',
              amount: 1000 + i,
              date: DateTime(2026, 11, 1),
              syncId: Value(syncId),
            ),
          );
          await db.into(db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              targetTable: 'transactions',
              syncId: syncId,
              op: 'insert',
            ),
          );
        }
      });

      final result = await pusher(remote).pushNow();

      // 106 entries (wallet + 105 transactions): the first batch
      // holds the wallet + 99 transactions, the second holds 6.
      expect(result.pushed, 106);
      expect(await outboxCount(), 0);
      final txCalls = [
        for (final u in remote.upserts)
          if (u.table == 'transactions') u,
      ];
      expect(txCalls.length, 2);
      expect(txCalls[0].rows.length, 99);
      expect(txCalls[1].rows.length, 6);
    });

    test('not signed in pushes nothing', () async {
      final remote = FakeSyncRemote();
      await makeWallet('Cash', 'cash');
      final service = SyncPushService(
        db: db,
        remote: remote,
        ownerId: null,
      );
      final result = await service.pushNow();
      expect(result.notSignedIn, isTrue);
      expect(result.pushed, 0);
      expect(remote.upserts, isEmpty);
      expect(await outboxCount(), 1);
    });
  });

  group('ack and failure', () {
    test('failure keeps entries and records no hashes', () async {
      final remote = FakeSyncRemote()..failAll = true;
      final wallet = await makeWallet('Cash', 'cash');
      await addExpense(wallet, await foodId(), 5000);

      final result = await pusher(remote).pushNow();

      expect(result.pushed, 0);
      expect(result.failed, 2);
      expect(result.error, isNull);
      expect(await outboxCount(), 2);
      expect(await pushedHashes(), isEmpty);
    });

    test('fatal error aborts the run and is reported', () async {
      final remote = FakeSyncRemote()..fatalNextCount = 1;
      final wallet = await makeWallet('Cash', 'cash');
      await addExpense(wallet, await foodId(), 5000);

      final result = await pusher(remote).pushNow();

      expect(result.error, isA<SyncFatalException>());
      expect(result.pushed, 0);
      expect(result.failed, 2);
      expect(await outboxCount(), 2);
      expect(await pushedHashes(), isEmpty);
    });

    test('group failure falls back to per-row upserts', () async {
      final remote = FakeSyncRemote()..failGroups = true;
      final wallet = await makeWallet('Cash', 'cash');
      await addExpense(wallet, await foodId(), 5000);
      await addExpense(wallet, await foodId(), 7000);

      final result = await pusher(remote).pushNow();

      expect(result.pushed, 3);
      expect(result.failed, 0);
      expect(await outboxCount(), 0);
      final txCalls = [
        for (final u in remote.upserts)
          if (u.table == 'transactions') u,
      ];
      expect(txCalls.length, 2);
      expect(txCalls.every((c) => c.rows.length == 1), isTrue);
    });

    test('unchanged rows are skipped by hash, not re-pushed', () async {
      final remote = FakeSyncRemote();
      final wallet = await makeWallet('Cash', 'cash');
      final syncId = await walletSyncId(wallet);

      await pusher(remote).pushNow();
      expect(remote.upserts.length, 1);
      expect(await outboxCount(), 0);

      // A no-change update entry for the same row.
      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion.insert(
          targetTable: 'wallets',
          syncId: syncId,
          op: 'update',
        ),
      );
      final again = await pusher(remote).pushNow();

      expect(again.skippedUnchanged, 1);
      expect(again.pushed, 0);
      expect(remote.upserts.length, 1);
      expect(await outboxCount(), 0);
    });
  });

  group('tombstones', () {
    test('pushed then deleted row is tombstoned, hash cleared', () async {
      final remote = FakeSyncRemote();
      final wallet = await makeWallet('Cash', 'cash');
      final syncId = await walletSyncId(wallet);
      await pusher(remote).pushNow();
      expect((await pushedHashes()).length, 1);

      expect(await db.deleteWallet(wallet), isTrue);
      final result = await pusher(remote).pushNow();

      expect(result.pushed, 1);
      expect(await outboxCount(), 0);
      expect(await pushedHashes(), isEmpty);
      expect(remote.tombstones.length, 1);
      expect(remote.tombstones.single.table, 'wallets');
      expect(remote.tombstones.single.syncIds, [syncId]);
    });

    test('created and deleted before first push sends no tombstone',
        () async {
      final remote = FakeSyncRemote();
      final wallet = await makeWallet('Cash', 'cash');
      expect(await db.deleteWallet(wallet), isTrue);

      final result = await pusher(remote).pushNow();

      expect(result.droppedNeverPushed, 1);
      expect(result.skippedStale, 1);
      expect(result.pushed, 0);
      expect(remote.tombstones, isEmpty);
      expect(remote.upserts, isEmpty);
      expect(await outboxCount(), 0);
    });
  });

  group('per-account toggle (idea #3)', () {
    test('off-account rows stay queued, then sync when toggled on',
        () async {
      final remote = FakeSyncRemote();
      final account2 = await makeAccount('Work');
      final wallet2 = await makeWallet(
        'Work cash',
        'cash',
        accountId: account2,
      );
      await addExpense(wallet2, await foodId(), 9000);

      await AppPrefs.setSyncAccountIds([1]);
      final skipped = await pusher(remote).pushNow();

      // The account row itself, its wallet and the transaction all
      // resolve to account 2, so all three stay queued.
      expect(skipped.skippedAccountOff, 3);
      expect(skipped.pushed, 0);
      expect(remote.upserts, isEmpty);
      expect(await outboxCount(), 3);

      await AppPrefs.setSyncAccountIds([1, account2]);
      final synced = await pusher(remote).pushNow();

      expect(synced.skippedAccountOff, 0);
      expect(synced.pushed, 3);
      expect(await outboxCount(), 0);
      final walletRow = remote.upserts
          .firstWhere((u) => u.table == 'wallets')
          .rows
          .single;
      expect(
        walletRow['account_id'],
        await accountSyncId(account2),
      );
    });
  });

  group('photos', () {
    test('photo bytes upload on Wi-Fi, then the row upserts with the key',
        () async {
      final remote = FakeSyncRemote();
      final wallet = await makeWallet('Cash', 'cash');
      final txId = await addExpense(wallet, await foodId(), 5000);
      final txSyncId =
          (await (db.select(
            db.transactions,
          )..where((t) => t.id.equals(txId))).getSingle()).syncId;
      final src = File('${root.path}/src.jpg')..writeAsBytesSync([1, 2, 3]);
      await db.addPhoto(txId, src.path);
      final photo = (await db.select(db.transactionPhotos).get()).single;

      final result = await pusher(
        remote,
        photoGate: FakePhotoUploadGate(true),
      ).pushNow();

      // 3 entries: wallet + expense + photo.
      expect(result.pushed, 3);
      expect(result.failed, 0);
      final key = 'receipts/test-owner/$txSyncId/${photo.syncId}.jpg';
      expect(remote.objects[key], [1, 2, 3]);
      expect(remote.uploadCalls, 1);
      final photoUpsert = remote.upserts
          .firstWhere((u) => u.table == 'transaction_photos')
          .rows
          .single;
      expect(photoUpsert['path'], key);
      expect(photoUpsert['transaction_id'], txSyncId);
      expect(
        (await db.select(db.transactionPhotos).get()).single.remoteKey,
        key,
      );
      expect(await outboxCount(), 0);
    });
  });

  group('restore resets sync state', () {
    test('outbox cleared, rows re-enqueued, cursor reset', () async {
      final remote = FakeSyncRemote();
      final wallet = await makeWallet('Cash', 'cash');
      final walletId = await walletSyncId(wallet);
      final txId = await addExpense(wallet, await foodId(), 5000);
      await pusher(remote).pushNow();
      expect(await outboxCount(), 0);
      expect((await pushedHashes()).isNotEmpty, isTrue);

      // A pull cursor from before the restore.
      await (db.update(db.syncState)..where((s) => s.id.equals(1))).write(
        SyncStateCompanion(
          lastPullCursor: const Value('2026-11-23T00:00:00.000Z'),
        ),
      );

      await db.resetSyncAfterRestore();

      expect(await pushedHashes(), isEmpty);
      final state = await db.select(db.syncState).getSingle();
      expect(state.lastPullCursor, isNull);
      expect(state.lastSyncAt, isNull);
      final entries = await outbox();
      expect(
        entries.any(
          (e) =>
              e.targetTable == 'wallets' &&
              e.syncId == walletId &&
              e.op == 'insert',
        ),
        isTrue,
      );
      expect(
        entries.where((e) => e.targetTable == 'transactions').length,
        1,
      );
      expect(
        entries.every((e) => e.op == 'insert'),
        isTrue,
      );

      // The restored state re-pushes as the new seed.
      remote.upserts.clear();
      final again = await pusher(remote).pushNow();
      expect(again.pushed, greaterThan(0));
      expect(
        remote.upserts.any(
          (u) =>
              u.table == 'wallets' &&
              u.rows.any((r) => r['sync_id'] == walletId),
        ),
        isTrue,
      );
      expect(txId, isNot(0));
    });
  });

  group('retry and backoff', () {
    test('retry delays double, capped at 60s', () {
      expect(
        SyncPushService.retryDelayForAttempt(0),
        const Duration(seconds: 1),
      );
      expect(
        SyncPushService.retryDelayForAttempt(1),
        const Duration(seconds: 2),
      );
      expect(
        SyncPushService.retryDelayForAttempt(2),
        const Duration(seconds: 4),
      );
      expect(
        SyncPushService.retryDelayForAttempt(5),
        const Duration(seconds: 32),
      );
      expect(
        SyncPushService.retryDelayForAttempt(6),
        const Duration(seconds: 60),
      );
      expect(
        SyncPushService.retryDelayForAttempt(10),
        const Duration(seconds: 60),
      );
    });

    test('pushWithRetry retries after a transient fatal error',
        () async {
      final remote = FakeSyncRemote()..fatalNextCount = 1;
      await makeWallet('Cash', 'cash');

      final result = await pusher(
        remote,
      ).pushWithRetry(maxAttempts: 2);

      expect(result.error, isNull);
      expect(result.pushed, 1);
      expect(await outboxCount(), 0);
    });
  });

  group('serialiser', () {
    test('wallet payload uses server snake_case and sync ids', () async {
      final accountId = 1;
      final wallet = await makeWallet('Cash', 'cash');
      final syncId = await walletSyncId(wallet);
      final maps = await SyncReferenceMaps.load(db);
      final serialiser = SyncSerialiser(
        db: db,
        maps: maps,
        ownerId: 'owner-1',
      );

      final outcome = await serialiser.serialise('wallets', syncId);

      expect(outcome.rowGone, isFalse);
      expect(outcome.accountId, accountId);
      final payload = outcome.payload!;
      expect(payload['sync_id'], syncId);
      expect(payload['owner_id'], 'owner-1');
      expect(payload['account_id'], await accountSyncId(accountId));
      expect(payload['kind'], 'cash');
      expect(payload['initial_amount'], 0);
      expect(payload.containsKey('initialAmount'), isFalse);
    });

    test('budget payload carries the reserved word limit', () async {
      final budgetId = await db.addBudget(
        BudgetsCompanion.insert(
          categoryId: await foodId(),
          month: '2026-11',
          limit: 100000,
        ),
      );
      final budget = await (db.select(
        db.budgets,
      )..where((b) => b.id.equals(budgetId))).getSingle();
      final maps = await SyncReferenceMaps.load(db);
      final serialiser = SyncSerialiser(
        db: db,
        maps: maps,
        ownerId: 'owner-1',
      );

      final outcome = await serialiser.serialise(
        'budgets',
        budget.syncId,
      );

      expect(outcome.payload!['limit'], 100000);
      expect(outcome.payload!['month'], '2026-11');
      expect(outcome.accountId, isNull);
    });

    test('payload hash is stable for key order, changes on content',
        () {
      final a = {'b': 2, 'a': 'x'};
      final b = {'a': 'x', 'b': 2};
      final c = {'a': 'x', 'b': 3};
      expect(payloadHash(a), payloadHash(b));
      expect(payloadHash(a), isNot(payloadHash(c)));
      expect(canonicalJson(a), '{"a":"x","b":2}');
    });
  });
}

/// Records every remote call; configurable failures for the failure
/// paths. Throws [SyncFatalException] when [fatalNextCount] is set
/// (the next calls abort the run); throws a plain [Exception] when
/// [failAll] is set (data error — the push falls back per-row, which
/// also fails); throws on multi-row upserts when [failGroups] is
/// set (the per-row fallback then succeeds).
class FakeSyncRemote implements SyncRemote {
  final upserts = <({String table, List<Map<String, dynamic>> rows})>[];
  final tombstones = <({String table, List<String> syncIds})>[];
  // P4: in-memory Storage objects (key → bytes) and server rows
  // (sync id → last upserted payload), so photo upload, download,
  // delete and fetchRow can be observed.
  final objects = <String, Uint8List>{};
  final serverRows = <String, Map<String, dynamic>>{};
  int uploadCalls = 0;
  int downloadCalls = 0;
  bool failAll = false;
  bool failGroups = false;
  int fatalNextCount = 0;

  @override
  Future<void> upsert(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    if (fatalNextCount > 0) {
      fatalNextCount--;
      throw SyncFatalException('fatal (test)');
    }
    if (failAll) throw Exception('upsert failed');
    if (failGroups && rows.length > 1) {
      throw Exception('group upsert failed');
    }
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
  ) async {
    if (fatalNextCount > 0) {
      fatalNextCount--;
      throw SyncFatalException('fatal (test)');
    }
    if (failAll) throw Exception('tombstone failed');
    tombstones.add((table: table, syncIds: syncIds));
  }

  @override
  Future<List<Map<String, dynamic>>> pull(
    String table,
    String? updatedAfter,
    int offset,
    int limit,
  ) async {
    // The push never pulls; the P3 tests have their own fake.
    return [];
  }

  @override
  Future<void> uploadPhoto(String key, File file) async {
    if (fatalNextCount > 0) {
      fatalNextCount--;
      throw SyncFatalException('fatal (test)');
    }
    if (failAll) throw Exception('upload failed');
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
  ) async => serverRows[syncId];

  // P5: the push never counts, lists devices or syncs prefs.
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
}

/// Wi-Fi gate the test drives directly: no radio involved.
class FakePhotoUploadGate implements PhotoUploadGate {
  FakePhotoUploadGate(this.onWifi);
  bool onWifi;
  @override
  Future<bool> get canUploadPhotos async => onWifi;
}
