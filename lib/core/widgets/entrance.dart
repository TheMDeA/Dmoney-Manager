import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Plays a fade + rise entrance once when first inserted into the tree.
///
/// Give list items a stable [Key] (e.g. the row id) so rebuilds don't
/// replay the animation — only newly inserted items animate in.
/// Pass a per-index [delay] for a staggered list effect.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.distance = 14,
    this.duration = AppMotion.normal,
  });

  final Widget child;
  final Duration delay;
  final double distance;
  final Duration duration;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: Offset(0, widget.distance / 100),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.enter));

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
