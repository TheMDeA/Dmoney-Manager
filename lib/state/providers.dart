import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/app_prefs.dart';
import '../core/services/drive_backup_service.dart';
import '../data/database/app_database.dart';

/// The database is created in main() and injected here.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden in main()'),
);

/// Google Drive backup (sign-in state lives inside the service).
final driveBackupServiceProvider =
    Provider<DriveBackupService>((ref) => DriveBackupService());

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

class AccentNotifier extends Notifier<String> {
  @override
  String build() => AppPrefs.accentId;
  Future<void> set(String id) async {
    await AppPrefs.setAccentId(id);
    state = id;
  }
}

/// Selected theme accent id ('lime' default, or 'material_you').
final accentProvider =
    NotifierProvider<AccentNotifier, String>(AccentNotifier.new);

/// Currently selected account filter on the Wallets screen (null = all).
class SelectedAccountNotifier extends Notifier<int?> {
  @override
  int? build() => AppPrefs.selectedAccountId;
  Future<void> select(int? id) async {
    await AppPrefs.setSelectedAccountId(id);
    state = id;
  }
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

class HapticsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => AppPrefs.hapticsEnabled;
  Future<void> set(bool value) async {
    await AppPrefs.setHapticsEnabled(value);
    state = value;
  }
}

final hapticsEnabledProvider =
    NotifierProvider<HapticsEnabledNotifier, bool>(
        HapticsEnabledNotifier.new);

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

/// Whether balance and total figures are hidden app-wide (privacy
/// mode). Seeded from prefs; the Home eye toggle flips it, and every
/// balance/total display watches it so all menus hide together.
/// Individual transaction amounts are deliberately not gated by this.
class BalanceHiddenNotifier extends Notifier<bool> {
  @override
  bool build() => AppPrefs.balanceHidden;
  Future<void> toggle() async {
    await AppPrefs.setBalanceHidden(!state);
    state = !state;
  }
}

final balanceHiddenProvider =
    NotifierProvider<BalanceHiddenNotifier, bool>(BalanceHiddenNotifier.new);

/// The date of the last transaction saved in this app session, so the add
/// sheet reopens on it instead of today. Deliberately NOT persisted: it
/// lives only in memory, so a fresh app launch starts on today again.
class LastTransactionDateNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void set(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }
}

final lastTransactionDateProvider =
    NotifierProvider<LastTransactionDateNotifier, DateTime?>(
      LastTransactionDateNotifier.new,
    );
