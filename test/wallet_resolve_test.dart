import 'package:flutter_test/flutter_test.dart';

import 'package:dmoney_manager/core/utils/wallet_resolve.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// resolveWalletId: a preselected (or edited) wallet survives the loading
/// frame instead of being wiped before the wallet list arrives.
void main() {
  Wallet wallet(int id) => Wallet(
        id: id,
        accountId: 1,
        name: 'W$id',
        kind: 'cash',
        balance: 0,
        initialAmount: 0,
        colorHex: '#A78BFA',
        logoTemplate: null,
        sortOrder: 0,
      );

  test('keeps the preselected id while the list is still loading', () {
    expect(resolveWalletId(const [], 7), 7);
  });

  test('keeps the id when it is in the loaded list', () {
    final wallets = [wallet(1), wallet(2)];
    expect(resolveWalletId(wallets, 2), 2);
  });

  test('falls back to the first wallet when missing or null', () {
    final wallets = [wallet(1), wallet(2)];
    expect(resolveWalletId(wallets, 999), 1);
    expect(resolveWalletId(wallets, null), 1);
  });

  test('empty list and null id stays null', () {
    expect(resolveWalletId(const [], null), isNull);
  });

  group('fallbackToFirst: false (optional-wallet sheets)', () {
    test('keeps the existing id while loading', () {
      expect(resolveWalletId(const [], 7, fallbackToFirst: false), 7);
    });

    test('keeps the id when it is in the loaded list', () {
      final wallets = [wallet(1), wallet(2)];
      expect(resolveWalletId(wallets, 2, fallbackToFirst: false), 2);
    });

    test('missing or null id stays null once loaded', () {
      final wallets = [wallet(1), wallet(2)];
      expect(resolveWalletId(wallets, 999, fallbackToFirst: false), isNull);
      expect(resolveWalletId(wallets, null, fallbackToFirst: false), isNull);
    });
  });
}
