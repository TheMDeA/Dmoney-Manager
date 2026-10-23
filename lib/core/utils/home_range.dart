/// Calendar bounds for the Home screen's Day/Week/Month switcher.
///
/// These are real calendar periods, matching the rest of the app:
/// Stats and Budgets use calendar months, and the calendar grid starts
/// weeks on Sunday. (They used to be rolling 7/30-day windows, which
/// made Home's "Month" disagree with Stats.)
(DateTime, DateTime) homeRangeBounds(String range, DateTime now) {
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
  switch (range) {
    case 'day':
      return (todayStart, todayEnd);
    case 'week':
      // Sunday-first, like the calendar grid (weekday % 7: Sun=0).
      final sunday = todayStart.subtract(Duration(days: now.weekday % 7));
      final saturdayEnd = sunday
          .add(const Duration(days: 7))
          .subtract(const Duration(seconds: 1));
      return (sunday, saturdayEnd);
    default: // 'month'
      final first = DateTime(now.year, now.month);
      final last = DateTime(now.year, now.month + 1)
          .subtract(const Duration(seconds: 1));
      return (first, last);
  }
}
