import 'package:dmoney_manager/core/services/subscription_detector.dart';
import 'package:dmoney_manager/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _tx({
  required String note,
  required int amount,
  required DateTime date,
  String kind = 'expense',
  int? recurringId,
}) {
  return Transaction(
    id: 0,
    walletId: 1,
    categoryId: 1,
    kind: kind,
    amount: amount,
    note: note,
    date: date,
    createdAt: date,
    toWalletId: null,
    debtId: null,
    debtPaymentId: null,
    recurringId: recurringId,
  );
}

void main() {
  group('detectSubscriptions', () {
    test('finds a monthly subscription', () {
      final txs = [
        for (var i = 0; i < 4; i++)
          _tx(
            note: 'Spotify',
            amount: 54990,
            date: DateTime(2026, 6 + i, 15),
          ),
      ];
      final found = detectSubscriptions(txs);
      expect(found, hasLength(1));
      expect(found.first.note, 'Spotify');
      expect(found.first.frequency, 'monthly');
      expect(found.first.amount, 54990);
      expect(found.first.occurrences, 4);
      // Gaps are 30/31/31 days -> median 31 -> next Sep 15 + 31d = Oct 16.
      expect(
        found.first.nextExpected,
        DateTime(2026, 9, 15).add(const Duration(days: 31)),
      );
    });

    test('finds a weekly subscription', () {
      final base = DateTime(2026, 9, 1);
      final txs = [
        for (var i = 0; i < 5; i++)
          _tx(
            note: 'Gym',
            amount: 25000,
            date: base.add(Duration(days: 7 * i)),
          ),
      ];
      final found = detectSubscriptions(txs);
      expect(found, hasLength(1));
      expect(found.first.frequency, 'weekly');
    });

    test('ignores groups with fewer than 3 occurrences', () {
      final txs = [
        _tx(note: 'Netflix', amount: 65000, date: DateTime(2026, 8, 1)),
        _tx(note: 'Netflix', amount: 65000, date: DateTime(2026, 9, 1)),
      ];
      expect(detectSubscriptions(txs), isEmpty);
    });

    test('ignores unstable amounts', () {
      final txs = [
        _tx(note: 'Koppa', amount: 50000, date: DateTime(2026, 7, 1)),
        _tx(note: 'Koppa', amount: 90000, date: DateTime(2026, 8, 1)),
        _tx(note: 'Koppa', amount: 60000, date: DateTime(2026, 9, 1)),
      ];
      expect(detectSubscriptions(txs), isEmpty);
    });

    test('ignores irregular cadence', () {
      final txs = [
        _tx(note: 'Domain', amount: 150000, date: DateTime(2026, 1, 10)),
        _tx(note: 'Domain', amount: 150000, date: DateTime(2026, 2, 10)),
        // big gap breaks the pattern
        _tx(note: 'Domain', amount: 150000, date: DateTime(2026, 8, 10)),
      ];
      expect(detectSubscriptions(txs), isEmpty);
    });

    test('ignores income and already-ruled transactions', () {
      final txs = [
        for (var i = 0; i < 4; i++)
          _tx(
            note: 'Salary',
            amount: 5000000,
            date: DateTime(2026, 6 + i, 1),
            kind: 'income',
          ),
        for (var i = 0; i < 4; i++)
          _tx(
            note: 'Rent',
            amount: 1500000,
            date: DateTime(2026, 6 + i, 5),
            recurringId: 7,
          ),
      ];
      expect(detectSubscriptions(txs), isEmpty);
    });

    test('note matching is case-insensitive', () {
      final txs = [
        _tx(note: 'spotify', amount: 54990, date: DateTime(2026, 6, 15)),
        _tx(note: 'Spotify', amount: 54990, date: DateTime(2026, 7, 15)),
        _tx(note: 'SPOTIFY', amount: 54990, date: DateTime(2026, 8, 15)),
      ];
      final found = detectSubscriptions(txs);
      expect(found, hasLength(1));
      expect(found.first.occurrences, 3);
    });

    test('fingerprint is stable', () {
      final txs = [
        for (var i = 0; i < 3; i++)
          _tx(
            note: '  Spotify ',
            amount: 54990,
            date: DateTime(2026, 6 + i, 15),
          ),
      ];
      expect(
        detectSubscriptions(txs).first.fingerprint,
        'spotify|monthly',
      );
    });
  });
}
