/// v19 -> v20 migration on a small book (regression test for the
/// sync-stall fix, 2026-11-23).
///
/// v20 adds the `sync_pull_cursors` table (one pull cursor per
/// table, advanced after every page). The test builds a v20
/// database the honest way (create the current schema, seed a
/// small book, stamp the global pull cursor), strips the v20
/// addition back out through raw SQL, and reopens it with
/// AppDatabase. The reopen runs the real migration; the test
/// asserts the book survives it and the new table works.
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/data/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late Directory root;
  late File dbFile;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => root.path,
        );
    root = await Directory.systemTemp.createTemp('v20mig');
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

  test('migrates a non-empty v19 book to v20', () async {
    // 1. Create the v20 schema + seed, fill a small book, stamp
    // the global pull cursor (as a v19 pull would have left it).
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
    await seedDb.addTransaction(
      TransactionsCompanion.insert(
        walletId: walletId,
        categoryId: foodId,
        kind: 'expense',
        amount: 5000,
        date: DateTime(2026, 11, 1),
      ),
    );
    await (seedDb.update(
      seedDb.syncState,
    )..where((s) => s.id.equals(1))).write(
      const SyncStateCompanion(
        lastPullCursor: Value('2026-11-23T10:00:00.000Z'),
      ),
    );
    expect(
      (await seedDb.customSelect(
        'SELECT COUNT(*) AS c FROM transactions',
      ).getSingle()).read<int>('c'),
      1,
    );

    // 2. Downgrade the file to v19: drop the per-table cursors
    // table, set the version back.
    await seedDb.customStatement('DROP TABLE IF EXISTS sync_pull_cursors');
    await seedDb.customStatement('PRAGMA user_version = 19');
    await seedDb.close();

    // 3. Reopen: this runs the real v19 -> v20 migration.
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    final accounts = await db.select(db.accounts).get();
    expect(accounts, hasLength(1));
    expect(
      (await db.customSelect(
        'SELECT COUNT(*) AS c FROM transactions',
      ).getSingle()).read<int>('c'),
      1,
    );

    // The global cursor survives the migration.
    expect(
      (await db.select(db.syncState).getSingle()).lastPullCursor,
      '2026-11-23T10:00:00.000Z',
    );

    // The new table works: a per-table cursor stores and reads
    // back, and a table without one falls back to null (the
    // pull falls back to the global cursor instead).
    expect(await db.pullCursorFor('wallets'), isNull);
    await db.setPullCursor('wallets', '2026-11-23T10:05:00.000Z');
    expect(await db.pullCursorFor('wallets'), '2026-11-23T10:05:00.000Z');
    await db.setPullCursor('wallets', '2026-11-23T10:06:00.000Z');
    expect(await db.pullCursorFor('wallets'), '2026-11-23T10:06:00.000Z');
    await db.clearPullCursors();
    expect(await db.pullCursorFor('wallets'), isNull);

    // The migration leaves the database at v20.
    final version = (await db.customSelect(
      'PRAGMA user_version',
    ).getSingle()).read<int>('user_version');
    expect(version, 20);
    await db.close();
  });
}
