import 'package:flutter/services.dart';

/// Centralized haptic feedback so the whole app uses the same intensities:
/// - [select] for segmented controls, chips, and tab switches
/// - [light] for toggles and minor confirmations
/// - [medium] for consequential actions (save, delete)
abstract final class Haptics {
  static void select() => HapticFeedback.selectionClick();
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
}
