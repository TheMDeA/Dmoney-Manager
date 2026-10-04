import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Linear progress bar whose fill tweens to a new value instead of jumping.
/// Used for budget and goal progress so month changes and new transactions
/// animate the bars.
class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.minHeight = 8,
    this.borderRadius = 4,
  });

  final double value;
  final Color color;
  final Color backgroundColor;
  final double minHeight;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0.0, 1.0)),
      duration: AppMotion.slow,
      curve: AppMotion.enter,
      builder: (context, v, _) => LinearProgressIndicator(
        value: v,
        backgroundColor: backgroundColor,
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        minHeight: minHeight,
      ),
    );
  }
}
