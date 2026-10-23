import 'package:flutter_test/flutter_test.dart';
import 'package:dmoney_manager/core/utils/home_range.dart';

void main() {
  // Friday 23 Oct 2026, mid-afternoon.
  final now = DateTime(2026, 10, 23, 14, 30);

  group('homeRangeBounds', () {
    test('day is today only', () {
      final (from, to) = homeRangeBounds('day', now);
      expect(from, DateTime(2026, 10, 23));
      expect(to, DateTime(2026, 10, 23, 23, 59, 59));
    });

    test('week is the Sunday-first calendar week', () {
      final (from, to) = homeRangeBounds('week', now);
      expect(from, DateTime(2026, 10, 18)); // Sunday
      expect(to, DateTime(2026, 10, 24, 23, 59, 59)); // Saturday
    });

    test('week starting on a Sunday starts that same day', () {
      final sunday = DateTime(2026, 10, 18, 9, 0);
      final (from, to) = homeRangeBounds('week', sunday);
      expect(from, DateTime(2026, 10, 18));
      expect(to, DateTime(2026, 10, 24, 23, 59, 59));
    });

    test('month is the full calendar month', () {
      final (from, to) = homeRangeBounds('month', now);
      expect(from, DateTime(2026, 10, 1));
      expect(to, DateTime(2026, 10, 31, 23, 59, 59));
    });

    test('month handles the December rollover', () {
      final (from, to) = homeRangeBounds('month', DateTime(2026, 12, 15));
      expect(from, DateTime(2026, 12, 1));
      expect(to, DateTime(2026, 12, 31, 23, 59, 59));
    });

    test('month handles February in a non-leap year', () {
      final (_, to) = homeRangeBounds('month', DateTime(2026, 2, 10));
      expect(to, DateTime(2026, 2, 28, 23, 59, 59));
    });
  });
}
