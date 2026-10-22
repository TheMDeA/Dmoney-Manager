import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dmoney_manager/data/database/app_database.dart';

/// Transfer fee lifecycle: the fee is an expense row on the source
/// wallet linked to its transfer; deleting (or undoing) the transfer
/// keeps every balance exact.
void main() {
  late AppDatabase db;
  late int fromId;
  late int toId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final account = await db.addAccount(AccountsCompanion.insert(
        name: 'Personal', kind: 'personal', colorHex: const Value('#FF0000')));
    fromId = await db.createWallet(
        accountId: account, name: 'Bank', kind: 'bank', initialAmount: 100000);
    toId = await db.createWallet(
        accountId: account, name: 'Cash', kind: 'cash', initialAmount: 0);
  });

  tearDown(() => db.close());

  Future<int> balance(int walletId) async =>
      (await db.getWalletById(walletId))!.balance;

  test('transfer with fee charges amount + fee to the source wallet',
      () async {
    final transferId = await db.addTransfer(
        fromWalletId: fromId, toWalletId: toId, amount: 50000, fee: 6500);

    expect(await balance(fromId), 100000 - 50000 - 6500);
    expect(await balance(toId), 50000);

    final fees = await db.transferFeeRows(transferId);
    expect(fees, hasLength(1));
    expect(fees.single.kind, 'expense');
    expect(fees.single.amount, 6500);
    expect(fees.single.walletId, fromId);
    final cat = await (db.select(db.categories)
          ..where((c) => c.id.equals(fees.single.categoryId)))
        .getSingle();
    expect(cat.name, 'Transfer fee');
    expect(cat.kind, 'expense');
  });

  test('transfer without fee creates no fee row', () async {
    final transferId = await db.addTransfer(
        fromWalletId: fromId, toWalletId: toId, amount: 20000);

    expect(await balance(fromId), 80000);
    expect(await balance(toId), 20000);
    expect(await db.transferFeeRows(transferId), isEmpty);
  });

  test('deleting the transfer reverses the fee too', () async {
    final transferId = await db.addTransfer(
        fromWalletId: fromId, toWalletId: toId, amount: 50000, fee: 6500);

    await db.deleteTransaction(transferId);

    expect(await balance(fromId), 100000);
    expect(await balance(toId), 0);
    expect(await db.transferFeeRows(transferId), isEmpty);
  });

  test('undo (restore transfer + fee rows) restores the balances',
      () async {
    final transferId = await db.addTransfer(
        fromWalletId: fromId, toWalletId: toId, amount: 50000, fee: 6500);
    final transfer = await (db.select(db.transactions)
          ..where((t) => t.id.equals(transferId)))
        .getSingle();
    final fees = await db.transferFeeRows(transferId);

    await db.deleteTransaction(transferId);
    expect(await balance(fromId), 100000);

    await db.restoreTransaction(transfer, const []);
    for (final f in fees) {
      await db.restoreTransaction(f, const []);
    }

    expect(await balance(fromId), 100000 - 50000 - 6500);
    expect(await balance(toId), 50000);
    expect(await db.transferFeeRows(transferId), hasLength(1));
  });
}
