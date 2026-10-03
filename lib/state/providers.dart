import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';

/// The database is created in main() and injected here.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden in main()'),
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;
  void set(ThemeMode mode) => state = mode;
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Currently selected account filter on the Wallets screen (null = all).
class SelectedAccountNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void select(int? id) => state = id;
}

final selectedAccountProvider =
    NotifierProvider<SelectedAccountNotifier, int?>(SelectedAccountNotifier.new);

/// 'day' | 'week' | 'month' — the Home screen date-range switcher.
class DateRangeNotifier extends Notifier<String> {
  @override
  String build() => 'month';
  void set(String value) => state = value;
}

final dateRangeProvider =
    NotifierProvider<DateRangeNotifier, String>(DateRangeNotifier.new);

class LockEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final lockEnabledProvider =
    NotifierProvider<LockEnabledNotifier, bool>(LockEnabledNotifier.new);

class LockedNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void lock() => state = true;
  void unlock() => state = false;
}

final lockedProvider = NotifierProvider<LockedNotifier, bool>(LockedNotifier.new);
