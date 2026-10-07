import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Controls a [Shaker]: call [shake] to play the wiggle once.
class ShakeController {
  _ShakerState? _state;

  void _attach(_ShakerState state) => _state = state;
  void _detach(_ShakerState state) {
    if (_state == state) _state = null;
  }

  /// Plays the shake animation. Safe to call when detached (no-op).
  void shake() => _state?.play();
}

/// Wraps a form field; call [ShakeController.shake] to wiggle it
/// horizontally when its validation fails.
///
/// Timing is a deliberate AppMotion exception: an oscillation needs its
/// own rhythm (like the calculator's invalid-"=" shake), not the one-shot
/// spec. Respects [MediaQuery.disableAnimations] by skipping the wiggle.
class Shaker extends StatefulWidget {
  const Shaker({
    super.key,
    required this.controller,
    required this.child,
  });

  final ShakeController controller;
  final Widget child;

  @override
  State<Shaker> createState() => _ShakerState();
}

class _ShakerState extends State<Shaker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
  }

  @override
  void didUpdateWidget(Shaker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._detach(this);
      widget.controller._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    _controller.dispose();
    super.dispose();
  }

  void play() {
    if (MediaQuery.of(context).disableAnimations) return;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Decaying oscillation: ~3 wiggles fading out.
        final dx = t == 0 || t == 1
            ? 0.0
            : math.sin(t * math.pi * 6) * (1 - t) * 8;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
