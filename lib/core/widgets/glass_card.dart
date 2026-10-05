import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted "liquid glass" card used for hero surfaces.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.onTap,
    this.glowColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;

  /// Optional accent glow washed from the top of the card, e.g. the
  /// home balance hero. Null keeps the plain frosted look.
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.65);
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: glowColor == null
                ? null
                : RadialGradient(
                    center: const Alignment(0, -0.7),
                    radius: 1.6,
                    colors: [glowColor!.withValues(alpha: 0.16), base],
                  ),
            color: glowColor == null ? base : null,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color:
                  glowColor?.withValues(alpha: 0.28) ??
                  (isDark
                      ? Colors.white.withValues(alpha: 0.09)
                      : Colors.black.withValues(alpha: 0.06)),
            ),
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}
