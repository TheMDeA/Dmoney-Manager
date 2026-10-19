import 'package:flutter_test/flutter_test.dart';

import 'package:dmoney_manager/core/utils/recurring_dates.dart';

/// advanceRecurringDate: month-end dates clamp instead of drifting.
/// (Jan 31 + 1 month must be Feb 28, not Mar 3.)
void main() {
  test('daily and weekly advance by fixed steps', () {
    final d = DateTime(2026, 10, 19, 20, 30);
    expect(advanceRecurringDate(d, 'daily'), DateTime(2026, 10, 20, 20, 30));
    expect(advanceRecurringDate(d, 'weekly'), DateTime(2026, 10, 26, 20, 30));
  });

  test('monthly keeps the day for normal months', () {
    final d = DateTime(2026, 10, 15, 9, 0);
    expect(advanceRecurringDate(d, 'monthly'), DateTime(2026, 11, 15, 9, 0));
  });

  test('monthly clamps Jan 31 to Feb 28 (no drift to March)', () {
    final jan31 = DateTime(2026, 1, 31, 10, 0);
    final feb = advanceRecurringDate(jan31, 'monthly');
    expect(feb, DateTime(2026, 2, 28, 10, 0));
    // And it stays clamped afterwards instead of drifting.
    expect(advanceRecurringDate(feb, 'monthly'), DateTime(2026, 3, 28, 10, 0));
  });

  test('monthly wraps December to January of the next year', () {
    final d = DateTime(2026, 12, 15, 9, 0);
    expect(advanceRecurringDate(d, 'monthly'), DateTime(2027, 1, 15, 9, 0));
  });

  test('monthly clamps Dec 31 to Jan 31 (31-day month)', () {
    final d = DateTime(2026, 12, 31, 9, 0);
    expect(advanceRecurringDate(d, 'monthly'), DateTime(2027, 1, 31, 9, 0));
  });

  test('yearly clamps Feb 29 to Feb 28 on non-leap years', () {
    final d = DateTime(2024, 2, 29, 12, 0);
    expect(advanceRecurringDate(d, 'yearly'), DateTime(2025, 2, 28, 12, 0));
  });

  test('yearly stays clamped once past a leap day', () {
    // 2028 is a leap year, but the clamped 28th stays put — no drift back.
    expect(advanceRecurringDate(DateTime(2027, 2, 28, 12, 0), 'yearly'),
        DateTime(2028, 2, 28, 12, 0));
  });

  test('unknown frequency falls back to 30 days', () {
    final d = DateTime(2026, 10, 19, 20, 30);
    expect(
        advanceRecurringDate(d, 'fortnightly'), DateTime(2026, 11, 18, 20, 30));
  });
}
