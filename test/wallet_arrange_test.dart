import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dmoney_manager/data/database/app_database.dart';

/// Arrange Wallets: manual ordering via sortOrder.
///
/// Covers:
/// 1. watchWallets returns wallets in sortOrder (not insertion order).
/// 2. reorderWallets persists a new order.
/// 3. New wallets land at the end (default sortOrder 0 would collide, so
///    createWallet must assign max+1 — verified here).
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<int> addWallet(String name) => db.createWallet(
        accountId: 1,
        name: name,
        kind: 'cash',
      );

  test('wallets come back in sortOrder', () async {
    final a = await addWallet('A');
    final b = await addWallet('B');
    final c = await addWallet('C');

    // Reverse the order.
    await db.reorderWallets([c, b, a]);

    final wallets = await db.watchWallets().first;
    expect([for (final w in wallets) w.id], [c, b, a]);
  });

  test('reorderWallets persists across reads', () async {
    final a = await addWallet('A');
    final b = await addWallet('B');

    await db.reorderWallets([b, a]);
    final first = await db.watchWallets().first;
    expect(first.first.id, b);

    // A second reorder sticks too.
    await db.reorderWallets([a, b]);
    final second = await db.watchWallets().first;
    expect(second.first.id, a);
  });

  test('new wallets append at the end after a reorder', () async {
    final a = await addWallet('A');
    final b = await addWallet('B');
    await db.reorderWallets([b, a]);

    final c = await addWallet('C');
    final wallets = await db.watchWallets().first;
    expect([for (final w in wallets) w.id], [b, a, c]);
  });
}
