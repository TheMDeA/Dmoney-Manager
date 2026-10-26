import '../../core/utils/formatters.dart';
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

/// Repayments into paylater wallets in a transaction list: transfers
/// whose destination is a paylater wallet. Purchases (expenses on the
/// paylater wallet) are deliberately excluded — repayments are money
/// out of the user's other wallets, shown separately from spending.
int paylaterRepayments(
  Iterable<Transaction> transactions,
  Set<int> paylaterIds,
) =>
    transactions
        .where(
          (t) =>
              t.kind == 'transfer' &&
              t.toWalletId != null &&
              paylaterIds.contains(t.toWalletId),
        )
        .fold(0, (s, t) => s + t.amount);

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

/// Parameters for the installment plan auto-created when a new paylater
/// expense is saved from the add sheet, or null when no plan applies.
/// The tenor is never skipped: the default 1x creates a 1-of-1 plan —
/// the "pay in full next month" case — exactly like longer tenors.
/// Never for edits, transfers, income, or non-paylater wallets: those
/// flows have no tenor context and must never spawn plans.
({String name, int totalAmount, int installmentAmount, int totalCount})?
    autoPlanParams({
  required bool isNew,
  required String transactionKind,
  required String walletKind,
  required int amount,
  required int tenor,
  required double? monthlyRatePercent,
  required String note,
  String? categoryName,
}) {
  if (!isNew ||
      transactionKind != 'expense' ||
      walletKind != 'paylater' ||
      amount <= 0 ||
      tenor <= 0) {
    return null;
  }
  final quote = calcTenor(
    principal: amount,
    tenor: tenor,
    monthlyRatePercent: monthlyRatePercent,
  );
  final trimmedNote = note.trim();
  final trimmedCategory = categoryName?.trim() ?? '';
  final name = trimmedNote.isNotEmpty
      ? trimmedNote
      : trimmedCategory.isNotEmpty
          ? trimmedCategory
          : 'Paylater installment';
  return (
    name: name,
    totalAmount: amount,
    installmentAmount: quote.monthlyAmount,
    totalCount: tenor,
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

/// Whether recording income on a wallet must be blocked: a paylater
/// wallet can never receive income. Income would push its balance
/// positive, which the dashboard reads as "nothing owed", while the
/// wallet card shows money sitting in the account — a contradiction.
/// Paylater bills are paid down via transfers, never topped up.
/// Merchant refunds are the only edge case; they belong in a transfer,
/// not an income row.
bool isIncomeToPaylaterBlocked({
  required String walletKind,
  required String kind,
}) =>
    walletKind == 'paylater' && kind == 'income';

/// Overpay produced by transferring [amount] into a paylater wallet
/// whose current balance is [balance]: the positive part of the
/// resulting balance, or 0 when the wallet still owes (or breaks even).
/// A transfer-in pushes the balance up, so the overpay is simply
/// whatever lands above zero.
int paylaterTransferOverpay(int balance, int amount) {
  final after = balance + amount;
  return after > 0 ? after : 0;
}

/// Amount of one installment payment for [p]: the monthly installment,
/// capped by what the plan still has left. The plan is the authority
/// for its own remaining — never capped by the wallet balance, so a
/// plan whose purchase was never recorded as an expense can still be
/// paid off.
int installmentDueAmount(InstallmentPlan p) {
  final remaining = planRemaining(p);
  return p.installmentAmount < remaining ? p.installmentAmount : remaining;
}

/// Display label for a paylater wallet's balance: the owed amount as a
/// positive figure when money is owed, "Overpaid Rp X" when the balance
/// went positive, "Rp 0" when settled. Never the raw signed balance
/// presented as if it were money owned.
String paylaterBalanceLabel(Wallet w) {
  if (w.balance < 0) return formatMoney(-w.balance);
  if (w.balance > 0) return 'Overpaid ${formatMoney(w.balance)}';
  return formatMoney(0);
}

/// Wallets shown in the Wallets screen stack: paylater wallets live in
/// the paylater dashboard only, never in the stack.
List<Wallet> stackWallets(List<Wallet> wallets) =>
    wallets.where((w) => w.kind != 'paylater').toList();
