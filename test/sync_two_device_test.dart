import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/services/sync_conflicts_service.dart';
import 'package:dmoney_manager/core/services/sync_devices.dart';
import 'package:dmoney_manager/core/services/sync_first_run.dart';
import 'package:dmoney_manager/core/services/sync_orchestrator.dart';
import 'package:dmoney_manager/core/services/sync_photos.dart';
import 'package:dmoney_manager/core/services/sync_remote.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

import 'sync_p5_test.dart' as p5;

/// One device: its own in-memory DB + orchestrator against the
/// shared server. The device id is re-issued before the device's
/// first sync so each device heartbeats as its own row (the id
/// pref is process-global in tests).
Future<_Device> _makeDevice(
  String label,
  SharedFakeServer server,
) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final orchestrator = SyncOrchestrator(
    db: db,
    remote: server,
    currentUserId: () => 'test-owner',
    photoGate: const _AlwaysWifiGate(),
    deviceService: SyncDeviceService(
      remote: server,
      labelProvider: () async => label,
      appVersionProvider: () async => '3.0.0',
    ),
  );
  return _Device(db, orchestrator);
}

/// Two-device simulation (P6 proof): two local in-memory DBs share
/// ONE fake server. Fake remote only, no network.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late SharedFakeServer server;
  late _Device deviceA;
  late _Device deviceB;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sync_2device_test');
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => root.path,
        );
    await AppPrefs.init();
    server = SharedFakeServer();
    deviceA = await _makeDevice('Phone A', server);
    deviceB = await _makeDevice('Tablet B', server);
    // Device A has the default account (inserted directly, no
    // outbox entry — the P6 seed enqueues it on first sync).
    await deviceA.db.into(deviceA.db.accounts).insert(
      AccountsCompanion.insert(name: 'Personal', kind: 'personal'),
    );
    // Device B starts genuinely empty: no account, so the
    // first-run check sees an empty local DB.
  });

  tearDown(() async {
    await deviceA.db.close();
    await deviceB.db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (await root.exists()) await root.delete(recursive: true);
  });

  /// Drive cycles the way the triggers do until the backlog drains
  /// (or [maxCycles] is reached), then assert the outbox is empty.
  Future<void> syncUntilDrained(_Device device, {int maxCycles = 6}) async {
    for (var i = 0; i < maxCycles; i++) {
      final result = await device.orchestrator.syncNow();
      expect(result.error, isNull);
      if (!device.orchestrator.initialPushPending &&
          await device.db.outboxCount() == 0) {
        return;
      }
    }
    fail('outbox did not drain after $maxCycles cycles');
  }

  /// A creates the baseline (wallet + [expenseCount] expenses),
  /// syncs it; B runs the first-run migration and lands it.
  /// Returns A's wallet id.
  Future<int> seedBoth({int expenseCount = 3}) async {
    final wallet = await deviceA.makeWallet('Cash', 'cash');
    final food = await deviceA.foodId();
    for (var i = 0; i < expenseCount; i++) {
      await deviceA.addExpense(wallet, food, 5000 + i * 1000);
    }
    await syncUntilDrained(deviceA);
    // The device id pref is process-global in tests, so B is
    // issued a fresh id before its first sync — otherwise B would
    // heartbeat as A's device. (Later syncs in the same test may
    // re-use whichever id is current; only the device list is
    // affected, and only the adoption test asserts on it.)
    await AppPrefs.setSyncDeviceId(const Uuid().v4());
    final firstRun = SyncFirstRunService(
      db: deviceB.db,
      orchestrator: deviceB.orchestrator,
    );
    final check = await firstRun.checkFirstRun();
    expect(check.eligible, isTrue);
    await firstRun.runMigration();
    return wallet;
  }

  /// Sorted sync ids per table — the convergence comparison.
  Future<Map<String, List<String>>> dump(AppDatabase db) async {
    final tables = [
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
    final out = <String, List<String>>{};
    for (final table in tables) {
      final rows = await db.customSelect(
        'SELECT sync_id FROM "$table" ORDER BY sync_id',
        readsFrom: {},
      ).get();
      out[table] = rows.map((r) => r.read<String>('sync_id')).toList();
    }
    return out;
  }

  test('fresh-device adoption lands A\'s data, incl. seed categories',
      () async {
    final walletA = await seedBoth();
    final a = await deviceA.db.getWalletById(walletA);
    // B landed the wallet (by sync id — local int ids need not match).
    final walletsB = await deviceB.db.select(deviceB.db.wallets).get();
    expect(walletsB, hasLength(1));
    expect(walletsB.single.syncId, a!.syncId);
    expect(walletsB.single.name, 'Cash');
    expect(walletsB.single.balance, a.balance);
    final txsB = await deviceB.db.select(deviceB.db.transactions).get();
    expect(txsB, hasLength(3));
    // The seed 'Food' category arrived with A's sync id.
    final foodA = await deviceA.db.select(deviceA.db.categories).get();
    final foodB = await deviceB.db.select(deviceB.db.categories).get();
    expect(
      foodB.map((c) => c.syncId).toSet(),
      foodA.map((c) => c.syncId).toSet(),
    );
    expect(
      foodB.firstWhere((c) => c.name == 'Food').syncId,
      foodA.firstWhere((c) => c.name == 'Food').syncId,
    );
    // Both devices registered themselves.
    final devices = await deviceB.orchestrator.deviceService.listDevices();
    expect(devices.map((d) => d.label).toSet(), {'Phone A', 'Tablet B'});
  });

  test('concurrent edit: LWW wins, loser is in the keeper, restore works',
      () async {
    final walletA = await seedBoth();
    final walletSyncId = await deviceA.syncIdOf('wallets', walletA);
    // A renames the wallet and syncs.
    final walletRowA = await deviceA.db.getWalletById(walletA);
    await deviceA.db.updateWallet(
      id: walletA,
      name: 'Cash A',
      kind: walletRowA!.kind,
    );
    await syncUntilDrained(deviceA);
    // B renames the same wallet differently — without pulling first.
    final walletB =
        (await deviceB.db.select(deviceB.db.wallets).get()).single;
    await deviceB.db.updateWallet(
      id: walletB.id,
      name: 'Cash B',
      kind: walletB.kind,
    );
    // B's push wins on the server (its stamp is newer).
    await syncUntilDrained(deviceB);
    // A syncs again: the pull overwrites A's name with B's and
    // the keeper records A's losing edit.
    await syncUntilDrained(deviceA);
    expect((await deviceA.db.getWalletById(walletA))!.name, 'Cash B');
    final conflicts = await deviceA.db.select(deviceA.db.syncConflicts).get();
    expect(conflicts, hasLength(1));
    expect(conflicts.single.targetTable, 'wallets');
    expect(conflicts.single.syncId, walletSyncId);
    expect(conflicts.single.losingJson, contains('Cash A'));
    // Restore A's name; the next sync pushes it, and B pulls it.
    expect(
      await SyncConflictService(deviceA.db).restoreConflict(conflicts.single),
      isTrue,
    );
    expect((await deviceA.db.getWalletById(walletA))!.name, 'Cash A');
    await syncUntilDrained(deviceA);
    await syncUntilDrained(deviceB);
    expect(
      (await deviceB.db.getWalletById(walletB.id))!.name,
      'Cash A',
    );
  });

  test('delete on A tombstones on B', () async {
    final walletA = await seedBoth();
    final txsA = await deviceA.db.select(deviceA.db.transactions).get();
    for (final t in txsA) {
      await deviceA.db.deleteTransaction(t.id);
    }
    await syncUntilDrained(deviceA);
    await syncUntilDrained(deviceB);
    expect(
      await deviceB.db.select(deviceB.db.transactions).get(),
      isEmpty,
    );
    // The wallet survived; only the transactions are gone.
    expect(
      (await deviceB.db.select(deviceB.db.wallets).get()),
      hasLength(1),
    );
    expect((await deviceA.db.getWalletById(walletA))!.balance, 0);
  });

  test('photo uploaded by A on Wi-Fi downloads lazily on B', () async {
    await seedBoth(expenseCount: 1);
    final txA =
        (await deviceA.db.select(deviceA.db.transactions).get()).single;
    final src = File('${root.path}/photo.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    await deviceA.db.addPhoto(txA.id, src.path);
    await syncUntilDrained(deviceA);
    // The object reached the server.
    final photoA =
        (await deviceA.db.select(deviceA.db.transactionPhotos).get()).single;
    expect(photoA.remoteKey, isNotNull);
    expect(server.objects, contains(photoA.remoteKey));
    // B pulls the row (the migration ran before the photo
    // existed, so a plain sync lands it). B's device id was
    // already issued in seedBoth.
    await syncUntilDrained(deviceB);
    final photosB =
        await deviceB.db.select(deviceB.db.transactionPhotos).get();
    expect(photosB, hasLength(1));
    expect(photosB.single.remoteKey, photoA.remoteKey);
    // Simulate "bytes not on this device": B's photo path points
    // at the shared mock docs dir, where A's file still sits —
    // delete it, then the lazy download must re-fetch it.
    final local = File(photosB.single.path);
    if (await local.exists()) await local.delete();
    expect(
      await SyncPhotoService(db: deviceB.db, remote: server)
          .ensureLocalFile(photosB.single),
      isTrue,
    );
    expect(await local.readAsBytes(), [1, 2, 3]);
  });

  test('chunked initial push resumes after an injected interruption',
      () async {
    final walletA = await deviceA.makeWallet('Cash', 'cash');
    final food = await deviceA.foodId();
    for (var i = 0; i < 250; i++) {
      await deviceA.addExpense(walletA, food, 1000 + i);
    }
    server.failUpsertAfterCalls = 2;
    final first = await deviceA.orchestrator.syncNow();
    expect(first.error, isNotNull);
    final remaining = await deviceA.db.outboxCount();
    expect(remaining, greaterThan(0));
    expect(deviceA.orchestrator.initialPushPending, isTrue);
    server.failUpsertAfterCalls = null;
    await syncUntilDrained(deviceA, maxCycles: 6);
    expect(deviceA.orchestrator.initialPushPending, isFalse);
    // Every transaction landed exactly once.
    final pushedTxIds = [
      for (final u in server.upserts)
        if (u.table == 'transactions')
          for (final row in u.rows) row['sync_id'] as String,
    ];
    expect(pushedTxIds.length, 250);
    expect(pushedTxIds.toSet().length, 250);
    // B adopts the whole library.
    await AppPrefs.setSyncDeviceId(const Uuid().v4());
    final firstRun = SyncFirstRunService(
      db: deviceB.db,
      orchestrator: deviceB.orchestrator,
    );
    expect((await firstRun.checkFirstRun()).eligible, isTrue);
    await firstRun.runMigration();
    expect(
      (await deviceB.db.select(deviceB.db.transactions).get()).length,
      250,
    );
  });

  test('both devices converge to the same content', () async {
    final walletA = await seedBoth();
    final food = await deviceA.foodId();
    // A adds one more expense and deletes another.
    await deviceA.addExpense(walletA, food, 9000);
    final toDelete =
        (await deviceA.db.select(deviceA.db.transactions).get()).first;
    await deviceA.db.deleteTransaction(toDelete.id);
    // B renames the wallet.
    final walletB =
        (await deviceB.db.select(deviceB.db.wallets).get()).single;
    await deviceB.db.updateWallet(
      id: walletB.id,
      name: 'Renamed on B',
      kind: walletB.kind,
    );
    // B syncs first (its rename wins), then A, then B again so
    // the delete and the new expense reach B.
    await syncUntilDrained(deviceB);
    await syncUntilDrained(deviceA);
    await syncUntilDrained(deviceB);
    expect(await dump(deviceA.db), await dump(deviceB.db));
    final a = await deviceA.db.getWalletById(walletA);
    final b = await deviceB.db.getWalletById(walletB.id);
    expect(a!.balance, b!.balance);
    expect(b.name, 'Renamed on B');
    expect(
      (await deviceB.db.select(deviceB.db.transactions).get()).length,
      3,
    );
  });
}

/// One device's DB + orchestrator, with the small write helpers the
/// scenarios use.
class _Device {
  _Device(this.db, this.orchestrator);

  final AppDatabase db;
  final SyncOrchestrator orchestrator;

  Future<int> makeWallet(String name, String kind, {int accountId = 1}) =>
      db.createWallet(
        accountId: accountId,
        name: name,
        kind: kind,
        initialAmount: 0,
      );

  Future<int> foodId() async {
    final cats = await db.select(db.categories).get();
    return cats.firstWhere((c) => c.name == 'Food').id;
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

  Future<String> syncIdOf(String table, int id) async {
    final row = await db.customSelect(
      'SELECT sync_id FROM "$table" WHERE id = ?',
      variables: [Variable.withInt(id)],
      readsFrom: {},
    ).getSingle();
    return row.read<String>('sync_id');
  }
}

/// Wi-Fi is always available in tests (no radio here).
class _AlwaysWifiGate implements PhotoUploadGate {
  const _AlwaysWifiGate();

  @override
  Future<bool> get canUploadPhotos async => true;
}

/// The P5 fake, extended so upserts/tombstones actually land in
/// the served rows — the shared "server" both devices see.
/// Server stamps tick from 2026-11-23T12:00:00Z, +1 s per row,
/// so pushed rows are always newer than the seeded '2026-11-23T10:xx'
/// rows the fakes use, and LWW ordering works across devices.
class SharedFakeServer extends p5.FakeP5Remote {
  int _tick = 0;

  String _nextStamp() {
    final stamp = DateTime.utc(2026, 11, 23, 12, 0, _tick);
    _tick++;
    return stamp.toIso8601String();
  }

  /// Throw a fatal error from upsert once the call count exceeds
  /// this (null = never). Counts every upsert call, group or row.
  int? failUpsertAfterCalls;
  int upsertCalls = 0;

  @override
  Future<void> upsert(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    upsertCalls++;
    if (failUpsertAfterCalls != null &&
        upsertCalls > failUpsertAfterCalls!) {
      throw SyncFatalException('injected fatal');
    }
    await super.upsert(table, rows);
    final served = serverRows.putIfAbsent(table, () => []);
    for (final row in rows) {
      final stamp = _nextStamp();
      final landed = Map<String, dynamic>.from(row)
        ..['server_updated_at'] = stamp
        ..['deleted_at'] = null;
      final existing = served.indexWhere(
        (r) => r['sync_id'] == row['sync_id'],
      );
      if (existing >= 0) {
        served[existing] = landed;
      } else {
        served.add(landed);
      }
      serverBySyncId[row['sync_id'] as String] = landed;
    }
  }

  @override
  Future<void> tombstone(
    String table,
    List<String> syncIds,
    DateTime deletedAt,
    String ownerId,
  ) async {
    await super.tombstone(table, syncIds, deletedAt, ownerId);
    final served = serverRows[table];
    if (served == null) return;
    final stamp = _nextStamp();
    for (final row in served) {
      if (syncIds.contains(row['sync_id'] as String)) {
        row['deleted_at'] = stamp;
        row['server_updated_at'] = stamp;
      }
    }
  }
}
