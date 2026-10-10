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

  // ------------------------------- accounts --------------------------------
  /// Global account scope: null means "All accounts".
  static int? get selectedAccountId => _p.getInt('selectedAccountId');
  static Future<void> setSelectedAccountId(int? v) => v == null
      ? _p.remove('selectedAccountId')
      : _p.setInt('selectedAccountId', v);

  // ----------------------------- notifications ----------------------------
  static bool get budgetAlerts => _p.getBool('notifBudgetAlerts') ?? true;
  static Future<void> setBudgetAlerts(bool v) =>
      _p.setBool('notifBudgetAlerts', v);

  static bool get debtReminders => _p.getBool('notifDebtReminders') ?? true;
  static Future<void> setDebtReminders(bool v) =>
      _p.setBool('notifDebtReminders', v);

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
