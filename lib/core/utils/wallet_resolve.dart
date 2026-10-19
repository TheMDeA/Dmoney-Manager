import '../../data/database/app_database.dart';

/// Resolves which wallet id a form should use given the loaded [wallets]
/// and the current [currentId] (preselected, or carried from an edit).
///
/// While the wallet list is still loading (empty), the current id is kept
/// as-is so a preselected/existing wallet isn't wiped on the first frame.
/// Once loaded, a missing id either falls back to the first wallet
/// ([fallbackToFirst], for sheets where a wallet is required) or stays
/// null (for sheets where the wallet is optional, e.g. debts).
int? resolveWalletId(
  List<Wallet> wallets,
  int? currentId, {
  bool fallbackToFirst = true,
}) {
  if (wallets.isEmpty) return currentId;
  if (currentId == null || wallets.every((w) => w.id != currentId)) {
    return fallbackToFirst ? wallets.first.id : null;
  }
  return currentId;
}
