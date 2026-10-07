import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dmoney_manager/data/database/app_database.dart';

/// Generates a sample Dmoney Manager backup: 10,000 transactions spread
/// over 5 years, packed as an importable `.zip` backup file.
///
/// Run: flutter test test/sample_backup_gen_test.dart
///
/// The database is created through the app's own drift schema, so the
/// backup restores cleanly via Settings > Backup > Restore.
void main() {
  test('generate sample backup', () async {
    final rand = Random(42); // fixed seed: reproducible sample
    final outZip =
        '${Platform.environment['HOME']}/workspace/your_files/dmoney-sample-backup-10k.zip';
    final workDir = await Directory.systemTemp.createTemp('sample_backup');
    final dbPath = '${workDir.path}/database.sqlite';
    final dbFile = File(dbPath);
    if (await dbFile.exists()) await dbFile.delete();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));

    // Start clean: drop the seeded default categories, use ours only.
    await db.delete(db.categories).go();

    // ------------------------------------------------------------------
    // Seed: account, wallets, categories.
    // ------------------------------------------------------------------
    final accountId = await db
        .into(db.accounts)
        .insert(AccountsCompanion.insert(name: 'Personal', kind: 'personal'));

    final walletDefs = [
      ('Cash', 'cash', '#4ECDC4', 1000000),
      ('BCA', 'account_balance', '#5B8DEF', 10000000),
      ('GoPay', 'wallet', '#00AED6', 2000000),
    ];
    final walletIds = <int>[];
    final balances = <int, int>{};
    for (final (name, kind, color, initial) in walletDefs) {
      final id = await db
          .into(db.wallets)
          .insert(
            WalletsCompanion.insert(
              accountId: accountId,
              name: name,
              kind: kind,
              balance: Value(initial),
              initialAmount: Value(initial),
              colorHex: Value(color),
            ),
          );
      walletIds.add(id);
      balances[id] = initial;
    }
    final bcaId = walletIds[1];

    final catDefs = <_CatDef>[
      _CatDef(
        'Food & Drink',
        'food',
        '#FF6B6B',
        'expense',
        15000,
        120000,
        0.34,
        _foodNotes,
      ),
      _CatDef(
        'Transport',
        'transport',
        '#4ECDC4',
        'expense',
        12000,
        80000,
        0.20,
        _transportNotes,
      ),
      _CatDef(
        'Groceries',
        'cart',
        '#95E1D3',
        'expense',
        80000,
        450000,
        0.12,
        _groceryNotes,
      ),
      _CatDef(
        'Shopping',
        'shopping',
        '#A78BFA',
        'expense',
        50000,
        1500000,
        0.12,
        _shoppingNotes,
      ),
      _CatDef(
        'Bills',
        'bills',
        '#F38181',
        'expense',
        75000,
        800000,
        0.08,
        _billNotes,
      ),
      _CatDef(
        'Entertainment',
        'entertainment',
        '#FCBAD3',
        'expense',
        35000,
        250000,
        0.06,
        _entertainmentNotes,
      ),
      _CatDef(
        'Health',
        'health',
        '#AA96DA',
        'expense',
        25000,
        400000,
        0.05,
        _healthNotes,
      ),
      _CatDef(
        'Education',
        'education',
        '#A8E6CF',
        'expense',
        100000,
        1000000,
        0.03,
        _educationNotes,
      ),
      _CatDef(
        'Salary',
        'salary',
        '#C6FF4A',
        'income',
        25000000,
        35000000,
        0,
        const ['Gaji bulanan'],
      ),
      _CatDef('Bonus', 'gift', '#C6FF4A', 'income', 2000000, 8000000, 0, const [
        'Bonus proyek',
        'THR',
        'Bonus tahunan',
      ]),
      _CatDef(
        'Side Income',
        'trending_up',
        '#C6FF4A',
        'income',
        500000,
        3000000,
        0,
        const ['Freelance', 'Jual barang bekas'],
      ),
      _CatDef('Transfer', 'swap_horiz', '#A78BFA', 'transfer', 0, 0, 0, const [
        'Transfer antar dompet',
      ]),
    ];
    final catIds = <String, int>{};
    final catByKind = <String, List<_CatDef>>{};
    var sortOrder = 0;
    for (final def in catDefs) {
      final id = await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: def.name,
              kind: def.kind,
              iconKey: Value(def.iconKey),
              colorHex: Value(def.colorHex),
              sortOrder: Value(sortOrder++),
            ),
          );
      catIds[def.name] = id;
      catByKind.putIfAbsent(def.kind, () => []).add(def);
    }
    final transferCatId = catIds['Transfer']!;

    // ------------------------------------------------------------------
    // 10,000 transactions over 5 years (2021-10-08 .. 2026-10-07).
    // ------------------------------------------------------------------
    final start = DateTime(2021, 10, 8);
    const totalDays = 1826;
    final entries = <TransactionsCompanion>[];

    int amount(_CatDef def) =>
        def.minAmount + rand.nextInt(def.maxAmount - def.minAmount + 1);
    String note(_CatDef def) => def.notes[rand.nextInt(def.notes.length)];
    int pickWallet(List<double> weights) {
      final r = rand.nextDouble();
      var acc = 0.0;
      for (var i = 0; i < weights.length; i++) {
        acc += weights[i];
        if (r < acc) return walletIds[i];
      }
      return walletIds.last;
    }

    void addTx({
      required int walletId,
      required _CatDef cat,
      required DateTime date,
      int? toWalletId,
    }) {
      final amt = amount(cat);
      entries.add(
        TransactionsCompanion.insert(
          walletId: walletId,
          categoryId: catIds[cat.name]!,
          kind: cat.kind,
          amount: amt,
          date: date,
          note: Value(note(cat)),
          createdAt: Value(date),
          toWalletId: Value(toWalletId),
        ),
      );
      if (cat.kind == 'income') {
        balances[walletId] = balances[walletId]! + amt;
      } else if (cat.kind == 'expense') {
        balances[walletId] = balances[walletId]! - amt;
      } else {
        balances[walletId] = balances[walletId]! - amt;
        balances[toWalletId!] = balances[toWalletId]! + amt;
      }
    }

    final expenseCats = catByKind['expense']!;
    _CatDef pickExpense() {
      final r = rand.nextDouble();
      var acc = 0.0;
      for (final c in expenseCats) {
        acc += c.weight;
        if (r < acc) return c;
      }
      return expenseCats.last;
    }

    // Monthly salary: 1st of each month, 60 months (Nov 2021 .. Oct 2026).
    final salaryCat = catByKind['income']!.firstWhere(
      (c) => c.name == 'Salary',
    );
    for (var m = 0; m < 60; m++) {
      final probe = DateTime(2021, 11 + m);
      addTx(
        walletId: bcaId,
        cat: salaryCat,
        date: DateTime(probe.year, probe.month, 1, 9, 0),
      );
    }

    // Monthly bills: electricity (15th) + internet (5th), never in the future.
    final billsCat = expenseCats.firstWhere((c) => c.name == 'Bills');
    final today = DateTime(2026, 10, 7);
    for (var m = 0; m < 60; m++) {
      final probe = DateTime(2021, 11 + m);
      final internetDate = DateTime(
        probe.year,
        probe.month,
        5,
        10,
        rand.nextInt(60),
      );
      if (!internetDate.isAfter(today)) {
        addTx(walletId: bcaId, cat: billsCat, date: internetDate);
      }
      final elecDate = DateTime(
        probe.year,
        probe.month,
        15,
        19,
        rand.nextInt(60),
      );
      if (!elecDate.isAfter(today)) {
        addTx(
          walletId: pickWallet([0.2, 0.6, 0.2]),
          cat: billsCat,
          date: elecDate,
        );
      }
    }

    // Monthly top-ups from salary account to spending wallets.
    for (var m = 0; m < 60; m++) {
      final probe = DateTime(2021, 11 + m);
      for (final (to, amt) in [
        (walletIds[0], 15000000),
        (walletIds[2], 13000000),
      ]) {
        final date = DateTime(probe.year, probe.month, 2, 10, rand.nextInt(60));
        entries.add(
          TransactionsCompanion.insert(
            walletId: bcaId,
            categoryId: transferCatId,
            kind: 'transfer',
            amount: amt,
            date: date,
            note: const Value('Top up bulanan'),
            createdAt: Value(date),
            toWalletId: Value(to),
          ),
        );
        balances[bcaId] = balances[bcaId]! - amt;
        balances[to] = balances[to]! + amt;
      }
    }

    // 80 random wallet-to-wallet transfers.
    for (var i = 0; i < 80; i++) {
      final from = walletIds[rand.nextInt(walletIds.length)];
      var to = walletIds[rand.nextInt(walletIds.length)];
      while (to == from) {
        to = walletIds[rand.nextInt(walletIds.length)];
      }
      final day = rand.nextInt(totalDays);
      final date = start.add(
        Duration(
          days: day,
          hours: 8 + rand.nextInt(12),
          minutes: rand.nextInt(60),
        ),
      );
      final amt = 100000 + rand.nextInt(2900001);
      entries.add(
        TransactionsCompanion.insert(
          walletId: from,
          categoryId: transferCatId,
          kind: 'transfer',
          amount: amt,
          date: date,
          note: const Value('Transfer antar dompet'),
          createdAt: Value(date),
          toWalletId: Value(to),
        ),
      );
      balances[from] = balances[from]! - amt;
      balances[to] = balances[to]! + amt;
    }

    // Daily transactions: 10,000 - 60 salary - 119 bills - 120 top-ups -
    // 80 transfers = 9,621 (98% expense, 2% income).
    const dailyCount = 9621;
    final bonusCat = catByKind['income']!.firstWhere((c) => c.name == 'Bonus');
    final sideCat = catByKind['income']!.firstWhere(
      (c) => c.name == 'Side Income',
    );
    for (var i = 0; i < dailyCount; i++) {
      final day = rand.nextInt(totalDays);
      final date = start.add(
        Duration(days: day, hours: _pickHour(rand), minutes: rand.nextInt(60)),
      );
      if (rand.nextDouble() < 0.02) {
        addTx(
          walletId: bcaId,
          cat: rand.nextBool() ? bonusCat : sideCat,
          date: date,
        );
      } else {
        addTx(
          walletId: pickWallet([0.4, 0.25, 0.35]),
          cat: pickExpense(),
          date: date,
        );
      }
    }

    expect(entries.length, 10000);
    entries.sort((a, b) => a.date.value.compareTo(b.date.value));

    // Bulk insert in batches.
    const batchSize = 1000;
    for (var i = 0; i < entries.length; i += batchSize) {
      final chunk = entries.sublist(
        i,
        (i + batchSize).clamp(0, entries.length),
      );
      await db.batch((b) => b.insertAll(db.transactions, chunk));
    }

    // Final wallet balances.
    for (final id in walletIds) {
      await (db.update(db.wallets)..where((w) => w.id.equals(id))).write(
        WalletsCompanion(balance: Value(balances[id]!)),
      );
    }

    await db.close();

    // ------------------------------------------------------------------
    // Pack the backup zip.
    // ------------------------------------------------------------------
    final manifest = jsonEncode({
      'app': 'dmoney_manager',
      'format': 1,
      'schemaVersion': 11,
      'createdAt': DateTime.now().toIso8601String(),
      'sample': true,
      'transactions': entries.length,
    });
    final manifestBytes = utf8.encode(manifest);
    final prefsBytes = utf8.encode(jsonEncode({'currencyCode': 'IDR'}));

    final archive = Archive();
    final dbBytes = await dbFile.readAsBytes();
    archive.addFile(ArchiveFile('database.sqlite', dbBytes.length, dbBytes));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );
    archive.addFile(ArchiveFile('prefs.json', prefsBytes.length, prefsBytes));

    final zipBytes = ZipEncoder().encode(archive)!;
    final outFile = File(outZip);
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(zipBytes);
    await workDir.delete(recursive: true);

    final kb = (await outFile.length()) ~/ 1024;
    // ignore: avoid_print
    print('Wrote $outZip (${kb}KB, ${entries.length} transactions)');
  });
}

int _pickHour(Random rand) {
  // Meal-time weighted hours.
  const hours = [7, 8, 12, 13, 18, 19, 20, 9, 10, 11, 14, 15, 16, 17, 21, 22];
  const weights = [3, 3, 5, 5, 5, 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 1];
  final total = weights.reduce((a, b) => a + b);
  var r = rand.nextInt(total);
  for (var i = 0; i < hours.length; i++) {
    r -= weights[i];
    if (r < 0) return hours[i];
  }
  return 12;
}

class _CatDef {
  _CatDef(
    this.name,
    this.iconKey,
    this.colorHex,
    this.kind,
    this.minAmount,
    this.maxAmount,
    this.weight,
    this.notes,
  );
  final String name;
  final String iconKey;
  final String colorHex;
  final String kind;
  final int minAmount;
  final int maxAmount;
  final double weight;
  final List<String> notes;
}

const _foodNotes = [
  'Nasi padang',
  'Soto ayam',
  'Kopi kenangan',
  'Mie ayam',
  'Warteg',
  'Ayam geprek',
  'Bakso',
  'Nasi goreng',
  'Sate ayam',
  'Gado-gado',
  'Pecel lele',
  'Rawon',
  'Coto makassar',
  'Bubur ayam',
  'Martabak',
];
const _transportNotes = [
  'Gojek ke kantor',
  'Grab ke mall',
  'Bensin',
  'Parkir',
  'Tol',
  'Ojek pulang',
  'TransJakarta',
  'KRL',
];
const _groceryNotes = [
  'Belanja mingguan',
  'Indomaret',
  'Pasar pagi',
  'Superindo',
  'Belanja bulanan',
];
const _shoppingNotes = [
  'Baju',
  'Sepatu',
  'Shopee',
  'Tokopedia',
  'Buku',
  'Elektronik',
  'Tas',
  'Jam tangan',
];
const _billNotes = ['Listrik', 'Internet', 'Air', 'Pulsa', 'BPJS'];
const _entertainmentNotes = [
  'Bioskop',
  'Netflix',
  'Karaoke',
  'Top up game',
  'Konser',
];
const _healthNotes = ['Apotek', 'Dokter gigi', 'Vitamin', 'Puskesmas'];
const _educationNotes = ['Kursus online', 'Buku pelajaran', 'Workshop'];
