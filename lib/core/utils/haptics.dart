import 'package:flutter/services.dart';

import '../../core/services/app_prefs.dart';

/// Centralized haptic feedback so the whole app uses the same intensities:
/// - [select] for segmented controls, chips, and tab switches
/// - [light] for toggles and minor confirmations
/// - [medium] for consequential actions (save, delete)
///
/// All methods are no-ops when the user disables haptics in Settings.
abstract final class Haptics {
  static bool get _on => AppPrefs.hapticsEnabled;

  static void select() {
    if (_on) HapticFeedback.selectionClick();
  }

  static void light() {
    if (_on) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (_on) HapticFeedback.mediumImpact();
  }
}
