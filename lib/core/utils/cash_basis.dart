import '../../data/database/app_database.dart';

/// Cash-basis income/expense rules for paylater wallets.
///
/// A paylater purchase is borrowing, not spending: the money leaves the
/// user's hands only when an installment is paid. So the totals count a
/// row only when cash actually moves:
///
/// - an income/expense row on a paylater wallet never counts;
/// - a transfer into a paylater wallet from a real funding wallet counts
///   as an expense, dated when it is paid;
/// - moving debt between two paylater wallets counts as neither;
/// - a transfer out of a paylater wallet counts as neither (borrowed
///   money is not income).
///
/// The SQL aggregates in [AppDatabase] (`watchCashKindTotals` and
/// friends) implement exactly these rules; the helpers here are the
/// same rules in pure form for the Dart-fold sites and for tests.

/// Contribution of one transaction row to the income total: [amount]
/// when it counts, 0 when it does not. [sourceWalletKind] is the kind
/// of the row's wallet; [destWalletKind] is the kind of the transfer
/// destination, null for income/expense rows.
int cashIncomeOf({
  required String kind,
  required String sourceWalletKind,
  String? destWalletKind,
  required int amount,
}) {
  // Income landing on a paylater wallet is not money in — it only
  // shrinks what is owed, and the add sheet never lets it happen.
  if (kind == 'income' && sourceWalletKind != 'paylater') return amount;
  return 0;
}

/// Contribution of one transaction row to the expense total: [amount]
/// when it counts, 0 when it does not. Same parameters as
/// [cashIncomeOf].
int cashExpenseOf({
  required String kind,
  required String sourceWalletKind,
  String? destWalletKind,
  required int amount,
}) {
  // An expense on a paylater wallet is unpaid borrowing, not spending.
  if (kind == 'expense' && sourceWalletKind != 'paylater') return amount;
  // A transfer into a paylater wallet from a real funding wallet is a
  // payment of the debt: spending, dated when paid. Moving debt between
  // two paylater wallets is not spending.
  if (kind == 'transfer' &&
      sourceWalletKind != 'paylater' &&
      destWalletKind == 'paylater') {
    return amount;
  }
  return 0;
}

/// The category an installment payment counts under in spending
/// breakdowns: the linked purchase's category when the transfer belongs
/// to a plan ([purchaseCategoryByPlanId] maps plan id → purchase
/// category id, see [AppDatabase.planPurchaseCategories]), otherwise
/// [fallbackCategoryId] — the row's own category, which is the hidden
/// Transfer category for an unlinked paydown.
int spendingCategoryOf({
  required Transaction t,
  required int fallbackCategoryId,
  required Map<int, int> purchaseCategoryByPlanId,
}) {
  final planId = t.planId;
  if (t.kind == 'transfer' && planId != null) {
    return purchaseCategoryByPlanId[planId] ?? fallbackCategoryId;
  }
  return fallbackCategoryId;
}
