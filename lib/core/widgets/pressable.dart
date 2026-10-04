import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Press physics: scales [child] down slightly while touched, springing
/// back on release. The child keeps its own tap handling (InkWell, etc.);
/// this only adds the tactile scale, so it composes with existing ripples.
///
/// Apply to tappable cards and tiles — not to list rows with swipe
/// actions, where the scale fights the gesture.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.pressedScale = 0.97,
  });

  final Widget child;

  /// Scale while pressed. 0.97 reads as tactile without looking broken.
  final double pressedScale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.fast,
    reverseDuration: AppMotion.normal,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pressDown(TapDownDetails _) {
    _controller.animateTo(1, curve: Curves.easeOut);
  }

  void _release() {
    // Springy return with a whisper of overshoot.
    _controller.animateBack(0, curve: Curves.easeOutBack);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _pressDown,
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale =
              1.0 - (1.0 - widget.pressedScale) * _controller.value;
          return Transform.scale(scale: scale, child: child);
        },
        child: widget.child,
      ),
    );
  }
}
