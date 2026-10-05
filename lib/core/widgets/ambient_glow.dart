import 'package:flutter/material.dart';

import '../theme/app_accents.dart';

/// Soft accent wash painted behind a screen's content so the backdrop
/// isn't flat black. Follows the active theme accent.
class AmbientGlow extends StatelessWidget {
  const AmbientGlow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -1.1),
                radius: 1.4,
                colors: [
                  context.accent.withValues(alpha: 0.12),
                  context.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
