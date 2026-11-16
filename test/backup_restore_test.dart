import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
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

  test('a pre-v17 backup relinks plans to their purchase and payments',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final paylaterId = await db.createWallet(
      accountId: 1,
      name: 'SPayLater',
      kind: 'paylater',
      initialAmount: 0,
    );
    final fundingId = await db.createWallet(
      accountId: 1,
      name: 'BCA',
      kind: 'bank',
      initialAmount: 1000000,
    );
    final categoryId = await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'Gadget', kind: 'expense'));

    // Two plans with the SAME total on the same wallet — the matcher
    // must not cross-link them (the purchase note disambiguates).
    final phoneId = await db.addPlanWithPurchase(
      walletId: paylaterId,
      name: 'Phone',
      totalAmount: 300000,
      installmentAmount: 100000,
      totalCount: 3,
      categoryId: categoryId,
    );
    final tabletId = await db.addPlanWithPurchase(
      walletId: paylaterId,
      name: 'Tablet',
      totalAmount: 300000,
      installmentAmount: 150000,
      totalCount: 2,
      categoryId: categoryId,
    );
    // One installment paid on the Phone plan only.
    await db.addTransfer(
      fromWalletId: fundingId,
      toWalletId: paylaterId,
      amount: 100000,
      note: 'Installment payment: Phone',
      planId: phoneId,
    );
    await db.markInstallmentPaid(phoneId);

    // A backdated purchase (auto-plan shape): the expense predates the
    // plan by 30 days and its note is not the plan name, so only
    // amount + date can identify it.
    final watchId = await db.addInstallmentPlan(
      walletId: paylaterId,
      name: 'Watch',
      totalAmount: 120000,
      installmentAmount: 60000,
      totalCount: 2,
    );
    final watchPurchaseId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            walletId: paylaterId,
            categoryId: categoryId,
            kind: 'expense',
            amount: 120000,
            note: const Value('Tokopedia'),
            date: DateTime.now().subtract(const Duration(days: 30)),
          ),
        );
    await db.adjustWalletBalance(paylaterId, -120000);
    await db.setTransactionPlan(watchPurchaseId, watchId);

    final zip = await BackupService.createBackup(db);

    // Downgrade the backup to schema 16: drop the plan_id column and
    // rewrite the manifest, exactly as a backup made by 2.7.1 would
    // look — every transaction arrives unlinked.
    final decoded = ZipDecoder().decodeBytes(await zip.readAsBytes());
    final files = <String, List<int>>{};
    for (final f in decoded) {
      if (!f.isFile) continue;
      if (f.name == 'database.sqlite') {
        final dbPath = '${root.path}/v16.sqlite';
        await File(dbPath).writeAsBytes(f.content as List<int>);
        final raw = sqlite3.sqlite3.open(dbPath);
        raw.execute('ALTER TABLE transactions DROP COLUMN plan_id');
        raw.close();
        files[f.name] = await File(dbPath).readAsBytes();
      } else if (f.name == 'manifest.json') {
        files[f.name] = utf8.encode(
          jsonEncode({
            'app': 'dmoney_manager',
            'format': 1,
            'schemaVersion': 16,
            'createdAt': DateTime.now().toIso8601String(),
          }),
        );
      } else {
        files[f.name] = f.content as List<int>;
      }
    }
    final oldZip = packZip(files, 'v16.zip');

    final target = await seedTargetWithDecoy();
    addTearDown(target.close);
    await BackupService.restoreBackup(target, oldZip);

    // Each plan got its own purchase back — no swaps, no duplicates.
    final phoneTxs = await target.planTransactions(phoneId);
    expect(phoneTxs.map((t) => t.note), contains('Phone'));
    expect(
      phoneTxs.where((t) => t.note == 'Installment payment: Phone'),
      hasLength(1),
    );
    final tabletTxs = await target.planTransactions(tabletId);
    expect(tabletTxs, hasLength(1));
    expect(tabletTxs.single.note, 'Tablet');
    final watchTxs = await target.planTransactions(watchId);
    expect(watchTxs, hasLength(1));
    expect(watchTxs.single.note, 'Tokopedia');
    // Nothing linked twice: 3 purchases + 1 payment.
    final linked = await target.select(target.transactions).get();
    expect(linked.where((t) => t.planId != null), hasLength(4));
    // Paid counts survived the round trip.
    final plans = await target.plansForWallet(paylaterId);
    expect(plans.firstWhere((p) => p.id == phoneId).paidCount, 1);
  });

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

  test('restore leaves the current app-lock PIN untouched', () async {
    // The backup was made while the device had the old PIN.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pinHash', 'old-pin-hash');
    final src = await seedSource();
    addTearDown(src.db.close);
    final zip = await BackupService.createBackup(src.db);

    // The PIN has since been changed on this device.
    await prefs.setString('pinHash', 'current-pin-hash');

    final target = await seedTargetWithDecoy();
    addTearDown(target.close);
    await BackupService.restoreBackup(target, zip);

    // The restored backup's old PIN must not overwrite the current
    // one — restoring it would lock the user out with a PIN they
    // may no longer remember.
    expect(prefs.getString('pinHash'), 'current-pin-hash');
  });

  test('restore never enables the app lock from a backup', () async {
    // The backup was made on a device with the app lock on.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lockEnabled', true);
    final src = await seedSource();
    addTearDown(src.db.close);
    final zip = await BackupService.createBackup(src.db);

    // This device is fresh: no PIN, lock off.
    await prefs.setBool('lockEnabled', false);
    await prefs.remove('pinHash');

    final target = await seedTargetWithDecoy();
    addTearDown(target.close);
    await BackupService.restoreBackup(target, zip);

    // The backup's lock switch must not carry over — restoring it
    // would boot the app into a lock screen no passcode can open.
    expect(prefs.getBool('lockEnabled'), isFalse);
    expect(prefs.containsKey('pinHash'), isFalse);
  });

  test('restore clears a stale selected account the backup does not have',
      () async {
    final prefs = await SharedPreferences.getInstance();
    // The backup is made with "All accounts": no selectedAccountId
    // key in its prefs.
    final src = await seedSource();
    addTearDown(src.db.close);
    final zip = await BackupService.createBackup(src.db);

    // This device has account 999 selected; the restored database
    // has no such account.
    await prefs.setInt('selectedAccountId', 999);

    final target = await seedTargetWithDecoy();
    addTearDown(target.close);
    await BackupService.restoreBackup(target, zip);

    // Keeping 999 would leave every account-scoped query empty
    // after a "successful" restore — the app would look empty.
    // (No bare isNull here: drift also exports isNull, so the
    // matcher is ambiguous in this file.)
    expect(prefs.containsKey('selectedAccountId'), isFalse);
    // The data itself still restored.
    final wallets = await target.select(target.wallets).get();
    expect(wallets.map((w) => w.name), contains('SPayLater'));
  });

  test('restore keeps a selected account that exists in the backup',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final src = await seedSource();
    addTearDown(src.db.close);
    final accountId = await src.db.addAccount(
      AccountsCompanion.insert(name: 'Personal', kind: 'personal'),
    );
    await prefs.setInt('selectedAccountId', accountId);
    final zip = await BackupService.createBackup(src.db);

    final target = await seedTargetWithDecoy();
    addTearDown(target.close);
    await BackupService.restoreBackup(target, zip);

    expect(prefs.getInt('selectedAccountId'), accountId);
  });

  test('restore drops budget-alert flags the backup does not mention',
      () async {
    final prefs = await SharedPreferences.getInstance();
    // One flag IS in the backup — it must survive the restore.
    await prefs.setBool('budgetNotified_3_2026-11_80', true);
    final src = await seedSource();
    addTearDown(src.db.close);
    final zip = await BackupService.createBackup(src.db);

    // Stale flags on this device, from the pre-restore data.
    await prefs.setBool('budgetNotified_7_2026-11_80', true);
    await prefs.setBool('budgetNotified_7_2026-11_100', true);
    await prefs.setString('dismissedUpdateVersion', '2.8.0');

    final target = await seedTargetWithDecoy();
    addTearDown(target.close);
    await BackupService.restoreBackup(target, zip);

    expect(prefs.getBool('budgetNotified_3_2026-11_80'), isTrue);
    expect(prefs.containsKey('budgetNotified_7_2026-11_80'), isFalse);
    expect(prefs.containsKey('budgetNotified_7_2026-11_100'), isFalse);
    expect(prefs.containsKey('dismissedUpdateVersion'), isFalse);
  });

  test('a malformed prefs value does not block the restore', () async {
    final src = await seedSource();
    addTearDown(src.db.close);
    final zip = await BackupService.createBackup(src.db);

    // Re-pack with a prefs.json carrying one bad value (a list with
    // a non-string, which used to throw inside _restorePrefs after
    // the database was already replaced) and good values around it.
    final decoded = ZipDecoder().decodeBytes(await zip.readAsBytes());
    final files = <String, List<int>>{};
    for (final f in decoded) {
      if (!f.isFile) continue;
      files[f.name] = f.name == 'prefs.json'
          ? utf8.encode(
              jsonEncode({
                'themeMode': 1,
                'displayName': 'Restored',
                'dismissedDetections': ['a', 42],
              }),
            )
          : (f.content as List<int>);
    }
    final badZip = packZip(files, 'bad-prefs.zip');

    final target = await seedTargetWithDecoy();
    addTearDown(target.close);
    // The old code threw here, after the database was replaced and
    // before the notification resync ran. The restore must now run
    // to completion — reaching the resync, which is the last step —
    // with the data and the good prefs restored.
    await BackupService.restoreBackup(target, badZip);

    final wallets = await target.select(target.wallets).get();
    expect(wallets.map((w) => w.name), contains('SPayLater'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('themeMode'), 1);
    expect(prefs.getString('displayName'), 'Restored');
    expect(prefs.containsKey('dismissedDetections'), isFalse);
  });

  test('a prefs file that is not a JSON object is refused, data intact',
      () async {
    final src = await seedSource();
    addTearDown(src.db.close);
    final zip = await BackupService.createBackup(src.db);

    // Valid JSON, but an array — not a prefs object.
    final decoded = ZipDecoder().decodeBytes(await zip.readAsBytes());
    final files = <String, List<int>>{};
    for (final f in decoded) {
      if (!f.isFile) continue;
      files[f.name] = f.name == 'prefs.json'
          ? utf8.encode(jsonEncode(['not', 'an', 'object']))
          : (f.content as List<int>);
    }
    final badZip = packZip(files, 'bad-prefs-shape.zip');

    final target = await seedTargetWithDecoy();
    addTearDown(target.close);
    await expectLater(
      BackupService.restoreBackup(target, badZip),
      throwsA(isA<BackupException>()),
    );
    final wallets = await target.select(target.wallets).get();
    expect(wallets.map((w) => w.name), contains('Decoy'));
  });
}
