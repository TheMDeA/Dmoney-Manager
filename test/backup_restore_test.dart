import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:dmoney_manager/core/services/backup_service.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// Restore coverage: a backup must bring back EVERY table —
/// installment plans, recurring rules, templates and category
/// keywords used to be silently dropped — and a damaged or foreign
/// database must be refused before any live data is touched.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('backup_restore_test');
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => root.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<({AppDatabase db, int walletId, int planId})> seedSource() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final walletId = await db.createWallet(
      accountId: 1,
      name: 'SPayLater',
      kind: 'paylater',
      initialAmount: 0,
    );
    final categoryId = await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'Gadget', kind: 'expense'));
    final planId = await db.addPlanWithPurchase(
      walletId: walletId,
      name: 'Phone',
      totalAmount: 300000,
      installmentAmount: 100000,
      totalCount: 3,
      categoryId: categoryId,
    );
    await db.markInstallmentPaid(planId);
    await db
        .into(db.recurringTransactions)
        .insert(
          RecurringTransactionsCompanion.insert(
            walletId: walletId,
            categoryId: categoryId,
            kind: 'expense',
            amount: 50000,
            frequency: 'monthly',
            nextDue: DateTime(2026, 12, 1),
          ),
        );
    await db
        .into(db.transactionTemplates)
        .insert(
          TransactionTemplatesCompanion.insert(
            name: 'Coffee',
            walletId: walletId,
            categoryId: categoryId,
            kind: 'expense',
            amount: 25000,
          ),
        );
    await db
        .into(db.categoryKeywords)
        .insert(
          CategoryKeywordsCompanion.insert(
            keyword: 'kopi',
            categoryId: categoryId,
          ),
        );
    return (db: db, walletId: walletId, planId: planId);
  }

  Future<AppDatabase> seedTargetWithDecoy() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.createWallet(
      accountId: 1,
      name: 'Decoy',
      kind: 'cash',
      initialAmount: 5000,
    );
    return db;
  }

  File packZip(Map<String, List<int>> files, String name) {
    final archive = Archive();
    for (final e in files.entries) {
      archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
    }
    final out = File('${root.path}/$name');
    out.writeAsBytesSync(ZipEncoder().encode(archive)!);
    return out;
  }

  test(
    'restore brings back plans, recurring rules, templates, keywords',
    () async {
      final src = await seedSource();
      addTearDown(src.db.close);
      final zip = await BackupService.createBackup(src.db);

      final target = await seedTargetWithDecoy();
      addTearDown(target.close);
      await BackupService.restoreBackup(target, zip);

      // The decoy wallet is gone; the source wallet is back.
      final wallets = await target.select(target.wallets).get();
      expect(wallets.map((w) => w.name), contains('SPayLater'));
      expect(wallets.map((w) => w.name), isNot(contains('Decoy')));

      // The tables the old restore silently skipped:
      final plans = await target.plansForWallet(src.walletId);
      expect(plans, hasLength(1));
      expect(plans.single.totalCount, 3);
      expect(plans.single.paidCount, 1);
      expect(
        await target.select(target.recurringTransactions).get(),
        hasLength(1),
      );
      expect(
        await target.select(target.transactionTemplates).get(),
        hasLength(1),
      );
      final keywords = await target.select(target.categoryKeywords).get();
      expect(keywords.map((k) => k.keyword), contains('kopi'));

      // And the purchase still points at its plan.
      final txs = await target.select(target.transactions).get();
      expect(txs.where((t) => t.planId == src.planId), hasLength(1));
    },
  );

  test('an empty database file is refused, data intact', () async {
    final target = await seedTargetWithDecoy();
    addTearDown(target.close);
    final manifest = utf8.encode(
      jsonEncode({
        'app': 'dmoney_manager',
        'format': 1,
        'schemaVersion': target.schemaVersion,
        'createdAt': DateTime.now().toIso8601String(),
      }),
    );
    // A zero-byte database used to sail through the old probe: the
    // restore deleted every live table, copied nothing, and still
    // reported success.
    final zip = packZip({
      'manifest.json': manifest,
      'database.sqlite': <int>[],
    }, 'empty.zip');

    await expectLater(
      BackupService.restoreBackup(target, zip),
      throwsA(isA<BackupException>()),
    );
    final wallets = await target.select(target.wallets).get();
    expect(wallets.map((w) => w.name), contains('Decoy'));
  });

  test('a foreign SQLite database is refused, data intact', () async {
    final target = await seedTargetWithDecoy();
    addTearDown(target.close);
    final manifest = utf8.encode(
      jsonEncode({
        'app': 'dmoney_manager',
        'format': 1,
        'schemaVersion': target.schemaVersion,
        'createdAt': DateTime.now().toIso8601String(),
      }),
    );
    // A real SQLite file (so it passes the header check) that simply
    // isn't a Dmoney database.
    final foreignPath = '${root.path}/foreign.sqlite';
    final foreign = sqlite3.sqlite3.open(foreignPath);
    foreign.execute('CREATE TABLE unrelated (x INTEGER)');
    foreign.execute('INSERT INTO unrelated VALUES (1)');
    foreign.close();
    final zip = packZip({
      'manifest.json': manifest,
      'database.sqlite': await File(foreignPath).readAsBytes(),
    }, 'foreign.zip');

    await expectLater(
      BackupService.restoreBackup(target, zip),
      throwsA(isA<BackupException>()),
    );
    final wallets = await target.select(target.wallets).get();
    expect(wallets.map((w) => w.name), contains('Decoy'));
  });

  test('a backup from a newer app version is refused', () async {
    final src = await seedSource();
    addTearDown(src.db.close);
    final good = await BackupService.createBackup(src.db);

    // Re-pack the same backup with a schema version from the future.
    final decoded = ZipDecoder().decodeBytes(await good.readAsBytes());
    final files = <String, List<int>>{};
    for (final f in decoded) {
      if (!f.isFile) continue;
      files[f.name] = f.name == 'manifest.json'
          ? utf8.encode(
              jsonEncode({
                'app': 'dmoney_manager',
                'format': 1,
                'schemaVersion': src.db.schemaVersion + 1,
                'createdAt': DateTime.now().toIso8601String(),
              }),
            )
          : (f.content as List<int>);
    }
    final zip = packZip(files, 'newer.zip');

    final target = await seedTargetWithDecoy();
    addTearDown(target.close);
    await expectLater(
      BackupService.restoreBackup(target, zip),
      throwsA(isA<BackupException>()),
    );
    final wallets = await target.select(target.wallets).get();
    expect(wallets.map((w) => w.name), contains('Decoy'));
  });
}
