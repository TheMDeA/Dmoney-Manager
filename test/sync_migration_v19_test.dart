/// v18 -> v19 migration on a small book (regression test for the
/// audit-round-2 diagnostics batch, 2026-11-23).
///
/// v19 adds the `sync_dead_letters` table and five nullable
/// diagnostic columns on `sync_log`. The test builds a v19
/// database the honest way (create the current schema, seed a
/// small book, write one log row), strips the v19 additions back
/// out through raw SQL, and reopens it with AppDatabase. The
/// reopen runs the real migration; the test asserts the book
/// survives it and the new structures work.
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

  late Directory root;
  late File dbFile;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => root.path,
        );
    root = await Directory.systemTemp.createTemp('v19mig');
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

  test('migrates a non-empty v18 book to v19', () async {
    // 1. Create the v19 schema + seed, then fill a small book and
    // one log row (old columns only — it predates v19).
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
    await seedDb.recordSyncLog(
      pushed: 3,
      pulled: 2,
      conflicts: 0,
      failed: 0,
    );
    expect(
      (await seedDb.customSelect(
        'SELECT COUNT(*) AS c FROM transactions',
      ).getSingle()).read<int>('c'),
      1,
    );

    // 2. Downgrade the file to v18: drop the dead-letters table
    // and the five v19 log columns, set the version back.
    await seedDb.customStatement('DROP TABLE IF EXISTS sync_dead_letters');
    for (final column in [
      'duration_ms',
      'phase',
      'skipped',
      'first_failed_table',
      'first_failed_sync_id',
    ]) {
      await seedDb.customStatement(
        'ALTER TABLE "sync_log" DROP COLUMN $column',
      );
    }
    await seedDb.customStatement('PRAGMA user_version = 18');
    await seedDb.close();

    // 3. Reopen: this runs the real v18 -> v19 migration.
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    final accounts = await db.select(db.accounts).get();
    expect(accounts, hasLength(1));
    expect(
      (await db.customSelect(
        'SELECT COUNT(*) AS c FROM transactions',
      ).getSingle()).read<int>('c'),
      1,
    );

    // The pre-migration log row survives, with null diagnostics.
    final logs = await db.select(db.syncLog).get();
    expect(logs, hasLength(1));
    expect(logs.single.pushed, 3);
    expect(logs.single.durationMs, isNull);
    expect(logs.single.phase, isNull);
    expect(logs.single.firstFailedTable, isNull);

    // The new structures work.
    await db.recordDeadLetter(
      targetTable: 'transaction_photos',
      syncId: 'photo-1',
      reason: 'photo_file_missing',
    );
    expect(await db.select(db.syncDeadLetters).get(), hasLength(1));
    await db.recordSyncLog(
      pushed: 0,
      pulled: 0,
      conflicts: 0,
      failed: 1,
      failureMode: 'partial',
      error: 'wallets/abc: upsert failed',
      durationMs: 42,
      phase: 'both',
      skipped: 1,
      firstFailedTable: 'wallets',
      firstFailedSyncId: 'abc',
    );
    final latest = (await db.select(db.syncLog).get()).last;
    expect(latest.durationMs, 42);
    expect(latest.phase, 'both');
    expect(latest.firstFailedSyncId, 'abc');

    // The migration leaves the database at the current schema
    // version — reopening a v18 file runs every migration step
    // up to it (v20 today), not just the v19 step.
    final version = (await db.customSelect(
      'PRAGMA user_version',
    ).getSingle()).read<int>('user_version');
    expect(version, 20);
    await db.close();
  });
}
