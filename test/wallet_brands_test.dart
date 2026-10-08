library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dmoney_manager/data/database/app_database.dart';
import 'package:dmoney_manager/features/wallets/wallet_brands.dart';
import 'package:dmoney_manager/features/wallets/widgets/wallet_badge.dart';

void main() {
  group('wallet brand templates', () {
    test('ids are unique', () {
      final ids = allWalletBrands.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('groups cover every brand exactly once', () {
      final grouped = walletBrandGroups.values.expand((l) => l).toList();
      expect(grouped.length, allWalletBrands.length);
      expect(
        grouped.map((b) => b.id).toSet(),
        allWalletBrands.map((b) => b.id).toSet(),
      );
    });

    test('lookup by id', () {
      expect(walletBrandForId('bca')!.label, 'BCA');
      expect(walletBrandForId('gopay')!.category, 'ewallet');
      expect(walletBrandForId('jago')!.badgeHex, isNotNull);
      expect(walletBrandForId('nope'), isNull);
      expect(walletBrandForId(null), isNull);
      expect(walletBrandForId(''), isNull);
    });

    test('every brand has a label, a color, and a mark', () {
      for (final b in allWalletBrands) {
        expect(b.label, isNotEmpty, reason: b.id);
        expect(b.colorHex, matches(RegExp(r'^#[0-9A-Fa-f]{6}$')), reason: b.id);
        expect(
          b.hasWordmark || b.icon != null,
          isTrue,
          reason: '${b.id} needs a wordmark or an icon',
        );
      }
    });

    test('Indonesian bank and e-wallet coverage', () {
      final ids = allWalletBrands.map((b) => b.id).toSet();
      for (final id in [
        'bca', 'bri', 'mandiri', 'bni', 'cimb', 'danamon', 'btn', 'bsi',
        'jago', 'seabank', 'blu', 'neo', // banks
        'gopay', 'dana', 'ovo', 'shopeepay', 'linkaja', 'astrapay', // e-wallets
        'cash', 'bank', 'ewallet', 'card', // generic
      ]) {
        expect(ids, contains(id));
      }
    });

    test('wallet badge falls back to the generic kind mark', () {
      expect(
        walletBrandForWallet(logoTemplate: 'bca', kind: 'bank').id,
        'bca',
      );
      expect(
        walletBrandForWallet(logoTemplate: 'bogus', kind: 'bank').id,
        'bank',
      );
      expect(
        walletBrandForWallet(kind: 'bank').id,
        'bank',
      );
      expect(walletBrandForWallet(kind: 'ewallet').id, 'ewallet');
      expect(walletBrandForWallet(kind: 'credit').id, 'card');
      expect(walletBrandForWallet(kind: 'cash').id, 'cash');
      expect(walletBrandForWallet(kind: 'mystery').id, 'cash');
    });
  });

  testWidgets('WalletBadge renders the wordmark', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WalletBadge(brand: _TestBrands.gopay),
        ),
      ),
    );
    expect(find.text('GoPay', findRichText: true), findsOneWidget);
  });

  testWidgets('WalletBadge renders the icon mark for generic templates',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WalletBadge(brand: _TestBrands.cash),
        ),
      ),
    );
    expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
  });

  group('wallets.logoTemplate persistence (v12)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('createWallet stores the logo template', () async {
      final accountId = await db.addAccount(
        AccountsCompanion.insert(name: 'Personal', kind: 'personal'),
      );
      final id = await db.createWallet(
        accountId: accountId,
        name: 'BCA',
        kind: 'bank',
        logoTemplate: 'bca',
        colorHex: '#2F6DF6',
      );
      final w = await (db.select(db.wallets)
            ..where((e) => e.id.equals(id)))
          .getSingle();
      expect(w.logoTemplate, 'bca');
      expect(w.colorHex, '#2F6DF6');
    });

    test('updateWallet changes and clears the logo template', () async {
      final accountId = await db.addAccount(
        AccountsCompanion.insert(name: 'Personal', kind: 'personal'),
      );
      final id = await db.createWallet(
        accountId: accountId,
        name: 'Cash',
        kind: 'cash',
      );
      Future<Wallet> load() => (db.select(db.wallets)
            ..where((e) => e.id.equals(id)))
          .getSingle();

      expect((await load()).logoTemplate, isNull);

      await db.updateWallet(
        id: id,
        name: 'Cash',
        kind: 'cash',
        logoTemplate: 'gopay',
      );
      expect((await load()).logoTemplate, 'gopay');

      await db.updateWallet(
        id: id,
        name: 'Cash',
        kind: 'cash',
        logoTemplate: null,
      );
      expect((await load()).logoTemplate, isNull);
    });
  });
}

/// Brand literals mirroring the library, for widget tests without
/// depending on the full template list.
class _TestBrands {
  static const gopay = WalletBrand(
    id: 'gopay',
    label: 'GoPay',
    category: 'ewallet',
    colorHex: '#00B4DD',
    wordmark: 'GoPay',
  );
  static const cash = WalletBrand(
    id: 'cash',
    label: 'Cash',
    category: 'general',
    colorHex: '#22C55E',
    icon: Icons.payments_outlined,
  );
}
