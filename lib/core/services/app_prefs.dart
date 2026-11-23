import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted user preferences (theme, lock, PIN, profile, notifications).
class AppPrefs {
  AppPrefs._();
  static late SharedPreferences _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  // ------------------------------ appearance ------------------------------
  static ThemeMode get themeMode =>
      ThemeMode.values[_p.getInt('themeMode') ?? ThemeMode.system.index];
  static Future<void> setThemeMode(ThemeMode m) =>
      _p.setInt('themeMode', m.index);

  static String get accentId => _p.getString('accentId') ?? 'lime';
  static Future<void> setAccentId(String v) =>
      _p.setString('accentId', v);

  // --------------------------------- lock ---------------------------------
  static bool get lockEnabled => _p.getBool('lockEnabled') ?? false;
  static Future<void> setLockEnabled(bool v) =>
      _p.setBool('lockEnabled', v);

  // ------------------------------ balance --------------------------------
  /// Whether the Home balance amounts are hidden. Persisted (not just
  /// screen state) because the shell's PageView disposes tabs more
  /// than one page away, which used to reset the eye toggle every
  /// time the user visited Stats, Budgets or Settings and came back.
  static bool get balanceHidden => _p.getBool('balanceHidden') ?? false;
  static Future<void> setBalanceHidden(bool v) =>
      _p.setBool('balanceHidden', v);

  // ------------------------------- haptics --------------------------------
  static bool get hapticsEnabled => _p.getBool('hapticsEnabled') ?? true;
  static Future<void> setHapticsEnabled(bool v) =>
      _p.setBool('hapticsEnabled', v);

  // ------------------------- smart suggestions ----------------------------
  static bool get smartSuggestions =>
      _p.getBool('smartSuggestions') ?? true;
  static Future<void> setSmartSuggestions(bool v) =>
      _p.setBool('smartSuggestions', v);

  static bool get keywordBackfillDone =>
      _p.getBool('keywordBackfillDone') ?? false;
  static Future<void> setKeywordBackfillDone(bool v) =>
      _p.setBool('keywordBackfillDone', v);

  // --------------------------- auto update check --------------------------
  static bool get autoCheckUpdate => _p.getBool('autoCheckUpdate') ?? true;
  static Future<void> setAutoCheckUpdate(bool v) =>
      _p.setBool('autoCheckUpdate', v);

  /// Last auto-check timestamp (ms since epoch). Throttles to once/day.
  static int get lastUpdateCheck => _p.getInt('lastUpdateCheck') ?? 0;
  static Future<void> setLastUpdateCheck(int v) =>
      _p.setInt('lastUpdateCheck', v);

  /// Version the user dismissed the auto-check nudge for — don't nag again.
  static String get dismissedUpdateVersion =>
      _p.getString('dismissedUpdateVersion') ?? '';
  static Future<void> setDismissedUpdateVersion(String v) =>
      _p.setString('dismissedUpdateVersion', v);

  static String _hashPin(String pin) =>
      sha256.convert(utf8.encode('dmoney::$pin')).toString();

  static bool get hasPin => _p.getString('pinHash') != null;
  static Future<void> setPin(String pin) =>
      _p.setString('pinHash', _hashPin(pin));
  static bool verifyPin(String pin) => _p.getString('pinHash') == _hashPin(pin);
  static Future<void> clearPin() => _p.remove('pinHash');

  // -------------------------------- profile -------------------------------
  static String get displayName => _p.getString('displayName') ?? 'Miko';
  static Future<void> setDisplayName(String v) =>
      _p.setString('displayName', v);

  // -------------------------------- currency -------------------------------
  static String get currencyCode => _p.getString('currencyCode') ?? 'IDR';
  static Future<void> setCurrencyCode(String v) =>
      _p.setString('currencyCode', v);

  // -------------------------------- language -------------------------------
  /// UI language override: null means "follow the device language".
  static String? get languageCode => _p.getString('languageCode');
  static Future<void> setLanguageCode(String? v) => v == null
      ? _p.remove('languageCode')
      : _p.setString('languageCode', v);

  // ------------------------------- accounts --------------------------------
  /// Global account scope: null means "All accounts".
  static int? get selectedAccountId => _p.getInt('selectedAccountId');
  static Future<void> setSelectedAccountId(int? v) => v == null
      ? _p.remove('selectedAccountId')
      : _p.setInt('selectedAccountId', v);

  // --------------------------------- sync ---------------------------------
  /// Local account ids included in Supabase sync (idea #3, P2 push
  /// side). Null means "all accounts" — the default, so behaviour is
  /// unchanged until the user toggles accounts in the sync settings
  /// (P5). Rows of an unselected account stay queued and push when
  /// the account is toggled back on. Stored as strings:
  /// SharedPreferences has no int lists.
  static List<int>? get syncAccountIds {
    final raw = _p.getStringList('syncAccountIds');
    if (raw == null) return null;
    return [
      for (final s in raw) int.tryParse(s) ?? -1,
    ].where((i) => i >= 0).toList();
  }

  static Future<void> setSyncAccountIds(List<int>? ids) => ids == null
      ? _p.remove('syncAccountIds')
      : _p.setStringList(
          'syncAccountIds',
          [for (final i in ids) '$i'],
        );

  /// Whether [accountId] is selected for sync. Null pref = all on.
  static bool isAccountSynced(int accountId) {
    final ids = syncAccountIds;
    return ids == null || ids.contains(accountId);
  }

  /// This device's stable id for the `devices` heartbeat table
  /// (idea #2, P5). Generated once on the first sync and kept in
  /// prefs — it is not a user secret, just a per-device label key.
  static String? get syncDeviceId => _p.getString('syncDeviceId');
  static Future<void> setSyncDeviceId(String id) =>
      _p.setString('syncDeviceId', id);

  /// The last sync cycle's fatal error, if any (P5 status UI).
  /// Cleared on the next clean cycle. Human-readable only — the
  /// Settings screen shows it, nothing else acts on it.
  static String? get syncLastError => _p.getString('syncLastError');
  static Future<void> setSyncLastError(String? message) => message == null
      ? _p.remove('syncLastError')
      : _p.setString('syncLastError', message);

  /// The named mode of the last sync cycle's fatal error, if any
  /// (P6, §12). Stored as the [SyncFailureMode] name; cleared on
  /// the next clean cycle. The Settings screen shows the named
  /// mode, not the raw error string.
  static String? get syncFailureMode => _p.getString('syncFailureMode');
  static Future<void> setSyncFailureMode(String? mode) => mode == null
      ? _p.remove('syncFailureMode')
      : _p.setString('syncFailureMode', mode);

  /// Total outbox entries when the chunked initial push started
  /// (P6). Present only while a chunked push is in progress; the
  /// status UI shows "X of Y rows" from it, and the triggers keep
  /// scheduling cycles until it clears.
  static int? get syncInitialPushTotal => _p.getInt('syncInitialPushTotal');
  static Future<void> setSyncInitialPushTotal(int? total) => total == null
      ? _p.remove('syncInitialPushTotal')
      : _p.setInt('syncInitialPushTotal', total);

  /// Whether the initial-push seed ran on this device (P6): the
  /// one-time enqueue of every pre-sync row (seed categories,
  /// v18-backfilled rows) into the outbox. Once true it never
  /// runs again — later cycles only push what changed since.
  static bool get syncInitialPushSeeded =>
      _p.getBool('syncInitialPushSeeded') ?? false;
  static Future<void> setSyncInitialPushSeeded(bool v) =>
      _p.setBool('syncInitialPushSeeded', v);

  /// The `server_updated_at` of the `sync_prefs` row as last seen
  /// (P5, §7). The ordering authority for prefs: a server row
  /// newer than this stamp wins over local values; otherwise local
  /// values push. Canonical UTC ISO, like the pull cursor.
  static String? get syncPrefsUpdatedAt => _p.getString('syncPrefsUpdatedAt');
  static Future<void> setSyncPrefsUpdatedAt(String? stamp) => stamp == null
      ? _p.remove('syncPrefsUpdatedAt')
      : _p.setString('syncPrefsUpdatedAt', stamp);

  // ----------------------------- notifications ----------------------------
  static bool get budgetAlerts => _p.getBool('notifBudgetAlerts') ?? true;
  static Future<void> setBudgetAlerts(bool v) =>
      _p.setBool('notifBudgetAlerts', v);

  static bool get debtReminders => _p.getBool('notifDebtReminders') ?? true;
  static Future<void> setDebtReminders(bool v) =>
      _p.setBool('notifDebtReminders', v);

  static bool get paylaterReminders =>
      _p.getBool('notifPaylaterReminders') ?? true;
  static Future<void> setPaylaterReminders(bool v) =>
      _p.setBool('notifPaylaterReminders', v);

  // ------------------------------ paylater --------------------------------
  /// Self-imposed paylater freeze: while true, the add-transaction sheet
  /// blocks new expenses on paylater wallets until the user unfreezes.
  static bool get paylaterFrozen => _p.getBool('paylaterFrozen') ?? false;
  static Future<void> setPaylaterFrozen(bool v) =>
      _p.setBool('paylaterFrozen', v);

  /// Fingerprints of subscription detections the user dismissed or
  /// already converted into rules, so the scanner doesn't resurface them.
  static List<String> get dismissedDetections =>
      _p.getStringList('dismissedDetections') ?? const [];
  static Future<void> dismissDetection(String fingerprint) => _p.setStringList(
      'dismissedDetections',
      [...dismissedDetections, fingerprint]);

  /// Tracks which (budget, month, level) alerts already fired.
  static bool budgetLevelNotified(int budgetId, String month, int level) =>
      _p.getBool('budgetNotified_${budgetId}_${month}_$level') ?? false;
  static Future<void> markBudgetLevelNotified(
          int budgetId, String month, int level) =>
      _p.setBool('budgetNotified_${budgetId}_${month}_$level', true);

  /// Whether the feature tour has been shown (or skipped). Fresh installs
  /// see it once right after onboarding; it stays replayable from Settings.
  static bool get hasSeenTour => _p.getBool('hasSeenTour') ?? false;
  static Future<void> setHasSeenTour(bool v) =>
      _p.setBool('hasSeenTour', v);
}
