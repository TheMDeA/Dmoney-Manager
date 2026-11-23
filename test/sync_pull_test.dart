import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/services/sync_conflicts_service.dart';
import 'package:dmoney_manager/core/services/sync_pull_service.dart';
import 'package:dmoney_manager/core/services/sync_push_service.dart';
import 'package:dmoney_manager/core/services/sync_remote.dart';
import 'package:dmoney_manager/core/services/sync_serialiser.dart';
import 'package:dmoney_manager/core/utils/sync_payload.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// P3 pull-only sync (schema v18): the pull fetches rows newer
/// than the cursor, applies them parents-before-children inside
/// one local transaction per page, recomputes derived state, and
/// advances the cursor — never past a skipped row. A pull never
/// touches the outbox. No real network in these tests — a fake
/// [SyncRemote] serves canned server rows.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sync_pull_test');
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

  Future<String> syncIdOf(String table, int id) async {
    final row = await db.customSelect(
      'SELECT sync_id FROM "$table" WHERE id = ?',
      variables: [Variable.withInt(id)],
      readsFrom: {},
    ).getSingle();
    return row.read<String>('sync_id');
  }

  Future<String> walletSyncId(int walletId) =>
      syncIdOf('wallets', walletId);

  Future<String> accountSyncId(int accountId) =>
      syncIdOf('accounts', accountId);

  Future<String> categorySyncId(int categoryId) =>
      syncIdOf('categories', categoryId);

  Future<List<SyncOutboxData>> outbox() => db.select(db.syncOutbox).get();

  Future<int> outboxCount() async => (await outbox()).length;

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

  SyncPullService puller(FakePullRemote remote) =>
      SyncPullService(db: db, remote: remote, ownerId: 'test-owner');

  /// Marks a local row as "previously pushed": records the hash
  /// of its current serialised payload (as the push would) and
  /// clears its outbox entries (as the push's ack would). Used to
  /// set up the conflict keeper's gate.
  Future<void> simulatePushed(String table, String syncId) async {
    final maps = await SyncReferenceMaps.load(db);
    final serialiser = SyncSerialiser(
      db: db,
      maps: maps,
      ownerId: 'test-owner',
    );
    final outcome = await serialiser.serialise(table, syncId);
    await db.into(db.syncPushed).insert(
      SyncPushedCompanion.insert(
        syncId: syncId,
        targetTable: table,
        hash: payloadHash(outcome.payload!),
      ),
    );
    await (db.delete(
      db.syncOutbox,
    )..where((o) => o.syncId.equals(syncId))).go();
  }

  /// Deletes the outbox entries for [syncId] without recording a
  /// push hash: the row is treated as already pushed. Tests that
  /// seed a server row for a locally-created row use this so the
  /// pull's pending-outbox skip doesn't mask what the test is
  /// actually exercising (account filtering, cursor hold-back).
  /// Unlike [simulatePushed] it records no hash, so no conflict
  /// entry is produced when the server row differs.
  Future<void> clearOutbox(String syncId) async {
    await (db.delete(
      db.syncOutbox,
    )..where((o) => o.syncId.equals(syncId))).go();
  }

  Future<String?> pullCursor() async =>
      (await db.select(db.syncState).getSingle()).lastPullCursor;

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
    String? parentId,
    int sortOrder = 0,
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
    'parent_id': parentId,
    'sort_order': sortOrder,
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
    String? toWalletId,
    String? planId,
    String? transferId,
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
    'to_wallet_id': toWalletId,
    'debt_id': null,
    'debt_payment_id': null,
    'recurring_id': null,
    'transfer_id': transferId,
    'plan_id': planId,
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

  group('pull applies rows and advances the cursor', () {
    test('inserts parents before children, resolves FKs, stamps sync',
        () async {
      final remote = FakePullRemote();
      remote.seed('accounts', [accountRow('srv-account-1', ts(1))]);
      remote.seed('categories', [
        categoryRow('srv-category-1', ts(2), name: 'Transport'),
      ]);
      remote.seed('wallets', [
        walletRow('srv-wallet-1', 'srv-account-1', ts(3), name: 'Bank'),
      ]);
      remote.seed('transactions', [
        txRow(
          'srv-tx-1',
          'srv-wallet-1',
          'srv-category-1',
          ts(4),
          amount: 12000,
          note: 'Taxi',
        ),
      ]);

      final result = await puller(remote).pullNow();

      expect(result.error, isNull);
      expect(result.pulled, 4);
      expect(result.applied, 4);
      expect(result.tombstoned, 0);
      // The pull fetched tables parents-first.
      final tablesPulled = {
        for (final p in remote.pulls) p.table,
      }.toList();
      expect(
        tablesPulled.indexOf('accounts'),
        lessThan(tablesPulled.indexOf('wallets')),
      );
      expect(
        tablesPulled.indexOf('wallets'),
        lessThan(tablesPulled.indexOf('transactions')),
      );
      // FKs resolved to the new local rows.
      final wallet = await (db.select(
        db.wallets,
      )..where((w) => w.syncId.equals('srv-wallet-1'))).getSingle();
      final category = await (db.select(
        db.categories,
      )..where((c) => c.syncId.equals('srv-category-1'))).getSingle();
      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.syncId.equals('srv-tx-1'))).getSingle();
      expect(tx.walletId, wallet.id);
      expect(tx.categoryId, category.id);
      expect(tx.amount, 12000);
      // The pulled expense moved the pulled wallet's balance
      // (reconcile from the ledger, not the server's balance).
      expect((await db.getWalletById(wallet.id))!.balance, -12000);
      // Cursor advanced to the newest seen timestamp; last sync
      // stamped; the outbox is untouched by a pull.
      expect(await pullCursor(), ts(4));
      expect(
        (await db.select(db.syncState).getSingle()).lastSyncAt,
        isNotNull,
      );
      expect(await outboxCount(), 0);
    });

    test('cursor advances only to the newest seen timestamp', () async {
      final remote = FakePullRemote();
      remote.seed('categories', [
        categoryRow('srv-cat-a', ts(5), name: 'A'),
        categoryRow('srv-cat-b', ts(9), name: 'B'),
      ]);

      final result = await puller(remote).pullNow();

      expect(result.applied, 2);
      expect(await pullCursor(), ts(9));
    });

    test('tombstone deletes the local row', () async {
      final remote = FakePullRemote();
      final wallet = await makeWallet('Old', 'cash');
      final syncId = await walletSyncId(wallet);
      // Direct insert state: no outbox entry, no hash — the
      // tombstone still applies (nothing local to lose).
      await (db.delete(
        db.syncOutbox,
      )..where((o) => o.syncId.equals(syncId))).go();
      remote.seed('wallets', [
        walletRow(
          syncId,
          await accountSyncId(1),
          ts(6),
          deletedAt: ts(6),
        ),
      ]);

      final result = await puller(remote).pullNow();

      expect(result.tombstoned, 1);
      expect(await db.getWalletById(wallet), isNull);
      expect(await pullCursor(), ts(6));
    });

    test('tombstone for an unknown row is a no-op that advances',
        () async {
      final remote = FakePullRemote();
      remote.seed('wallets', [
        walletRow(
          'never-seen',
          await accountSyncId(1),
          ts(7),
          deletedAt: ts(7),
        ),
      ]);

      final result = await puller(remote).pullNow();

      expect(result.tombstoned, 1);
      expect(result.error, isNull);
      expect(await pullCursor(), ts(7));
    });

    test('update applies silently when the row was never pushed',
        () async {
      final remote = FakePullRemote();
      final food = await foodId();
      final syncId = await categorySyncId(food);
      // A seeded row: no outbox entry, no hash record.
      expect(await outboxCount(), 0);
      remote.seed('categories', [
        categoryRow(syncId, ts(8), name: 'Food & Drink'),
      ]);

      final result = await puller(remote).pullNow();

      expect(result.applied, 1);
      expect(result.conflicts, 0);
      final updated = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(food))).getSingle();
      expect(updated.name, 'Food & Drink');
    });

    test('paging fetches 250 transactions in 3 pages', () async {
      final remote = FakePullRemote();
      final wallet = await makeWallet('Cash', 'cash');
      final walletSync = await walletSyncId(wallet);
      final foodSync = await categorySyncId(await foodId());
      remote.seed('transactions', [
        for (var i = 0; i < 250; i++)
          txRow(
            'srv-tx-$i',
            walletSync,
            foodSync,
            // Timestamps repeat every 60 minutes by design here:
            // minute cycles, so order falls back to sync id.
            ts(i % 60),
            amount: 1000 + i,
          ),
      ]);

      final result = await puller(remote).pullNow();

      expect(result.applied, 250);
      expect(result.error, isNull);
      final txPulls = [
        for (final p in remote.pulls)
          if (p.table == 'transactions') p,
      ];
      expect(txPulls.map((p) => p.offset).toList(), [0, 100, 200]);
      expect(txPulls.every((p) => p.limit == 100), isTrue);
      final count = await (db.select(
        db.transactions,
      )).get().then((rows) => rows.length);
      expect(count, 250);
    });

    test('not signed in pulls nothing', () async {
      final remote = FakePullRemote();
      remote.seed('categories', [categoryRow('srv-cat-1', ts(1))]);
      final service = SyncPullService(
        db: db,
        remote: remote,
        ownerId: null,
      );

      final result = await service.pullNow();

      expect(result.notSignedIn, isTrue);
      expect(result.pulled, 0);
      expect(remote.pulls, isEmpty);
      expect(await pullCursor(), isNull);
    });

    test('pull failure aborts without advancing the cursor', () async {
      final remote = FakePullRemote()..failTables.add('wallets');
      remote.seed('accounts', [accountRow('srv-account-1', ts(1))]);
      remote.seed('wallets', [
        walletRow('srv-wallet-1', 'srv-account-1', ts(2)),
      ]);

      final result = await puller(remote).pullNow();

      expect(result.error, isA<SyncFatalException>());
      // The accounts page stayed applied (the apply is
      // idempotent); the cursor did not move, so the wallets
      // rows are re-fetched on the next run, not lost.
      expect(
        await (db.select(
          db.accounts,
        )..where((a) => a.syncId.equals('srv-account-1'))).get(),
        hasLength(1),
      );
      expect(await pullCursor(), isNull);
    });
  });

  group('conflict keeper (idea #1)', () {
    test('records the loser, Restore re-pushes it as newest', () async {
      final remote = FakePullRemote();
      final wallet = await makeWallet('Cash', 'cash');
      final syncId = await walletSyncId(wallet);
      await simulatePushed('wallets', syncId);
      remote.seed('wallets', [
        walletRow(
          syncId,
          await accountSyncId(1),
          ts(10),
          name: 'Cash renamed',
        ),
      ]);

      final result = await puller(remote).pullNow();

      expect(result.conflicts, 1);
      expect(result.applied, 1);
      expect((await db.getWalletById(wallet))!.name, 'Cash renamed');
      final conflicts = await db.select(db.syncConflicts).get();
      expect(conflicts.length, 1);
      expect(conflicts.single.targetTable, 'wallets');
      expect(conflicts.single.syncId, syncId);
      expect(conflicts.single.winningDevice, isNull);
      final loser =
          jsonDecode(conflicts.single.losingJson) as Map<String, dynamic>;
      expect(loser['name'], 'Cash');
      expect(loser['sync_id'], syncId);

      // Restore brings the old name back as a new local edit.
      final ok = await SyncConflictService(
        db,
      ).restoreConflict(conflicts.single);
      expect(ok, isTrue);
      expect((await db.getWalletById(wallet))!.name, 'Cash');
      expect(await db.select(db.syncConflicts).get(), isEmpty);
      final entries = await outbox();
      expect(entries.length, 1);
      expect(entries.single.targetTable, 'wallets');
      expect(entries.single.syncId, syncId);
      expect(entries.single.op, 'update');

      // A re-pull of a newer server row does not record a second
      // conflict: the restored edit is still pending, so pull
      // skips it. (Checked before the push below, while the
      // restored edit is still queued.)
      remote.seed('wallets', [
        walletRow(
          syncId,
          await accountSyncId(1),
          ts(12),
          name: 'Cash renamed',
        ),
      ]);
      final again = await puller(remote).pullNow();
      expect(again.skippedPendingOutbox, 1);
      expect(again.conflicts, 0);
      expect((await db.getWalletById(wallet))!.name, 'Cash');

      // The restored row pushes as the newest change.
      final recording = _RecordingRemote();
      await SyncPushService(
        db: db,
        remote: recording,
        ownerId: 'test-owner',
      ).pushNow();
      expect(recording.upserts.length, 1);
      expect(recording.upserts.single.table, 'wallets');
      expect(recording.upserts.single.rows.single['name'], 'Cash');
      expect(await outboxCount(), 0);
    });

    test('identical content records no conflict', () async {
      final remote = FakePullRemote();
      final wallet = await makeWallet('Cash', 'cash');
      final syncId = await walletSyncId(wallet);
      await simulatePushed('wallets', syncId);
      // The server row is this device's own last push, coming
      // back (e.g. after a cursor reset): same content, so the
      // overwrite is a no-op, not a conflict.
      final maps = await SyncReferenceMaps.load(db);
      final serialiser = SyncSerialiser(
        db: db,
        maps: maps,
        ownerId: 'test-owner',
      );
      final payload =
          (await serialiser.serialise('wallets', syncId)).payload!;
      remote.seed('wallets', [
        {
          ...payload,
          'server_updated_at': ts(11),
          // As PostgREST returns it: the server's `updated_at`
          // column in `+00:00` form. It is local bookkeeping,
          // not row content, so it must not trigger a conflict.
          'updated_at': '2026-11-23T09:00:00+00:00',
        },
      ]);

      final result = await puller(remote).pullNow();

      expect(result.conflicts, 0);
      expect(result.applied, 1);
      expect(await db.select(db.syncConflicts).get(), isEmpty);
    });

    test('derived-only differences record no conflict', () async {
      final remote = FakePullRemote();
      final wallet = await makeWallet('Cash', 'cash', initialAmount: 1000);
      final syncId = await walletSyncId(wallet);
      await simulatePushed('wallets', syncId);
      // Another device's copy of the same wallet, whose
      // maintained balance drifted — the balance is derived, so
      // this is not an edit being lost.
      final maps = await SyncReferenceMaps.load(db);
      final serialiser = SyncSerialiser(
        db: db,
        maps: maps,
        ownerId: 'test-owner',
      );
      final payload =
          (await serialiser.serialise('wallets', syncId)).payload!;
      remote.seed('wallets', [
        {
          ...payload,
          'server_updated_at': ts(12),
          'balance': 424242,
          'updated_at': '2026-11-23T09:00:00+00:00',
        },
      ]);

      final result = await puller(remote).pullNow();

      expect(result.conflicts, 0);
      // The server balance was not applied either — the local
      // maintained balance stands until the reconcile runs.
      expect((await db.getWalletById(wallet))!.balance, 1000);
    });

    test('dismiss drops the entry without restoring', () async {
      final remote = FakePullRemote();
      final wallet = await makeWallet('Cash', 'cash');
      final syncId = await walletSyncId(wallet);
      await simulatePushed('wallets', syncId);
      remote.seed('wallets', [
        walletRow(
          syncId,
          await accountSyncId(1),
          ts(10),
          name: 'Cash renamed',
        ),
      ]);
      await puller(remote).pullNow();
      final conflicts = await db.select(db.syncConflicts).get();
      expect(conflicts.length, 1);

      await SyncConflictService(db).dismissConflict(conflicts.single.id);

      expect(await db.select(db.syncConflicts).get(), isEmpty);
      expect((await db.getWalletById(wallet))!.name, 'Cash renamed');
      expect(await outboxCount(), 0);
    });
  });

  group('skip rules and the cursor', () {
    test('pending outbox entries are skipped, then apply after push',
        () async {
      final remote = FakePullRemote();
      final wallet = await makeWallet('Cash', 'cash');
      final syncId = await walletSyncId(wallet);
      // The create enqueued an outbox entry: the push has not
      // run yet, so pull must not overwrite the local edit.
      expect(await outboxCount(), 1);
      remote.seed('wallets', [
        walletRow(
          syncId,
          await accountSyncId(1),
          ts(10),
          name: 'Cash renamed',
        ),
      ]);

      final skipped = await puller(remote).pullNow();

      expect(skipped.skippedPendingOutbox, 1);
      expect(skipped.applied, 0);
      expect((await db.getWalletById(wallet))!.name, 'Cash');
      // The cursor did not advance past the skipped row.
      expect(await pullCursor(), isNull);

      // Once the edit is pushed, the next pull applies the
      // server row (and the pushed hash means the overwrite is
      // recorded as a conflict — the local edit lost to a newer
      // remote edit).
      await simulatePushed('wallets', syncId);
      final applied = await puller(remote).pullNow();

      expect(applied.skippedPendingOutbox, 0);
      expect(applied.applied, 1);
      expect(applied.conflicts, 1);
      expect((await db.getWalletById(wallet))!.name, 'Cash renamed');
      expect(await pullCursor(), ts(10));
    });

    test('per-account pull filtering holds back, then syncs on toggle',
        () async {
      final remote = FakePullRemote();
      final account2 = await makeAccount('Work');
      final account2Sync = await accountSyncId(account2);
      final wallet2 = await makeWallet(
        'Work cash',
        'cash',
        accountId: account2,
      );
      final wallet2Sync = await walletSyncId(wallet2);
      final txId = await addExpense(wallet2, await foodId(), 9000);
      final txSync = await syncIdOf('transactions', txId);
      final foodSync = await categorySyncId(await foodId());
      // The rows were created locally (outbox pending) — clear
      // that, so the pulls exercise account filtering rather
      // than the pending-outbox skip.
      await clearOutbox(account2Sync);
      await clearOutbox(wallet2Sync);
      await clearOutbox(txSync);
      await AppPrefs.setSyncAccountIds([1]);
      remote.seed('accounts', [
        accountRow(account2Sync, ts(10), name: 'Work renamed'),
      ]);
      remote.seed('wallets', [
        walletRow(
          wallet2Sync,
          account2Sync,
          ts(11),
          name: 'Work cash renamed',
        ),
      ]);
      remote.seed('transactions', [
        txRow(txSync, wallet2Sync, foodSync, ts(12), amount: 9500),
      ]);

      final skipped = await puller(remote).pullNow();

      expect(skipped.skippedAccountOff, 3);
      expect(skipped.applied, 0);
      expect(await pullCursor(), isNull);
      final accountRowAfter = await (db.select(
        db.accounts,
      )..where((a) => a.id.equals(account2))).getSingle();
      expect(accountRowAfter.name, 'Work');
      expect((await db.getWalletById(wallet2))!.name, 'Work cash');

      await AppPrefs.setSyncAccountIds([1, account2]);
      final synced = await puller(remote).pullNow();

      expect(synced.skippedAccountOff, 0);
      expect(synced.applied, 3);
      expect(
        (await (db.select(
          db.accounts,
        )..where((a) => a.id.equals(account2))).getSingle()).name,
        'Work renamed',
      );
      expect(
        (await db.getWalletById(wallet2))!.name,
        'Work cash renamed',
      );
      expect(await pullCursor(), ts(12));
    });

    test('cursor holds back at the oldest skipped row', () async {
      final remote = FakePullRemote();
      final account2 = await makeAccount('Work');
      final account2Sync = await accountSyncId(account2);
      final wallet2 = await makeWallet(
        'Work cash',
        'cash',
        accountId: account2,
      );
      final wallet2Sync = await walletSyncId(wallet2);
      // The wallet was created locally (outbox pending) — clear
      // that, so the second pull exercises the cursor hold-back
      // rather than the pending-outbox skip.
      await clearOutbox(wallet2Sync);
      await AppPrefs.setSyncAccountIds([1]);
      remote.seed('categories', [
        categoryRow('srv-cat-old', ts(20), name: 'Old'),
        categoryRow('srv-cat-new', ts(22), name: 'New'),
      ]);
      remote.seed('wallets', [
        walletRow(wallet2Sync, account2Sync, ts(21), name: 'Renamed'),
      ]);

      final result = await puller(remote).pullNow();

      expect(result.skippedAccountOff, 1);
      expect(result.applied, 2);
      // The newest applied row strictly older than the skipped
      // row's ts(21) is ts(20) — not ts(22).
      expect(await pullCursor(), ts(20));

      await AppPrefs.setSyncAccountIds([1, account2]);
      final synced = await puller(remote).pullNow();

      // The ts(20) category row is not re-fetched (its timestamp
      // equals the cursor) — only the two newer rows apply.
      expect(synced.applied, 2);
      expect(await pullCursor(), ts(22));
    });

    test('unresolvable FK is skipped and held back', () async {
      final remote = FakePullRemote();
      final foodSync = await categorySyncId(await foodId());
      remote.seed('transactions', [
        txRow(
          'srv-tx-orphan',
          'missing-wallet',
          foodSync,
          ts(15),
          amount: 7000,
        ),
      ]);

      final result = await puller(remote).pullNow();

      expect(result.skippedUnresolved, 1);
      expect(result.applied, 0);
      expect(await pullCursor(), isNull);
      expect(
        await (db.select(
          db.transactions,
        )..where((t) => t.syncId.equals('srv-tx-orphan'))).get(),
        isEmpty,
      );
    });

    test('photo rows apply and no longer hold the cursor back', () async {
      final remote = FakePullRemote();
      remote.seed('accounts', [accountRow('srv-account-1', ts(1))]);
      remote.seed('wallets', [
        walletRow('srv-wallet-1', 'srv-account-1', ts(2)),
      ]);
      final foodSync = await categorySyncId(await foodId());
      remote.seed('transactions', [
        txRow('srv-tx-1', 'srv-wallet-1', foodSync, ts(15)),
      ]);
      remote.seed('transaction_photos', [
        photoRow('srv-photo-1', 'srv-tx-1', ts(16)),
      ]);

      final result = await puller(remote).pullNow();

      // Account + wallet + transaction + photo, all applied.
      expect(result.applied, 4);
      expect(result.failed, 0);
      expect(await pullCursor(), ts(16));
      final photos = await db.select(db.transactionPhotos).get();
      expect(photos, hasLength(1));
      expect(photos.single.syncId, 'srv-photo-1');
      expect(
        photos.single.remoteKey,
        'receipts/test-owner/srv-tx-1/srv-photo-1.jpg',
      );
      expect(photos.single.path, '${root.path}/receipts/srv-photo-1.jpg');
      // Lazy (§9): the row applies with no bytes on disk — the
      // file is fetched when the photo is opened.
      expect(await File(photos.single.path).exists(), isFalse);
    });
  });

  group('derived-state reconcile (§7)', () {
    /// Builds a realistic book on three wallets, then returns the
    /// incrementally maintained derived values to compare against.
    /// Expected arithmetic (verified by hand):
    ///   Cash:    100000 + 200000 − 50000 − 30000 − 1000 (fee)
    ///            − 100000 (debt A lent) + 40000 (payment in)
    ///            − 50000 (debt C lent, no history) = 109000
    ///   Bank:     50000 + 30000 − 100000 − 100000 (two plan
    ///            payments) + 80000 (debt B borrowed, no history)
    ///            − 30000 (payment out) = −70000
    ///   Paylater: 0 − 1200000 (purchase) + 100000 + 100000
    ///            (two payments) = −1000000; paidCount 2
    ///   Goal 'Trip': 50000 − 10000 = 40000 saved.
    ///   Debts A/B/C: none fully paid.
    Future<
      ({
        int cash,
        int bank,
        int paylater,
        int plan,
        int goal,
        int debtA,
        int debtB,
        int debtC,
      })
    >
    buildBook() async {
      final food = await foodId();
      final cash = await makeWallet(
        'Cash',
        'cash',
        initialAmount: 100000,
      );
      final bank = await makeWallet(
        'Bank',
        'bank',
        initialAmount: 50000,
      );
      final paylater = await makeWallet('ShopeePaylater', 'paylater');
      await db.addTransaction(
        TransactionsCompanion.insert(
          walletId: cash,
          categoryId: food,
          kind: 'income',
          amount: 200000,
          date: DateTime(2026, 11, 1),
        ),
      );
      await addExpense(cash, food, 50000);
      await db.addTransfer(
        fromWalletId: cash,
        toWalletId: bank,
        amount: 30000,
        fee: 1000,
        date: DateTime(2026, 11, 2),
      );
      final plan = await db.addPlanWithPurchase(
        walletId: paylater,
        name: 'Phone',
        totalAmount: 1200000,
        installmentAmount: 100000,
        totalCount: 12,
        categoryId: food,
      );
      for (var i = 0; i < 2; i++) {
        await db.addTransfer(
          fromWalletId: bank,
          toWalletId: paylater,
          amount: 100000,
          note: 'Installment payment: Phone',
          date: DateTime(2026, 11, 3 + i),
          planId: plan,
        );
        await db.markInstallmentPaid(plan);
      }
      final goal = await db.addGoal(
        GoalsCompanion.insert(name: 'Trip', target: 1000000),
      );
      await db.recordGoalDeposit(
        goalId: goal,
        amount: 50000,
        date: DateTime(2026, 11, 4),
      );
      await db.recordGoalDeposit(
        goalId: goal,
        amount: -10000,
        date: DateTime(2026, 11, 5),
      );
      final debtA = await db.createDebt(
        person: 'Andi',
        note: '',
        amount: 100000,
        direction: 'receivable',
        walletId: cash,
        recordAsTransaction: true,
      );
      await db.recordDebtPayment(
        debt: (await db.getDebtById(debtA))!,
        amount: 40000,
        date: DateTime(2026, 11, 6),
        walletId: cash,
      );
      final debtB = await db.createDebt(
        person: 'Budi',
        note: '',
        amount: 80000,
        direction: 'payable',
        walletId: bank,
        recordAsTransaction: false,
      );
      await db.recordDebtPayment(
        debt: (await db.getDebtById(debtB))!,
        amount: 30000,
        date: DateTime(2026, 11, 7),
        walletId: bank,
      );
      final debtC = await db.createDebt(
        person: 'Citra',
        note: '',
        amount: 50000,
        direction: 'receivable',
        walletId: cash,
        recordAsTransaction: false,
      );
      return (
        cash: cash,
        bank: bank,
        paylater: paylater,
        plan: plan,
        goal: goal,
        debtA: debtA,
        debtB: debtB,
        debtC: debtC,
      );
    }

    Future<int> walletBalance(int id) async =>
        (await db.getWalletById(id))!.balance;

    test('recomputed values match the maintained ones', () async {
      final ids = await buildBook();

      // Sanity: the maintained values are what the hand
      // computation says, so the test compares against a
      // known-good baseline, not against itself.
      expect(await walletBalance(ids.cash), 109000);
      expect(await walletBalance(ids.bank), -70000);
      expect(await walletBalance(ids.paylater), -1000000);
      expect((await db.getInstallmentPlan(ids.plan))!.paidCount, 2);
      expect((await db.getGoalById(ids.goal))!.saved, 40000);
      expect((await db.getDebtById(ids.debtA))!.isPaid, isFalse);
      expect((await db.getDebtById(ids.debtB))!.isPaid, isFalse);
      expect((await db.getDebtById(ids.debtC))!.isPaid, isFalse);

      // Corrupt every derived value, then reconcile.
      for (final id in [ids.cash, ids.bank, ids.paylater]) {
        await (db.update(
          db.wallets,
        )..where((w) => w.id.equals(id))).write(
          const WalletsCompanion(balance: Value(999999)),
        );
      }
      await (db.update(
        db.installmentPlans,
      )..where((p) => p.id.equals(ids.plan))).write(
        const InstallmentPlansCompanion(paidCount: Value(99)),
      );
      await (db.update(
        db.goals,
      )..where((g) => g.id.equals(ids.goal))).write(
        const GoalsCompanion(saved: Value(1)),
      );
      await (db.update(
        db.debts,
      )..where((d) => d.id.equals(ids.debtA))).write(
        const DebtsCompanion(isPaid: Value(true)),
      );

      final result = await db.reconcileDerivedState();

      expect(result.walletsChanged, 3);
      expect(result.plansChanged, 1);
      expect(result.goalsChanged, 1);
      expect(result.debtsChanged, 1);
      expect(await walletBalance(ids.cash), 109000);
      expect(await walletBalance(ids.bank), -70000);
      expect(await walletBalance(ids.paylater), -1000000);
      expect((await db.getInstallmentPlan(ids.plan))!.paidCount, 2);
      expect((await db.getGoalById(ids.goal))!.saved, 40000);
      expect((await db.getDebtById(ids.debtA))!.isPaid, isFalse);

      // Idempotent: a second run changes nothing.
      final again = await db.reconcileDerivedState();
      expect(again.walletsChanged, 0);
      expect(again.plansChanged, 0);
      expect(again.goalsChanged, 0);
      expect(again.debtsChanged, 0);
    });

    test('reconcile heals the double-reversed debt payment', () async {
      final cash = await makeWallet('Cash', 'cash');
      final debtId = await db.createDebt(
        person: 'Andi',
        note: '',
        amount: 100000,
        direction: 'receivable',
        walletId: cash,
        recordAsTransaction: true,
      );
      final debt = (await db.getDebtById(debtId))!;
      await db.recordDebtPayment(
        debt: debt,
        amount: 40000,
        date: DateTime(2026, 11, 6),
        walletId: cash,
      );
      expect(await walletBalance(cash), -60000);
      final payment = await (db.select(
        db.debtPayments,
      )..where((p) => p.debtId.equals(debtId))).getSingle();
      final linkedTx = await (db.select(
        db.transactions,
      )..where((t) => t.debtPaymentId.equals(payment.id))).getSingle();

      // The payment's linked transaction is deleted directly
      // (e.g. from the transaction list), then the payment itself
      // is deleted: deleteDebtPayment reverses the wallet effect
      // even though the transaction is already gone — the
      // maintained balance is now wrong by one payment.
      await db.deleteTransaction(linkedTx.id);
      expect(await walletBalance(cash), -100000);
      await db.deleteDebtPayment(payment, debt);
      expect(await walletBalance(cash), -140000);

      final result = await db.reconcileDerivedState();

      expect(result.walletsChanged, 1);
      expect(await walletBalance(cash), -100000);
      expect((await db.getDebtById(debtId))!.isPaid, isFalse);
    });

    test('a pull reconciles derived state afterwards', () async {
      final remote = FakePullRemote();
      final foodSync = await categorySyncId(await foodId());
      final wallet = await makeWallet('Cash', 'cash', initialAmount: 5000);
      final walletSync = await walletSyncId(wallet);
      // Corrupt the local balance, then pull a new expense on
      // that wallet: the reconcile after the pull must rebuild
      // the balance from the ledger, not trust the corrupt one.
      await (db.update(
        db.wallets,
      )..where((w) => w.id.equals(wallet))).write(
        const WalletsCompanion(balance: Value(777777)),
      );
      remote.seed('transactions', [
        txRow(
          'srv-tx-1',
          walletSync,
          foodSync,
          ts(30),
          amount: 2000,
        ),
      ]);
      // The wallet row itself is not in the pull, so the
      // reconcile is the only thing that can fix the balance.
      await puller(remote).pullNow();

      expect(await walletBalance(wallet), 5000 - 2000);
    });
  });
}

/// Fake [SyncRemote] for pull tests: serves canned server rows
/// per table, applying the same filter/order/page semantics the
/// real PostgREST query has (server_updated_at > updatedAfter,
/// ordered by server_updated_at then sync_id, offset/limit).
class FakePullRemote implements SyncRemote {
  final serverRows = <String, List<Map<String, dynamic>>>{};
  final pulls = <({String table, String? updatedAfter, int offset, int limit})>[];
  final failTables = <String>{};
  // P4: in-memory Storage objects (key → bytes).
  final objects = <String, Uint8List>{};

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
    pulls.add((
      table: table,
      updatedAfter: updatedAfter,
      offset: offset,
      limit: limit,
    ));
    if (failTables.contains(table)) {
      throw SyncFatalException('fake pull failure on $table');
    }
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
  ) async {}

  @override
  Future<void> tombstone(
    String table,
    List<String> syncIds,
    DateTime deletedAt,
  ) async {}

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
    // The server trigger stamps the row — the fake stamps with
    // the wall clock, like the real trigger.
    prefsRow = {
      ...row,
      'server_updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

/// Push-only recording fake for the conflict Restore test: the
/// restored row must leave as an upsert payload.
class _RecordingRemote implements SyncRemote {
  final upserts = <({String table, List<Map<String, dynamic>> rows})>[];

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
  ) async {}

  @override
  Future<void> uploadPhoto(String key, File file) async {}

  @override
  Future<Uint8List> downloadPhoto(String key) async => Uint8List(0);

  @override
  Future<void> deletePhotoObject(String key) async {}

  @override
  Future<Map<String, dynamic>?> fetchRow(
    String table,
    String syncId,
  ) async => null;

  @override
  Future<List<Map<String, dynamic>>> pull(
    String table,
    String? updatedAfter,
    int offset,
    int limit,
  ) async => [];

  // P5: the conflict Restore test never counts, lists devices or
  // syncs prefs.
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
