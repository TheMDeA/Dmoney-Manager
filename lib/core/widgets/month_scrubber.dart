import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_accents.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../utils/haptics.dart';

/// Fast-scroll date scrubber for month-paged lists: a slim drag strip on the
/// right edge. Dragging vertically scrubs through months (up = newer),
/// with a floating month bubble and a haptic tick per month.
class MonthScrubber extends StatefulWidget {
  const MonthScrubber({
    super.key,
    required this.month,
    required this.onShift,
    required this.child,
  });

  final DateTime month;
  final ValueChanged<int> onShift;
  final Widget child;

  @override
  State<MonthScrubber> createState() => _MonthScrubberState();
}

class _MonthScrubberState extends State<MonthScrubber> {
  var _scrubbing = false;
  var _accum = 0.0;

  static const _pxPerMonth = 56.0;

  void _onStart(_) => setState(() {
        _scrubbing = true;
        _accum = 0;
      });

  void _onUpdate(DragUpdateDetails d) {
    _accum += d.delta.dy;
    var shifted = false;
    while (_accum <= -_pxPerMonth) {
      _accum += _pxPerMonth;
      widget.onShift(1); // drag up → newer month
      shifted = true;
    }
    while (_accum >= _pxPerMonth) {
      _accum -= _pxPerMonth;
      widget.onShift(-1); // drag down → older month
      shifted = true;
    }
    if (shifted) Haptics.select();
  }

  void _onEnd(_) => setState(() => _scrubbing = false);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Drag strip.
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: 24,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: _onStart,
            onVerticalDragUpdate: _onUpdate,
            onVerticalDragEnd: _onEnd,
            onVerticalDragCancel: () =>
                setState(() => _scrubbing = false),
            child: Center(
              child: AnimatedContainer(
                duration: AppMotion.fast,
                width: 4,
                height: _scrubbing ? 120 : 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: context.textMuted.withValues(
                      alpha: _scrubbing ? 0.55 : 0.25),
                ),
              ),
            ),
          ),
        ),
        // Floating month bubble while scrubbing.
        if (_scrubbing)
          Positioned(
            right: 30,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.accent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  DateFormat('MMM yyyy').format(widget.month),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: onAccent(context.accent),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
