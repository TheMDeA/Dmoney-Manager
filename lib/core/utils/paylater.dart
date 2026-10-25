import '../../data/database/app_database.dart';

/// Pure paylater math and wallet helpers.
///
/// Balance model: a paylater wallet uses the same balance mechanics as
/// every other wallet — expenses push the balance down, payments
/// (transfers in) push it back toward zero. So a paylater wallet's
/// balance is negative exactly when money is owed, and the outstanding
/// amount is `-balance` (0 when the balance is zero or positive).
/// Liabilities are never mixed into asset totals: [combinedBalance]
/// excludes paylater wallets entirely.

/// Outstanding amount owed on a paylater wallet (whole IDR).
int outstandingFromBalance(int balance) => balance < 0 ? -balance : 0;

/// Outstanding amount owed on [w] (0 for non-paylater wallets too, since
/// their balances are assets — callers filter by kind first).
int paylaterOutstanding(Wallet w) => outstandingFromBalance(w.balance);

bool isPaylaterWallet(Wallet w) => w.kind == 'paylater';

List<Wallet> paylaterWallets(List<Wallet> wallets) =>
    wallets.where(isPaylaterWallet).toList();

/// Combined balance for the Wallets screen: every wallet's balance
/// except paylater wallets, whose owed amounts are liabilities, not assets.
int combinedBalance(List<Wallet> wallets) =>
    wallets.where((w) => w.kind != 'paylater').fold(0, (s, w) => s + w.balance);

/// Total outstanding across [wallets] (paylater wallets only).
int totalPaylaterOutstanding(List<Wallet> wallets) =>
    paylaterWallets(wallets).fold(0, (s, w) => s + paylaterOutstanding(w));

/// Combined credit limit across paylater wallets that have one set.
int totalPaylaterLimit(List<Wallet> wallets) => paylaterWallets(wallets)
    .where((w) => w.creditLimit != null)
    .fold(0, (s, w) => s + w.creditLimit!);

/// Fraction of the limit used, or null when no limit is set anywhere.
double? paylaterLimitUsedRatio(List<Wallet> wallets) {
  final limit = totalPaylaterLimit(wallets);
  if (limit <= 0) return null;
  return totalPaylaterOutstanding(wallets) / limit;
}

/// Next occurrence of a monthly [dueDay] (1-31) on or after [from]'s date.
/// Days past the end of a short month clamp to that month's last day
/// (e.g. due day 31 in February lands on Feb 28).
DateTime nextDueDate({required int dueDay, required DateTime from}) {
  DateTime candidate(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, dueDay.clamp(1, lastDay));
  }

  final today = DateTime(from.year, from.month, from.day);
  final thisMonth = candidate(from.year, from.month);
  if (!thisMonth.isBefore(today)) return thisMonth;
  return candidate(from.year, from.month + 1);
}

/// The paylater wallet whose bill comes due soonest, with its due date.
/// Only wallets with an outstanding amount and a due day set are eligible;
/// null when nothing is due.
({Wallet wallet, DateTime dueDate})? nextPaylaterDue(
  List<Wallet> wallets,
  DateTime now,
) {
  ({Wallet wallet, DateTime dueDate})? best;
  for (final w in paylaterWallets(wallets)) {
    if (paylaterOutstanding(w) <= 0 || w.dueDay == null) continue;
    final due = nextDueDate(dueDay: w.dueDay!, from: now);
    if (best == null || due.isBefore(best.dueDate)) {
      best = (wallet: w, dueDate: due);
    }
  }
  return best;
}

/// Amount due this cycle: outstanding on wallets whose next due date
/// falls in [now]'s calendar month.
int dueThisCycle(List<Wallet> wallets, DateTime now) {
  var sum = 0;
  for (final w in paylaterWallets(wallets)) {
    if (paylaterOutstanding(w) <= 0 || w.dueDay == null) continue;
    final due = nextDueDate(dueDay: w.dueDay!, from: now);
    if (due.year == now.year && due.month == now.month) {
      sum += paylaterOutstanding(w);
    }
  }
  return sum;
}

/// Quote for splitting a paylater purchase across [tenor] monthly payments.
///
/// Flat-monthly-fee model (how BNPL admin fees normally work): the monthly
/// fee is computed on the full principal every month, so
/// total interest = principal x monthly rate x tenor, rounded to whole IDR.
class TenorQuote {
  const TenorQuote({
    required this.monthlyAmount,
    required this.totalInterest,
    required this.totalPayable,
  });

  /// Amount due each month (principal share + monthly fee, if rated).
  final int monthlyAmount;

  /// Total interest across all months, or null when no rate is set —
  /// callers must never invent a rate.
  final int? totalInterest;

  /// Principal + total interest (principal alone when unrated).
  final int totalPayable;
}

TenorQuote calcTenor({
  required int principal,
  required int tenor,
  double? monthlyRatePercent,
}) {
  assert(tenor > 0, 'tenor must be positive');
  final base = (principal / tenor).round();
  if (monthlyRatePercent == null) {
    return TenorQuote(
      monthlyAmount: base,
      totalInterest: null,
      totalPayable: principal,
    );
  }
  final monthlyFee = (principal * monthlyRatePercent / 100).round();
  return TenorQuote(
    monthlyAmount: base + monthlyFee,
    totalInterest: monthlyFee * tenor,
    totalPayable: principal + monthlyFee * tenor,
  );
}

/// Remaining balance on an installment plan (never below zero).
int planRemaining(InstallmentPlan p) {
  final remaining = p.totalAmount - p.paidCount * p.installmentAmount;
  return remaining < 0 ? 0 : remaining;
}

/// Progress fraction 0..1 for an installment plan.
double planProgress(InstallmentPlan p) {
  if (p.totalCount <= 0) return 0;
  return (p.paidCount / p.totalCount).clamp(0.0, 1.0);
}

/// Whether recording a new expense on a wallet must be blocked by the
/// paylater freeze: frozen + a paylater wallet + a genuinely new expense.
/// Editing an existing record is never blocked.
bool isPaylaterSpendBlocked({
  required bool frozen,
  required String walletKind,
  required bool isNewExpense,
}) =>
    frozen && isNewExpense && walletKind == 'paylater';
