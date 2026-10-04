import 'package:flutter/material.dart';

/// App-wide motion spec: every animation in the app uses these durations
/// and curves so motion feels coherent instead of per-screen improvised.
///
/// - [fast]: micro-interactions (toggles, chips, small fades)
/// - [normal]: standard transitions (page routes, switchers, sheets, lists)
/// - [slow]: emphasis moments (charts, count-ups, heroes)
///
/// - [enter]: elements arriving on screen
/// - [exit]: elements leaving the screen
///
/// Deliberate exceptions (documented at their sites, not spec drift):
/// continuous loops (the skeleton shimmer) and oscillations (the
/// passcode shake) keep their own timing — the spec covers one-shot
/// transitions.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 600);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
}
