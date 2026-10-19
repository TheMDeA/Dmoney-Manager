// Date arithmetic for recurring rules, extracted as pure functions so the
// month-end clamping can be unit-tested without a database.
//
// Dart's [DateTime] constructor normalizes out-of-range days, so advancing
// naively from Jan 31 gives Mar 3 (February is skipped) and the day then
// drifts forever. These helpers clamp to the last day of the target month
// instead: Jan 31 -> Feb 28, and stays on the 28th while February is short.

/// Advances [date] by one [frequency] step: daily, weekly, monthly, yearly.
/// Unknown frequencies fall back to a 30-day step (matching legacy data).
DateTime advanceRecurringDate(DateTime date, String frequency) {
  switch (frequency) {
    case 'daily':
      return date.add(const Duration(days: 1));
    case 'weekly':
      return date.add(const Duration(days: 7));
    case 'monthly': {
      final year = date.month == 12 ? date.year + 1 : date.year;
      final month = date.month == 12 ? 1 : date.month + 1;
      return _withClampedDay(year, month, date.day, date.hour, date.minute);
    }
    case 'yearly':
      return _withClampedDay(
          date.year + 1, date.month, date.day, date.hour, date.minute);
    default:
      return date.add(const Duration(days: 30));
  }
}

/// Builds a [DateTime], clamping [day] to the last day of the month when it
/// doesn't fit (e.g. Feb 30 -> Feb 28).
DateTime _withClampedDay(int year, int month, int day, int hour, int minute) {
  // Day 0 of the next month is the last day of [month]; the constructor
  // normalizes month 13 to January of the following year.
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > lastDay ? lastDay : day, hour, minute);
}
