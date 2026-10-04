import '../../data/database/app_database.dart';

/// A repeating charge found in the transaction history that has no
/// recurring rule yet.
class DetectedSubscription {
  const DetectedSubscription({
    required this.note,
    required this.amount,
    required this.frequency,
    required this.lastDate,
    required this.nextExpected,
    required this.occurrences,
    required this.walletId,
    required this.categoryId,
  });

  /// Display name, taken from the most recent occurrence.
  final String note;

  /// Median amount across occurrences.
  final int amount;

  /// 'weekly' | 'monthly' | 'yearly' (matches the recurring-rule values).
  final String frequency;
  final DateTime lastDate;

  /// When the next charge is expected.
  final DateTime nextExpected;
  final int occurrences;

  /// Wallet / category of the most recent occurrence, reused for the rule.
  final int walletId;
  final int categoryId;

  /// Stable identity used to dismiss a detection permanently.
  String get fingerprint =>
      '${note.trim().toLowerCase()}|$frequency';
}

/// Scans income/expense transactions for repeating charges:
/// same note, stable amount, regular cadence, at least 3 occurrences.
/// Pure function — feed it [AppDatabase.learnableTransactions].
List<DetectedSubscription> detectSubscriptions(List<Transaction> txs) {
  final groups = <String, List<Transaction>>{};
  for (final t in txs) {
    if (t.kind != 'expense') continue;
    final note = t.note.trim();
    if (note.isEmpty) continue;
    // Transfers, debt movements and already-ruled occurrences can't be
    // subscriptions.
    if (t.debtId != null ||
        t.debtPaymentId != null ||
        t.recurringId != null) {
      continue;
    }
    groups.putIfAbsent(note.toLowerCase(), () => []).add(t);
  }

  final out = <DetectedSubscription>[];
  for (final entry in groups.entries) {
    final list = entry.value
      ..sort((a, b) => a.date.compareTo(b.date));
    if (list.length < 3) continue;

    // Amount stability: within 5% of the median.
    final amounts = list.map((t) => t.amount).toList()..sort();
    final medianAmount = amounts[amounts.length ~/ 2];
    if (medianAmount <= 0) continue;
    if ((amounts.last - amounts.first) / medianAmount > 0.05) continue;

    // Cadence regularity: every gap within -25% / +30% of the median gap.
    final gaps = <double>[];
    for (var i = 1; i < list.length; i++) {
      gaps.add(
          list[i].date.difference(list[i - 1].date).inHours / 24.0);
    }
    gaps.sort();
    final medianGap = gaps[gaps.length ~/ 2];
    if (!gaps.every(
        (g) => g >= medianGap * 0.75 && g <= medianGap * 1.3)) {
      continue;
    }

    final String frequency;
    if (medianGap >= 6 && medianGap <= 8) {
      frequency = 'weekly';
    } else if (medianGap >= 27 && medianGap <= 33) {
      frequency = 'monthly';
    } else if (medianGap >= 355 && medianGap <= 375) {
      frequency = 'yearly';
    } else {
      continue; // not a supported recurring cadence
    }

    final last = list.last;
    out.add(DetectedSubscription(
      note: last.note.trim(),
      amount: medianAmount,
      frequency: frequency,
      lastDate: last.date,
      nextExpected:
          last.date.add(Duration(days: medianGap.round())),
      occurrences: list.length,
      walletId: last.walletId,
      categoryId: last.categoryId,
    ));
  }
  out.sort((a, b) => b.occurrences.compareTo(a.occurrences));
  return out;
}
