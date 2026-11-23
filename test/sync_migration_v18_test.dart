/// v17 -> v18 migration on a realistic book (regression test for the
/// 3.0.0 first-launch boot-splash hang, 2026-11-23).
///
/// On a real device the 3.0.0 build never got past `_BootSplash`:
/// the accounts stream waits on the database opening, and the open
/// runs the v17->v18 migration (42 addColumn + row-by-row sync-id
/// backfill + 14 unique indexes). No test ever migrated a non-empty
/// v17 database — fresh in-memory DBs are created at v18, so the
/// migration path was unexercised.
///
/// The test builds a v17 database the honest way: create the current
/// (v18) schema, seed a realistic book, then strip the v18 additions
/// back out through raw SQL (drop the sync indexes, drop the three
/// sync columns from every data table, drop the five sync tables,
/// set user_version back to 17) and reopen it with AppDatabase.
/// The reopen runs the real migration; the test times it and asserts
/// the book survives it.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/data/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  const txCount = 5000;
  const keywordCount = 100;

  late Directory root;
  late File dbFile;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => root.path,
        );
    root = await Directory.systemTemp.createTemp('v18mig');
    dbFile = File('${root.path}/money_manager.db');
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('migrates a non-empty v17 book to v18', () async {
    // 1. Create the v18 schema + seed, then fill a realistic book.
    final seedDb = AppDatabase.forTesting(NativeDatabase(dbFile));
    final accountId = await seedDb.into(seedDb.accounts).insert(
      AccountsCompanion.insert(name: 'Personal', kind: 'personal'),
    );
    final walletId = await seedDb.createWallet(
      accountId: accountId,
      name: 'Cash',
      kind: 'cash',
    );
    final foodId = (await seedDb.select(seedDb.categories).get())
        .firstWhere((c) => c.name == 'Food')
        .id;
    // One bulk insert: 5,000 expenses spread over 2026. Drift stores
    // datetimes as unix seconds; 1767225600 == 2026-01-01 00:00 UTC.
    await seedDb.customStatement(
      'WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM n '
      'WHERE x < $txCount) '
      'INSERT INTO transactions (wallet_id, category_id, kind, amount, '
      'date, sync_id, updated_at) SELECT $walletId, $foodId, \'expense\', '
      '1000 + (x % 50000), 1767225600 + x * 3600, \'seed-\' || x, '
      '1767225600 FROM n',
    );
    await seedDb.customStatement(
      'WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM n '
      'WHERE x < $keywordCount) '
      'INSERT INTO category_keywords (keyword, category_id, hits, '
      'sync_id, updated_at) SELECT \'kw\' || x, $foodId, 0, '
      '\'seed-kw-\' || x, 1767225600 FROM n',
    );
    expect(
      (await seedDb.customSelect(
        'SELECT COUNT(*) AS c FROM transactions',
      ).getSingle()).read<int>('c'),
      txCount,
    );

    // 2. Downgrade the file to v17: drop the sync indexes, drop the
    // three sync columns from every data table, drop the sync tables,
    // set the version back. (DROP COLUMN fails on indexed columns,
    // so the indexes go first.)
    const syncIndexes = [
      'idx_accounts_sync_id',
      'idx_wallets_sync_id',
      'idx_categories_sync_id',
      'idx_transactions_sync_id',
      'idx_transaction_photos_sync_id',
      'idx_budgets_sync_id',
      'idx_goals_sync_id',
      'idx_debts_sync_id',
      'idx_debt_payments_sync_id',
      'idx_goal_deposits_sync_id',
      'idx_recurring_transactions_sync_id',
      'idx_transaction_templates_sync_id',
      'idx_category_keywords_sync_id',
      'idx_installment_plans_sync_id',
    ];
    for (final idx in syncIndexes) {
      await seedDb.customStatement('DROP INDEX IF EXISTS $idx');
    }
    const syncTables = [
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
      'transactions',
      'transaction_photos',
      'budgets',
      'category_keywords',
    ];
    for (final table in syncTables) {
      for (final column in ['sync_id', 'updated_at', 'deleted_at']) {
        await seedDb.customStatement(
          'ALTER TABLE "$table" DROP COLUMN $column',
        );
      }
    }
    // remote_key is also a v18 addition (P4, folded into the same
    // unreleased step) — it must go too, or the migration's
    // addColumn for it fails as a duplicate.
    await seedDb.customStatement(
      'ALTER TABLE "transaction_photos" DROP COLUMN remote_key',
    );
    for (final table in [
      'sync_outbox',
      'sync_state',
      'sync_pushed',
      'sync_conflicts',
      'sync_log',
      // v19 addition — it must go too, or the v19 migration's
      // createIndex for it fails as a duplicate on reopen.
      'sync_dead_letters',
      // v20 addition — same reason: the v20 migration's
      // createTable for it fails as a duplicate on reopen.
      'sync_pull_cursors',
    ]) {
      await seedDb.customStatement('DROP TABLE IF EXISTS $table');
    }
    await seedDb.customStatement('PRAGMA user_version = 17');
    await seedDb.close();

    // 3. Reopen: this runs the real v17 -> v18 migration. Time it —
    // the first frame waits on this, so it must finish, and fast.
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    final sw = Stopwatch()..start();
    final accounts = await db.select(db.accounts).get();
    sw.stop();
    // ignore: avoid_print — the number is the regression's evidence.
    print('v17->v18 migration ($txCount txs): ${sw.elapsedMilliseconds}ms');
    expect(accounts, hasLength(1));

    final unbackfilled = (await db.customSelect(
      'SELECT COUNT(*) AS c FROM transactions WHERE sync_id = \'\'',
    ).getSingle()).read<int>('c');
    expect(unbackfilled, 0);
    final txIds = (await db.customSelect(
      'SELECT COUNT(DISTINCT sync_id) AS c FROM transactions',
    ).getSingle()).read<int>('c');
    expect(txIds, txCount);

    final indexCount = (await db.customSelect(
      "SELECT COUNT(*) AS c FROM sqlite_master WHERE type = 'index' "
      "AND name LIKE 'idx_%_sync_id'",
    ).getSingle()).read<int>('c');
    expect(indexCount, syncIndexes.length);

    final stateRows = await db.select(db.syncState).get();
    expect(stateRows, hasLength(1));
    expect(await db.select(db.syncOutbox).get(), isEmpty);

    // The migration must be quick — the boot splash waits on it.
    // 60 s is generous (a phone is slower than this host); the
    // pre-fix row-by-row backfill is what this guards against.
    expect(sw.elapsedMilliseconds, lessThan(60000));
    await db.close();
  });
}
