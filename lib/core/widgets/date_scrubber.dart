import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_accents.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../utils/haptics.dart';

/// Fast-scroll date scrubber for long transaction lists: a slim drag strip
/// on the right edge. Dragging scrubs the scroll position proportionally
/// (up = newer), with a floating date bubble and a haptic tick whenever the
/// date under the thumb changes. Built for the "All" history view, where
/// month paging doesn't apply.
class DateScrubber extends StatefulWidget {
  const DateScrubber({
    super.key,
    required this.controller,
    required this.itemDates,
    required this.child,
  });

  /// Controls the scrolled list.
  final ScrollController controller;

  /// One date per list item, newest first. Used for the bubble label.
  final List<DateTime> itemDates;

  final Widget child;

  @override
  State<DateScrubber> createState() => _DateScrubberState();
}

class _DateScrubberState extends State<DateScrubber> {
  final _stripKey = GlobalKey();
  var _scrubbing = false;
  DateTime? _bubbleDate;

  void _scrubTo(Offset globalPosition) {
    final box =
        _stripKey.currentContext?.findRenderObject() as RenderBox?;
    final controller = widget.controller;
    if (box == null || !controller.hasClients) return;
    final local = box.globalToLocal(globalPosition);
    final fraction = (local.dy / box.size.height).clamp(0.0, 1.0);
    final max = controller.position.maxScrollExtent;
    if (max <= 0) return;
    controller.jumpTo(fraction * max);
    final dates = widget.itemDates;
    if (dates.isNotEmpty) {
      final raw = dates[(fraction * (dates.length - 1)).round()];
      final day = DateTime(raw.year, raw.month, raw.day);
      if (day != _bubbleDate) {
        setState(() => _bubbleDate = day);
        Haptics.select();
      }
    }
  }

  void _onStart(DragStartDetails d) {
    setState(() {
      _scrubbing = true;
      _bubbleDate = null;
    });
    _scrubTo(d.globalPosition);
  }

  void _onUpdate(DragUpdateDetails d) => _scrubTo(d.globalPosition);

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
            key: _stripKey,
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
        // Floating date bubble while scrubbing.
        if (_scrubbing && _bubbleDate != null)
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
                  DateFormat('d MMM yyyy').format(_bubbleDate!),
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
