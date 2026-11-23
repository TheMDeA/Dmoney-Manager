import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/services/sync_devices.dart';
import 'package:dmoney_manager/core/services/sync_orchestrator.dart';
import 'package:dmoney_manager/core/services/sync_photos.dart';
import 'package:dmoney_manager/core/services/sync_remote.dart';
import 'package:dmoney_manager/core/services/sync_reset_service.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// "Reset sync data": the wipe plan's foreign-key order and the
/// reset service (backup → wipe → re-enqueue → first cycle).
/// Fake remote, no network.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory root;
  late FakeResetRemote remote;
  late SyncOrchestrator orchestrator;
  late SyncResetService reset;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sync_reset_test');
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
    remote = FakeResetRemote();
    orchestrator = SyncOrchestrator(
      db: db,
      remote: remote,
      currentUserId: () => 'test-owner',
      photoGate: _AlwaysWifiGate(),
      deviceService: SyncDeviceService(
        remote: remote,
        labelProvider: () async => 'Test Phone',
        appVersionProvider: () async => '3.0.0',
      ),
    );
    reset = SyncResetService(db: db, orchestrator: orchestrator);
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

  Future<String> syncIdOf(String table, int id) async {
    final row = await db.customSelect(
      'SELECT sync_id FROM "$table" WHERE id = ?',
      variables: [Variable.withInt(id)],
      readsFrom: {},
    ).getSingle();
    return row.read<String>('sync_id');
  }

  Future<int> foodCategoryId() async {
    final cats = await db.select(db.categories).get();
    return cats.firstWhere((c) => c.name == 'Food').id;
  }

  test('wipe plan deletes children before parents', () {
    final ops = SupabaseSyncRemote.wipeOperations();
    final deletes = <String>[
      for (final op in ops)
        if (op is WipeDeleteTable) op.table,
    ];
    // Every table exactly once.
    expect(deletes.toSet().length, deletes.length);
    expect(deletes.length, 16);
    // Foreign-key edges (child → parent): the child must be wiped
    // before the parent it references.
    const edges = <(String, String)>[
      ('transaction_photos', 'transactions'),
      ('transactions', 'wallets'),
      ('transactions', 'categories'),
      ('transactions', 'debts'),
      ('transactions', 'debt_payments'),
      ('transactions', 'recurring_transactions'),
      ('transactions', 'installment_plans'),
      ('category_keywords', 'categories'),
      ('transaction_templates', 'categories'),
      ('budgets', 'categories'),
      ('recurring_transactions', 'wallets'),
      ('recurring_transactions', 'categories'),
      ('goal_deposits', 'goals'),
      ('goal_deposits', 'wallets'),
      ('debt_payments', 'debts'),
      ('debt_payments', 'wallets'),
      ('debts', 'wallets'),
      ('installment_plans', 'wallets'),
      ('wallets', 'accounts'),
    ];
    for (final (child, parent) in edges) {
      expect(
        deletes.indexOf(child),
        lessThan(deletes.indexOf(parent)),
        reason: '$child must be wiped before $parent',
      );
    }
    // Self-references: the transfer link is cleared before the
    // transactions DELETE, and categories deletes its children
    // before the rest.
    final clear = ops.whereType<WipeClearColumn>().toList();
    expect(
      clear.map((c) => '${c.table}.${c.column}'),
      ['transactions.transfer_id'],
    );
    expect(
      ops.indexWhere((op) => op is WipeClearColumn),
      lessThan(deletes.indexOf('transactions')),
    );
    final categories = ops
        .whereType<WipeDeleteTable>()
        .firstWhere((d) => d.table == 'categories');
    expect(categories.childrenFirst, isTrue);
  });

  test('reset wipes the server and re-uploads the local book', () async {
    final walletId = await db.createWallet(
      accountId: 1,
      name: 'Cash',
      kind: 'cash',
      initialAmount: 0,
    );
    final txId = await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        walletId: walletId,
        categoryId: await foodCategoryId(),
        kind: 'expense',
        amount: 15000,
        date: DateTime.now(),
      ),
    );
    final txSyncId = await syncIdOf('transactions', txId);
    final photoPath = '${root.path}/receipts/test.jpg';
    await File(photoPath).create(recursive: true);
    await File(photoPath).writeAsBytes([1, 2, 3]);
    await db.into(db.transactionPhotos).insert(
      TransactionPhotosCompanion.insert(
        transactionId: txId,
        path: photoPath,
        remoteKey: Value(
          photoObjectKey('test-owner', txSyncId, 'photo-1'),
        ),
      ),
    );

    final result = await reset.runReset();

    // The backup landed first.
    expect(await File(result.backupPath).exists(), isTrue);
    // The wipe ran with this device's photo keys.
    expect(remote.wipeCalled, isTrue);
    expect(
      remote.wipePhotoKeys,
      ['receipts/test-owner/$txSyncId/photo-1.jpg'],
    );
    // The whole book was re-enqueued and the first cycle pushed it
    // (small book: one plain push, no chunking).
    expect(result.queued, greaterThan(0));
    expect(result.pushed, greaterThan(0));
    expect(result.cycleError, isNull);
    final pushedTables = {
      for (final u in remote.upserts) u.table,
    };
    expect(
      pushedTables,
      containsAll(['wallets', 'transactions', 'transaction_photos']),
    );
    // The photo's bytes were already on the server (remoteKey
    // set), so the push does not re-upload them.
    expect(remote.uploadedPhotoKeys, isEmpty);
    // Nothing left queued: the reset's first cycle drained it.
    expect(await db.outboxCount(), 0);
  });

  test('a failed wipe still re-enqueues the local book', () async {
    await db.createWallet(
      accountId: 1,
      name: 'Cash',
      kind: 'cash',
      initialAmount: 0,
    );
    remote.failWipe = true;

    await expectLater(reset.runReset(), throwsA(isA<SyncFatalException>()));

    // The invariant: the wiped rows are queued for re-upload, so
    // they are never stranded on a partial server.
    expect(await db.outboxCount(), greaterThan(0));
  });
}

class _AlwaysWifiGate implements PhotoUploadGate {
  @override
  Future<bool> get canUploadPhotos async => true;
}

class FakeResetRemote implements SyncRemote {
  bool wipeCalled = false;
  List<String> wipePhotoKeys = [];
  bool failWipe = false;
  final upserts = <({String table, List<Map<String, dynamic>> rows})>[];
  final uploadedPhotoKeys = <String>[];
  final objects = <String, Uint8List>{};

  @override
  Future<ServerWipeResult> wipeServerData(List<String> photoKeys) async {
    wipeCalled = true;
    wipePhotoKeys = List.of(photoKeys);
    if (failWipe) throw SyncFatalException('wipe failed');
    return ServerWipeResult(
      deletedRows: const {},
      photosRemoved: photoKeys.length,
      photosAttempted: photoKeys.length,
    );
  }

  @override
  Future<void> upsert(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    upserts.add((table: table, rows: rows));
  }

  @override
  Future<void> tombstone(
    String table,
    List<String> syncIds,
    DateTime deletedAt,
    String ownerId,
  ) async {}

  @override
  Future<List<Map<String, dynamic>>> pull(
    String table,
    String? updatedAfter,
    int offset,
    int limit,
  ) async => [];

  @override
  Future<void> uploadPhoto(String key, File file) async {
    uploadedPhotoKeys.add(key);
    objects[key] = await file.readAsBytes();
  }

  @override
  Future<Uint8List> downloadPhoto(String key) async => objects[key]!;

  @override
  Future<void> deletePhotoObject(String key) async {
    objects.remove(key);
  }

  @override
  Future<Map<String, dynamic>?> fetchRow(
    String table,
    String syncId,
  ) async => null;

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
