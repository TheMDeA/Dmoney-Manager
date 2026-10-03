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

  // ----------------------------- notifications ----------------------------
  static bool get budgetAlerts => _p.getBool('notifBudgetAlerts') ?? true;
  static Future<void> setBudgetAlerts(bool v) =>
      _p.setBool('notifBudgetAlerts', v);

  static bool get debtReminders => _p.getBool('notifDebtReminders') ?? true;
  static Future<void> setDebtReminders(bool v) =>
      _p.setBool('notifDebtReminders', v);

  /// Tracks which (budget, month, level) alerts already fired.
  static bool budgetLevelNotified(int budgetId, String month, int level) =>
      _p.getBool('budgetNotified_${budgetId}_${month}_$level') ?? false;
  static Future<void> markBudgetLevelNotified(
          int budgetId, String month, int level) =>
      _p.setBool('budgetNotified_${budgetId}_${month}_$level', true);
}
