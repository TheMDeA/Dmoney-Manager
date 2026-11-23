import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/services/sync_devices.dart';
import 'package:dmoney_manager/core/services/sync_failure_mode.dart';
import 'package:dmoney_manager/core/services/sync_initial_push.dart';
import 'package:dmoney_manager/core/services/sync_orchestrator.dart';
import 'package:dmoney_manager/core/services/sync_pull_service.dart';
import 'package:dmoney_manager/core/services/sync_push_service.dart';
import 'package:dmoney_manager/core/services/sync_remote.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

import 'sync_p5_test.dart' as p5;

/// P6 hardening (chunked initial push, partial-failure handling,
/// sync log, named failure modes, SQL-aggregates judgment): fake
/// remote, no network. The two-device proof lives in
/// test/sync_two_device_test.dart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory root;
  late FailingFakeRemote remote;
  late SyncOrchestrator orchestrator;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sync_p6_test');
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
    remote = FailingFakeRemote();
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

  /// Deletes the outbox entries for one row (no hash recorded, so
  /// no conflict entries can be produced). A test that seeds server
  /// rows for a locally-created row must call this first, or pull
  /// correctly skips the row as pending and masks the behavior
  /// under test (the P3 trap).
  Future<void> clearOutbox(String syncId) async {
    await (db.delete(
      db.syncOutbox,
    )..where((o) => o.syncId.equals(syncId))).go();
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

  SyncPushService pusher() => SyncPushService(
    db: db,
    remote: remote,
    ownerId: 'test-owner',
  );

  SyncPullService puller() => SyncPullService(
    db: db,
    remote: remote,
    ownerId: 'test-owner',
  );

  // -- canned server rows (snake_case, as PostgREST returns them;
  // same shapes as the P5 test's builders, which live inside its
  // main() and cannot be imported) --

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

  group('named failure modes', () {
    test('auth errors map to authExpired', () {
      expect(
        classifySyncError(
          SyncFatalException(
            'Supabase rejected the request (401): x',
            PostgrestException(message: 'JWT expired', code: '401'),
          ),
        ),
        SyncFailureMode.authExpired,
      );
      expect(
        classifySyncError(AuthException('session expired')),
        SyncFailureMode.authExpired,
      );
      expect(
        classifySyncError(
          PostgrestException(message: 'Forbidden', code: '403'),
        ),
        SyncFailureMode.authExpired,
      );
    });

    test('503 maps to serverPaused', () {
      expect(
        classifySyncError(
          SyncFatalException(
            'Supabase is unavailable (503): x',
            PostgrestException(message: 'paused', code: '503'),
          ),
        ),
        SyncFailureMode.serverPaused,
      );
      expect(
        classifySyncError(
          PostgrestException(message: 'Service Unavailable', code: '503'),
        ),
        SyncFailureMode.serverPaused,
      );
      expect(
        classifySyncError(Exception('project is paused')),
        SyncFailureMode.serverPaused,
      );
    });

    test('transport failures map to offline, refused maps to paused', () {
      expect(
        classifySyncError(
          const SocketException('Failed host lookup: \'x.supabase.co\''),
        ),
        SyncFailureMode.offline,
      );
      expect(
        classifySyncError(
          SyncFatalException(
            'No connection to Supabase: x',
            const SocketException('Network is unreachable'),
          ),
        ),
        SyncFailureMode.offline,
      );
      expect(
        classifySyncError(TimeoutException('request', Duration.zero)),
        SyncFailureMode.offline,
      );
      expect(
        classifySyncError(
          const SocketException(
            'Connection refused',
            osError: OSError('Connection refused', 111),
          ),
        ),
        SyncFailureMode.serverPaused,
      );
    });

    test('unknown errors stay unknown; keys round-trip', () {
      expect(classifySyncError(Exception('weird')), SyncFailureMode.unknown);
      expect(classifySyncError(null), SyncFailureMode.unknown);
      for (final mode in SyncFailureMode.values) {
        expect(parseSyncFailureMode(syncFailureModeKey(mode)), mode);
      }
      expect(parseSyncFailureMode(null), isNull);
      expect(parseSyncFailureMode('nope'), isNull);
    });

    test('orchestrator records the mode and the log row', () async {
      remote.failUpsertWith = SyncFatalException(
        'Supabase is unavailable (503): x',
        PostgrestException(message: 'paused', code: '503'),
      );
      final wallet = await makeWallet('Cash', 'cash');
      await addExpense(wallet, await foodId(), 5000);
      final result = await orchestrator.syncNow();
      expect(result.error, isNotNull);
      expect(AppPrefs.syncFailureMode, 'serverPaused');
      expect(AppPrefs.syncLastError, contains('503'));
      final log = await db.select(db.syncLog).get();
      expect(log, hasLength(1));
      expect(log.single.failureMode, 'serverPaused');
      // A fatal abort settles nothing (pushed 0), but every queued
      // entry counts as failed — P2's definition: entries left
      // queued by an error, whether per-row failures or never
      // attempted because the run aborted. They stay queued and
      // the next cycle retries them; the mode + error name the
      // cause. (An earlier draft of this test expected failed 0
      // here — wrong: that would understate a run where 29 rows
      // did not sync.)
      expect(log.single.pushed, 0);
      expect(log.single.failed, await db.outboxCount());
      expect(await db.outboxCount(), greaterThan(0));
    });
  });

  group('initial-push seed', () {
    test('enqueues pre-sync rows once, then never again', () async {
      final wallet = await makeWallet('Cash', 'cash');
      final food = await foodId();
      await addExpense(wallet, food, 5000);
      // The wallet + expense already have outbox entries (the
      // helpers enqueue); the account (inserted directly) and the
      // seed categories do not.
      final categories = await db.select(db.categories).get();
      final accountSyncId = await syncIdOf('accounts', 1);
      final added = await db.enqueueAllRowsForInitialPush();
      expect(added, 1 + categories.length);
      final queued = await db.select(db.syncOutbox).get();
      expect(
        queued.where((e) => e.syncId == accountSyncId),
        hasLength(1),
      );
      for (final c in categories) {
        expect(
          queued.where((e) => e.syncId == c.syncId),
          hasLength(1),
        );
      }
      // Idempotent: a second seed adds nothing.
      expect(await db.enqueueAllRowsForInitialPush(), 0);
      expect((await db.select(db.syncOutbox).get()).length, queued.length);
    });
  });

  group('chunked initial push', () {
    test('pushes in bounded chunks and clears the marker', () async {
      final wallet = await makeWallet('Cash', 'cash');
      final food = await foodId();
      for (var i = 0; i < 250; i++) {
        await addExpense(wallet, food, 1000 + i);
      }
      final total = await db.outboxCount();
      expect(total, greaterThan(SyncInitialPushService.chunkSize));
      // Drive cycles the way the triggers do (follow-up while the
      // marker is set) until the backlog drains.
      for (var i = 0; i < 5; i++) {
        final result = await orchestrator.syncNow();
        expect(result.error, isNull);
        if (!orchestrator.initialPushPending) break;
      }
      expect(orchestrator.initialPushPending, isFalse);
      expect(await db.outboxCount(), 0);
      expect(AppPrefs.syncInitialPushTotal, isNull);
      // Every transaction landed exactly once.
      final pushedTxIds = [
        for (final u in remote.upserts)
          if (u.table == 'transactions')
            for (final row in u.rows) row['sync_id'] as String,
      ];
      expect(pushedTxIds.length, 250);
      expect(pushedTxIds.toSet().length, 250);
    });

    test('a killed run resumes where it left off', () async {
      final wallet = await makeWallet('Cash', 'cash');
      final food = await foodId();
      for (var i = 0; i < 250; i++) {
        await addExpense(wallet, food, 1000 + i);
      }
      // Seed first so `before` includes the account + categories
      // the orchestrator would otherwise add mid-cycle (the
      // seed is idempotent, so the orchestrator's own call adds 0).
      await db.enqueueAllRowsForInitialPush();
      final before = await db.outboxCount();
      // Fail the 3rd upsert call: the first internal chunk acks
      // its groups, then the run aborts mid-way.
      remote.failUpsertAfterCalls = 2;
      final first = await orchestrator.syncNow();
      expect(first.error, isNotNull);
      final remaining = await db.outboxCount();
      expect(remaining, lessThan(before));
      expect(remaining, greaterThan(0));
      expect(orchestrator.initialPushPending, isTrue);
      // Resume: the next cycles finish the backlog without
      // re-pushing anything already acked.
      remote.failUpsertAfterCalls = null;
      for (var i = 0; i < 5; i++) {
        final result = await orchestrator.syncNow();
        expect(result.error, isNull);
        if (!orchestrator.initialPushPending) break;
      }
      expect(await db.outboxCount(), 0);
      expect(orchestrator.initialPushPending, isFalse);
      final pushedTxIds = [
        for (final u in remote.upserts)
          if (u.table == 'transactions')
            for (final row in u.rows) row['sync_id'] as String,
      ];
      expect(pushedTxIds.length, 250);
      expect(pushedTxIds.toSet().length, 250);
    });

    test('steady state never takes the chunked path', () async {
      final wallet = await makeWallet('Cash', 'cash');
      await addExpense(wallet, await foodId(), 5000);
      final result = await orchestrator.syncNow();
      expect(result.error, isNull);
      // One small cycle: no marker was ever set.
      expect(AppPrefs.syncInitialPushTotal, isNull);
      expect(orchestrator.initialPushPending, isFalse);
      expect(await db.outboxCount(), 0);
    });
  });

  group('partial-failure handling', () {
    test('one bad row does not block its siblings; retried next cycle',
        () async {
      final wallet = await makeWallet('Cash', 'cash');
      final food = await foodId();
      final good1 = await addExpense(wallet, food, 1000);
      final bad = await addExpense(wallet, food, 2000);
      final good2 = await addExpense(wallet, food, 3000);
      remote.badUpsertIds.add(await syncIdOf('transactions', bad));
      final first = await pusher().pushNow();
      expect(first.failed, 1);
      expect(first.error, isNull);
      expect(await db.outboxCount(), 1);
      // The siblings landed; only the bad row is still queued.
      final landed = [
        for (final u in remote.upserts)
          if (u.table == 'transactions')
            for (final row in u.rows) row['sync_id'] as String,
      ];
      expect(landed, contains(await syncIdOf('transactions', good1)));
      expect(landed, contains(await syncIdOf('transactions', good2)));
      expect(landed, isNot(contains(await syncIdOf('transactions', bad))));
      // Next cycle, with the server accepting the row, it pushes.
      remote.badUpsertIds.clear();
      final second = await pusher().pushNow();
      expect(second.failed, 0);
      expect(await db.outboxCount(), 0);
    });

    test('one malformed pull row does not nuke its page', () async {
      final wallet = await makeWallet('Cash', 'cash');
      final walletSyncId = await syncIdOf('wallets', wallet);
      // The wallet is locally created, so its outbox entry is
      // pending — pull would skip the server wallet row and the
      // cursor could never advance past it. Clear it first: the
      // server row below carries the same content.
      await clearOutbox(walletSyncId);
      final food = await foodId();
      final foodSyncId = await syncIdOf('categories', food);
      final accountSyncId = await syncIdOf('accounts', 1);
      remote.seed('accounts', [accountRow(accountSyncId, ts(1))]);
      remote.seed('categories', [categoryRow(foodSyncId, ts(1))]);
      remote.seed('wallets', [
        walletRow(walletSyncId, accountSyncId, ts(1)),
      ]);
      // One good row and one row whose amount is not a number.
      remote.seed('transactions', [
        txRow('tx-good', walletSyncId, foodSyncId, ts(2), amount: 7000),
        {
          ...txRow('tx-bad', walletSyncId, foodSyncId, ts(3)),
          'amount': 'not-a-number',
        },
      ]);
      final result = await puller().pullNow();
      expect(result.applied, greaterThanOrEqualTo(3));
      expect(result.failed, 1);
      expect(result.error, isNull);
      // The good transaction landed; the bad one holds the cursor
      // back, so it is re-seen next pull.
      final txs = await db.select(db.transactions).get();
      expect(txs.map((t) => t.syncId), contains('tx-good'));
      expect(txs.map((t) => t.syncId), isNot(contains('tx-bad')));
      final cursor = (await db.select(db.syncState).getSingle())
          .lastPullCursor;
      expect(cursor, isNotNull);
      expect(cursor!.compareTo(ts(3)), lessThan(0));
    });
  });

  group('sync log', () {
    test('a cycle records one row; the log caps at 50', () async {
      final wallet = await makeWallet('Cash', 'cash');
      await addExpense(wallet, await foodId(), 5000);
      await orchestrator.syncNow();
      var log = await db.select(db.syncLog).get();
      expect(log, hasLength(1));
      expect(log.single.pushed, greaterThan(0));
      expect(log.single.failureMode, isNull);
      // 55 more runs: the oldest 6 are pruned.
      for (var i = 0; i < 55; i++) {
        await db.recordSyncLog(
          pushed: i,
          pulled: 0,
          conflicts: 0,
          failed: 0,
        );
      }
      log = await db.select(db.syncLog).get();
      expect(log, hasLength(50));
      final ids = log.map((r) => r.id).toList()..sort();
      expect(ids.first, 7);
      expect(ids.last, 56);
    });

    test('a failed cycle logs its mode', () async {
      remote.failUpsertWith = SyncFatalException(
        'No connection to Supabase: x',
        const SocketException('Failed host lookup: \'x.supabase.co\''),
      );
      final wallet = await makeWallet('Cash', 'cash');
      await addExpense(wallet, await foodId(), 5000);
      await orchestrator.syncNow();
      final log = await db.select(db.syncLog).get();
      expect(log, hasLength(1));
      expect(log.single.failureMode, 'offline');
      expect(log.single.error, contains('No connection'));
    });
  });

  group('reconcile timing (SQL-aggregates judgment)', () {
    test('Dart fold at realistic scale', () async {
      final wallet = await makeWallet('Cash', 'cash');
      final food = await foodId();
      // Direct inserts (no outbox, no balance maintenance) — the
      // reconcile is what is measured, not the seeding.
      for (final count in [500, 2000]) {
        await (db.delete(db.transactions)).go();
        await db.transaction(() async {
          for (var i = 0; i < count; i++) {
            await db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                walletId: wallet,
                categoryId: food,
                kind: 'expense',
                amount: 1000 + (i % 97),
                date: DateTime(2026, 11, 1),
              ),
            );
          }
        });
        final sw = Stopwatch()..start();
        await db.reconcileDerivedState();
        sw.stop();
        // Timing measured 2026-11-23: 500 rows 14ms, 2000 rows
        // 22ms — the Dart fold stays; see concept doc §7.
        expect(sw.elapsedMilliseconds, lessThan(2000));
        var expected = 0;
        for (var i = 0; i < count; i++) {
          expected += 1000 + (i % 97);
        }
        final w = await db.getWalletById(wallet);
        expect(w!.balance, -expected);
      }
    });
  });
}

/// Fake remote with injectable push failures, over the P5 fake
/// (which already implements the whole SyncRemote interface over
/// in-memory server rows).
class FailingFakeRemote extends p5.FakeP5Remote {
  /// Sync ids whose group upsert must fail with a data error.
  /// The per-row fallback then fails only these rows.
  final badUpsertIds = <String>{};

  /// Throw this fatal error from every upsert call (null = never).
  SyncFatalException? failUpsertWith;

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
    if (failUpsertWith != null) throw failUpsertWith!;
    if (failUpsertAfterCalls != null &&
        upsertCalls > failUpsertAfterCalls!) {
      throw SyncFatalException('injected fatal');
    }
    if (rows.any((r) => badUpsertIds.contains(r['sync_id'] as String))) {
      throw Exception('injected data error');
    }
    return super.upsert(table, rows);
  }
}
