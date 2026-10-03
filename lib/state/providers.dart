import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/app_prefs.dart';
import '../data/database/app_database.dart';

/// The database is created in main() and injected here.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden in main()'),
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => AppPrefs.themeMode;
  Future<void> set(ThemeMode mode) async {
    await AppPrefs.setThemeMode(mode);
    state = mode;
  }
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

/// Bottom-nav tab index, so quick actions can jump to a tab.
class TabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void go(int i) => state = i;
}

final tabIndexProvider =
    NotifierProvider<TabIndexNotifier, int>(TabIndexNotifier.new);

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
  bool build() => AppPrefs.lockEnabled;
  Future<void> set(bool value) async {
    await AppPrefs.setLockEnabled(value);
    state = value;
  }
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

class DisplayNameNotifier extends Notifier<String> {
  @override
  String build() => AppPrefs.displayName;
  Future<void> set(String v) async {
    await AppPrefs.setDisplayName(v);
    state = v;
  }
}

final displayNameProvider =
    NotifierProvider<DisplayNameNotifier, String>(DisplayNameNotifier.new);

/// Stream of all accounts; empty means the user hasn't onboarded yet.
final accountsStreamProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(databaseProvider).watchAccounts();
});
