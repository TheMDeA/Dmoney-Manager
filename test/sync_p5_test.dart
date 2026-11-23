import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/services/sync_devices.dart';
import 'package:dmoney_manager/core/services/sync_first_run.dart';
import 'package:dmoney_manager/core/services/sync_orchestrator.dart';
import 'package:dmoney_manager/core/services/sync_prefs.dart';
import 'package:dmoney_manager/core/services/sync_pull_service.dart';
import 'package:dmoney_manager/core/services/sync_remote.dart';
import 'package:dmoney_manager/core/services/sync_triggers.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// P5 sync (orchestrator + triggers + device list + preview +
/// first-run migration + prefs sync): fake remote, no network.
/// The launch ordering tests (pull-before-generation) run the real
/// `processDueRecurringTransactions` against a pulled server row.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory root;
  late FakeP5Remote remote;
  late SyncOrchestrator orchestrator;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sync_p5_test');
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => root.path,
        );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await AppPrefs.init();
    // The seed only creates categories — no account exists in a
    // fresh test DB. Insert the default account directly (no outbox
    // entry, like the seeded categories); it takes id 1, so
    // makeWallet's default accountId resolves.
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(name: 'Personal', kind: 'personal'),
    );
    remote = FakeP5Remote();
    orchestrator = SyncOrchestrator(
      db: db,
      remote: remote,
      currentUserId: () => 'test-owner',
      deviceService: SyncDeviceService(
        remote: remote,
        labelProvider: () async => 'Test Phone',
        appVersionProvider: () async => '3.0.0',
      ),
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

  Future<String> syncIdOf(String table, int id) async {
    final row = await db.customSelect(
      'SELECT sync_id FROM "$table" WHERE id = ?',
      variables: [Variable.withInt(id)],
      readsFrom: {},
    ).getSingle();
    return row.read<String>('sync_id');
  }

  Future<String> walletSyncId(int walletId) => syncIdOf('wallets', walletId);
  Future<String> categorySyncId(int categoryId) =>
      syncIdOf('categories', categoryId);

  SyncPullService puller() =>
      SyncPullService(db: db, remote: remote, ownerId: 'test-owner');

  /// Waits until the fake has served [n] pull calls (one cycle =
  /// 14, one per table), or fails. The trigger tests poll instead
  /// of sleeping a fixed time so a slow machine can't flake them.
  Future<void> waitForPullCalls(int n) async {
    for (var i = 0; i < 100; i++) {
      if (remote.pullCalls >= n) return;
      await Future.delayed(const Duration(milliseconds: 20));
    }
    fail('pullCalls did not reach $n (got ${remote.pullCalls})');
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

  Map<String, dynamic> categoryRow(
    String syncId,
    String timestamp, {
    String name = 'Food',
    String kind = 'expense',
    String? deletedAt,
  }) => {
    'sync_id': syncId,
    'owner_id': 'test-owner',
    'server_updated_at': timestamp,
    'deleted_at': deletedAt,
    'name': name,
    'icon_key': 'other',
    'color_hex': '#A78BFA',
    'kind': kind,
    'parent_id': null,
    'sort_order': 0,
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

  Map<String, dynamic> recurringRow(
    String syncId,
    String walletSyncId,
    String categorySyncId,
    String timestamp, {
    required String nextDue,
    String? deletedAt,
  }) => {
    'sync_id': syncId,
    'owner_id': 'test-owner',
    'server_updated_at': timestamp,
    'deleted_at': deletedAt,
    'wallet_id': walletSyncId,
    'category_id': categorySyncId,
    'kind': 'expense',
    'amount': 5000,
    'note': 'Rent',
    'frequency': 'monthly',
    'next_due': nextDue,
    'end_date': null,
    'active': true,
  };

  group('orchestrator', () {
    test('runs push before pull', () async {
      final wallet = await makeWallet('Cash', 'cash');
      remote.seed('accounts', [accountRow('srv-account-1', ts(3))]);
      final result = await orchestrator.syncNow();

      expect(result.error, isNull);
      expect(result.pushed, greaterThan(0));
      // The first remote call is a push upsert; no pull ran before it.
      final firstPull = remote.calls.indexWhere(
        (c) => c.startsWith('pull:'),
      );
      final firstPush = remote.calls.indexWhere(
        (c) => c.startsWith('upsert:'),
      );
      expect(firstPush, greaterThanOrEqualTo(0));
      expect(firstPull, greaterThan(firstPush));
      // The pushed wallet's sync id is among the upserts.
      final walletId = await walletSyncId(wallet);
      expect(
        remote.upserts.any(
          (u) => u.rows.any((r) => r['sync_id'] == walletId),
        ),
        isTrue,
      );
    });

    test('single-flight: two concurrent calls run one cycle', () async {
      final first = orchestrator.syncNow();
      final second = orchestrator.syncNow();
      final results = await Future.wait([first, second]);

      expect(identical(results[0], results[1]), isTrue);
      // One cycle = one pull call per table (14), not two cycles' 28.
      expect(remote.pullCalls, 14);
    });

    test('signed out is a silent no-op', () async {
      final signedOut = SyncOrchestrator(
        db: db,
        remote: remote,
        currentUserId: () => null,
      );
      final result = await signedOut.syncNow();

      expect(result.notSignedIn, isTrue);
      expect(result.hasFailures, isFalse);
      expect(remote.calls, isEmpty);
      expect(remote.pullCalls, 0);
    });

    test('device heartbeat upserts on a clean cycle', () async {
      final result = await orchestrator.syncNow();

      expect(result.error, isNull);
      expect(remote.devices, hasLength(1));
      final device = remote.devices.single;
      expect(device['device_id'], AppPrefs.syncDeviceId);
      expect(device['device_id'], isNotEmpty);
      expect(device['label'], 'Test Phone');
      expect(device['app_version'], '3.0.0');
      expect(device['owner_id'], 'test-owner');
      expect(device['last_seen_at'], isNotNull);
    });

    test('a second cycle reuses the device id', () async {
      await orchestrator.syncNow();
      final firstId = AppPrefs.syncDeviceId;
      await orchestrator.syncNow();

      expect(remote.devices, hasLength(1));
      expect(remote.devices.single['device_id'], firstId);
      expect(AppPrefs.syncDeviceId, firstId);
    });
  });

  group('launch ordering (pull before generation)', () {
    /// A monthly rule, due 3 days ago locally, whose server copy
    /// carries a next_due 30 days out with a newer timestamp.
    Future<int> dueRuleWithServerFuture() async {
      final wallet = await makeWallet('Cash', 'cash');
      final food = await foodId();
      final now = DateTime.now();
      final ruleId = await db.addRecurringTransaction(
        RecurringTransactionsCompanion.insert(
          walletId: wallet,
          categoryId: food,
          kind: 'expense',
          amount: 5000,
          note: const Value('Rent'),
          frequency: 'monthly',
          nextDue: now.subtract(const Duration(days: 3)),
        ),
      );
      // Push first: the pull skips rows with a pending outbox entry
      // (the push-before-pull contract), so the rule must leave
      // before the server's newer copy can apply.
      await orchestrator.syncNow();
      remote.seed('recurring_transactions', [
        recurringRow(
          await syncIdOf('recurring_transactions', ruleId),
          await walletSyncId(wallet),
          await categorySyncId(food),
          now.add(const Duration(hours: 1)).toUtc().toIso8601String(),
          nextDue: now.add(const Duration(days: 30)).toUtc().toIso8601String(),
        ),
      ]);
      return ruleId;
    }

    test('pull-then-generate does not double-post', () async {
      final ruleId = await dueRuleWithServerFuture();
      final pull = await puller().pullNow();
      expect(pull.error, isNull);

      final generated = await db.processDueRecurringTransactions();
      expect(generated, 0);
      expect(await db.select(db.transactions).get(), isEmpty);

      final rule =
          await (db.select(
            db.recurringTransactions,
          )..where((r) => r.id.equals(ruleId))).getSingle();
      expect(
        rule.nextDue.isAfter(DateTime.now().add(const Duration(days: 20))),
        isTrue,
      );
    });

    test('generate-then-pull posts once (the counterfactual)', () async {
      final ruleId = await dueRuleWithServerFuture();

      final generated = await db.processDueRecurringTransactions();
      expect(generated, 1);
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(1));
      expect(txs.single.recurringId, ruleId);
    });
  });

  group('preview', () {
    test('counts live rows per table, tombstones excluded', () async {
      remote.seed('wallets', [
        walletRow('srv-wallet-1', 'srv-account-1', ts(1)),
        walletRow('srv-wallet-2', 'srv-account-1', ts(2)),
      ]);
      remote.seed('transactions', [
        txRow('srv-tx-1', 'srv-wallet-1', 'srv-category-1', ts(3)),
        txRow('srv-tx-2', 'srv-wallet-1', 'srv-category-1', ts(4)),
        txRow(
          'srv-tx-3',
          'srv-wallet-1',
          'srv-category-1',
          ts(5),
          note: 'gone',
          deletedAt: ts(5),
        ),
      ]);
      final firstRun = SyncFirstRunService(db: db, orchestrator: orchestrator);
      final preview = await firstRun.fetchPreview();

      expect(preview.count('wallets'), 2);
      expect(preview.count('transactions'), 2);
      expect(preview.count('accounts'), 0);
      expect(preview.total, 4);
    });
  });

  group('first-run migration', () {
    test('backup, wipe, full pull restores the server rows', () async {
      // Local data: a wallet + a transaction, both local-only.
      final localWallet = await makeWallet('Local Cash', 'cash');
      final food = await foodId();
      await db.addTransaction(
        TransactionsCompanion.insert(
          walletId: localWallet,
          categoryId: food,
          kind: 'expense',
          amount: 9999,
          date: DateTime(2026, 11, 1),
        ),
      );
      // Server data: a different account, wallet, category, tx.
      remote.seed('accounts', [accountRow('srv-account-1', ts(1))]);
      remote.seed('categories', [
        categoryRow('srv-category-1', ts(2), name: 'Food'),
      ]);
      remote.seed('wallets', [
        walletRow('srv-wallet-1', 'srv-account-1', ts(3), name: 'Server Cash'),
      ]);
      remote.seed('transactions', [
        txRow(
          'srv-tx-1',
          'srv-wallet-1',
          'srv-category-1',
          ts(4),
          amount: 12000,
          note: 'Server taxi',
        ),
      ]);
      remote.seedPrefs({
        'owner_id': 'test-owner',
        'currency_code': 'USD',
        'language_code': 'en',
        'server_updated_at': '2026-11-23T13:00:00.000Z',
      });

      final firstRun = SyncFirstRunService(db: db, orchestrator: orchestrator);
      final eligible = await firstRun.checkFirstRun();
      expect(eligible.eligible, isFalse); // local has data — no auto-offer
      final steps = <String>[];
      final result = await firstRun.runMigration(
        onStep: (step) => steps.add(step),
      );

      expect(File(result.backupPath).existsSync(), isTrue);
      expect(steps, ['backup', 'wipe', 'pull', 'prefs']);
      expect(result.pulled, greaterThan(0));
      // Local-only rows are gone; server rows landed.
      final wallets = await db.select(db.wallets).get();
      expect(wallets.map((w) => w.name), ['Server Cash']);
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(1));
      expect(txs.single.note, 'Server taxi');
      expect(txs.single.amount, 12000);
      // The pull cursor advanced past the beginning.
      final state = await db.select(db.syncState).getSingle();
      expect(state.lastPullCursor, isNotNull);
      // Server prefs were adopted.
      expect(AppPrefs.currencyCode, 'USD');
      expect(AppPrefs.languageCode, 'en');
    });

    test('checkFirstRun offers only when local is empty', () async {
      // The setUp inserts a default account so makeWallet resolves;
      // this test needs a genuinely empty local DB, so remove it.
      await db.delete(db.accounts).go();
      remote.seed('accounts', [accountRow('srv-account-1', ts(1))]);
      final firstRun = SyncFirstRunService(db: db, orchestrator: orchestrator);

      final check = await firstRun.checkFirstRun();
      expect(check.eligible, isTrue);
      expect(check.preview?.count('accounts'), 1);
    });

    test('checkFirstRun declines when the server is empty', () async {
      final firstRun = SyncFirstRunService(db: db, orchestrator: orchestrator);

      final check = await firstRun.checkFirstRun();
      expect(check.eligible, isFalse);
      expect(check.preview, isNull);
    });
  });

  group('prefs sync', () {
    test('round-trip: push local, adopt newer server, push local again',
        () async {
      final prefs = SyncPrefsService(remote: remote);
      // No server row yet: local values (IDR, follow-device) push.
      var result = await prefs.syncPrefs('test-owner');
      expect(result.pushed, isTrue);
      expect(remote.prefsRow?['currency_code'], 'IDR');
      expect(remote.prefsRow?['language_code'], isNull);
      expect(AppPrefs.syncPrefsUpdatedAt, isNotNull);

      // Other prefs are set now, to prove the round leaves them alone.
      await AppPrefs.setThemeMode(ThemeMode.dark);
      await AppPrefs.setBalanceHidden(true);

      // A newer server row (EUR, Indonesian) wins over local.
      final stamp = DateTime.parse(AppPrefs.syncPrefsUpdatedAt!);
      remote.seedPrefs({
        'owner_id': 'test-owner',
        'currency_code': 'EUR',
        'language_code': 'id',
        'server_updated_at': stamp
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
      });
      result = await prefs.syncPrefs('test-owner');
      expect(result.appliedServer, isTrue);
      expect(result.currencyChanged, isTrue);
      expect(result.languageChanged, isTrue);
      expect(AppPrefs.currencyCode, 'EUR');
      expect(AppPrefs.languageCode, 'id');
      expect(AppPrefs.themeMode, ThemeMode.dark);
      expect(AppPrefs.balanceHidden, isTrue);

      // A local change after adopting pushes back to the server.
      await AppPrefs.setCurrencyCode('USD');
      result = await prefs.syncPrefs('test-owner');
      expect(result.pushed, isTrue);
      expect(remote.prefsRow?['currency_code'], 'USD');
      // The server language survived the push (allowlist, both keys).
      expect(remote.prefsRow?['language_code'], 'id');
    });

    test('unreachable server is best-effort, never throws', () async {
      final failing = _FailingRemote();
      final prefs = SyncPrefsService(remote: failing);
      final result = await prefs.syncPrefs('test-owner');
      expect(result.serverUnreachable, isTrue);
      expect(result.pushed, isFalse);
      expect(result.appliedServer, isFalse);
    });
  });

  group('triggers', () {
    test('save trigger debounces rapid changes into one cycle', () async {
      final connectivity = StreamController<List<ConnectivityResult>>.broadcast();
      final triggers = SyncTriggerService(
        db: db,
        orchestrator: orchestrator,
        debounce: const Duration(milliseconds: 50),
        connectivityStream: connectivity.stream,
      );
      triggers.start();
      // Launch sync: exactly one cycle.
      await waitForPullCalls(14);
      final afterLaunch = remote.pullCalls;
      expect(afterLaunch, 14);

      // Two rapid local changes — still debouncing, no cycle yet.
      await makeWallet('A', 'cash');
      await makeWallet('B', 'cash');
      expect(remote.pullCalls, afterLaunch);
      // One debounced cycle for the burst, not two.
      await waitForPullCalls(afterLaunch + 14);
      expect(remote.pullCalls, afterLaunch + 14);

      triggers.stop();
      await connectivity.close();
    });

    test('connectivity regain triggers a cycle, going offline does not',
        () async {
      final connectivity = StreamController<List<ConnectivityResult>>.broadcast();
      final triggers = SyncTriggerService(
        db: db,
        orchestrator: orchestrator,
        debounce: const Duration(milliseconds: 50),
        connectivityStream: connectivity.stream,
      );
      triggers.start();
      await waitForPullCalls(14);
      final base = remote.pullCalls;

      connectivity.add([ConnectivityResult.none]);
      await Future.delayed(const Duration(milliseconds: 150));
      expect(remote.pullCalls, base);
      connectivity.add([ConnectivityResult.wifi]);
      await waitForPullCalls(base + 14);
      expect(remote.pullCalls, base + 14);

      triggers.stop();
      await connectivity.close();
    });

    test('resume schedules a debounced cycle', () async {
      final connectivity = StreamController<List<ConnectivityResult>>.broadcast();
      final triggers = SyncTriggerService(
        db: db,
        orchestrator: orchestrator,
        debounce: const Duration(milliseconds: 50),
        connectivityStream: connectivity.stream,
      );
      triggers.start();
      await waitForPullCalls(14);
      final base = remote.pullCalls;

      triggers.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await waitForPullCalls(base + 14);
      expect(remote.pullCalls, base + 14);

      triggers.stop();
      await connectivity.close();
    });
  });
}

/// Fake [SyncRemote] for P5: serves canned server rows with
/// PostgREST filter/order/page semantics; upsert records payloads
/// and makes them visible to [fetchRow]; devices + prefs live in
/// memory; a monotonic fake clock stamps prefs upserts (the real
/// server trigger stamps with the server clock).
class FakeP5Remote implements SyncRemote {
  final serverRows = <String, List<Map<String, dynamic>>>{};
  final upserts = <({String table, List<Map<String, dynamic>> rows})>[];
  final tombstones = <({String table, List<String> syncIds, String ownerId})>[];
  final serverBySyncId = <String, Map<String, dynamic>>{};
  final objects = <String, Uint8List>{};
  final devices = <Map<String, dynamic>>[];
  Map<String, dynamic>? prefsRow;

  /// Every remote call in order ('upsert:table' / 'pull:table'),
  /// for the push-before-pull assertion.
  final calls = <String>[];
  int pullCalls = 0;

  DateTime _clock = DateTime.utc(2026, 11, 23, 12);
  String _tick() {
    _clock = _clock.add(const Duration(seconds: 1));
    return _clock.toIso8601String();
  }

  void seed(String table, List<Map<String, dynamic>> rows) {
    serverRows[table] = rows;
  }

  void seedPrefs(Map<String, dynamic> row) {
    prefsRow = Map<String, dynamic>.from(row);
  }

  @override
  Future<void> upsert(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    calls.add('upsert:$table');
    upserts.add((table: table, rows: rows));
    for (final row in rows) {
      serverBySyncId[row['sync_id'] as String] = row;
    }
  }

  @override
  Future<void> tombstone(
    String table,
    List<String> syncIds,
    DateTime deletedAt,
    String ownerId,
  ) async {
    calls.add('tombstone:$table');
    tombstones.add((table: table, syncIds: syncIds, ownerId: ownerId));
  }

  @override
  Future<List<Map<String, dynamic>>> pull(
    String table,
    String? updatedAfter,
    int offset,
    int limit,
  ) async {
    calls.add('pull:$table');
    pullCalls++;
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
    return rows.sublist(offset, offset + limit > rows.length ? rows.length : offset + limit);
  }

  @override
  Future<void> uploadPhoto(String key, File file) async {
    objects[key] = await file.readAsBytes();
  }

  @override
  Future<Uint8List> downloadPhoto(String key) async {
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
    final fromServer = serverRows[table] ?? const [];
    for (final row in fromServer) {
      if (row['sync_id'] == syncId) return row;
    }
    return serverBySyncId[syncId];
  }

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
    prefsRow = {...row, 'server_updated_at': _tick()};
  }
}

/// A remote that fails every prefs call, for the best-effort test.
class _FailingRemote implements SyncRemote {
  @override
  Future<void> upsert(String table, List<Map<String, dynamic>> rows) =>
      throw Exception('down');

  @override
  Future<void> tombstone(
    String table,
    List<String> syncIds,
    DateTime deletedAt,
    String ownerId,
  ) => throw Exception('down');

  @override
  Future<List<Map<String, dynamic>>> pull(
    String table,
    String? updatedAfter,
    int offset,
    int limit,
  ) async => throw Exception('down');

  @override
  Future<void> uploadPhoto(String key, File file) =>
      throw Exception('down');

  @override
  Future<Uint8List> downloadPhoto(String key) => throw Exception('down');

  @override
  Future<void> deletePhotoObject(String key) => throw Exception('down');

  @override
  Future<Map<String, dynamic>?> fetchRow(String table, String syncId) =>
      throw Exception('down');

  @override
  Future<int> countRows(String table) => throw Exception('down');

  @override
  Future<void> upsertDevice(Map<String, dynamic> row) =>
      throw Exception('down');

  @override
  Future<List<Map<String, dynamic>>> listDevices() =>
      throw Exception('down');

  @override
  Future<Map<String, dynamic>?> fetchPrefs() => throw Exception('down');

  @override
  Future<void> upsertPrefs(Map<String, dynamic> row) =>
      throw Exception('down');
}
