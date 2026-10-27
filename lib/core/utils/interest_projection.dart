import 'dart:math' as math;

import '../../data/database/app_database.dart';

/// Pure growth-projection math for savings wallets.
///
/// This is the opposite direction from paylater: paylater's
/// `interestRateMonthly` is a *cost* rate on money owed, while the
/// `interestRateAnnual` here is a *growth* rate on money saved. The two
/// fields are never mixed — a wallet carries at most one of them in
/// practice, and this file only ever reads the annual one.
///
/// Projection model: monthly compounding, future value
/// `balance * (1 + r/12)^n` with r the annual rate as a fraction
/// (4.0%/year → r = 0.04). Every figure derived from this is an
/// estimate that assumes the balance and the rate stay unchanged; the
/// UI must label it as such, never as guaranteed.

/// Kinds that can earn interest: bank accounts and e-wallets.
/// Cash earns nothing, credit is debt, and paylater has its own
/// monthly cost rate — none of those get a growth projection.
bool isGrowthWallet(Wallet w) => w.kind == 'bank' || w.kind == 'ewallet';

/// Whether the wallet detail should show the Growth projection section.
/// An *unset* rate means no section at all — an unset rate is never
/// treated as a zero-rate projection.
bool showGrowthProjection(Wallet w) =>
    isGrowthWallet(w) && w.interestRateAnnual != null;

/// Future value of [balance] after [months] months at an annual rate of
/// [annualRatePct] percent, compounded monthly. Whole IDR, rounded.
int projectedBalance({
  required int balance,
  required double annualRatePct,
  required int months,
}) {
  final r = annualRatePct / 100 / 12;
  return (balance * math.pow(1 + r, months)).round();
}

/// Projected balances for months 0..12 (13 points) — the curve data.
/// Month 0 is the current balance.
List<int> projectionCurve({
  required int balance,
  required double annualRatePct,
}) =>
    List<int>.generate(
      13,
      (m) => projectedBalance(
        balance: balance,
        annualRatePct: annualRatePct,
        months: m,
      ),
    );

/// Projected interest earned over a full year: the 12-month future
/// value minus today's balance. Labeled "projected" in the UI — it is
/// an estimate, not a record of interest actually received (for that,
/// see [interestEarned]).
int projectedYearInterest({
  required int balance,
  required double annualRatePct,
}) =>
    projectedBalance(balance: balance, annualRatePct: annualRatePct, months: 12) -
    balance;

/// Actual interest earned from a wallet's loaded transactions: income
/// rows booked under the Interest category. [interestCategoryId] is
/// the category's id (see [AppDatabase.interestCategoryId]); matching
/// by id, not name, so renaming the category keeps working. With
/// [year] set, only that calendar year's rows count; without it, all
/// rows. This can only total interest that was recorded — a balance
/// jump from a deposit or transfer is indistinguishable from interest,
/// so unrecorded interest never appears here.
int interestEarned(
  List<TransactionWithDetails> txs,
  int interestCategoryId, {
  int? year,
}) {
  var total = 0;
  for (final t in txs) {
    if (t.category.id != interestCategoryId) continue;
    if (t.transaction.kind != 'income') continue;
    if (year != null && t.transaction.date.year != year) continue;
    total += t.transaction.amount;
  }
  return total;
}

/// Display form of an annual rate: "4%" for 4.0, "4.5%" for 4.5.
String formatAnnualRate(double annualRatePct) {
  final s = annualRatePct.toStringAsFixed(2);
  final trimmed = s.contains('.')
      ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
      : s;
  return '$trimmed%';
}
