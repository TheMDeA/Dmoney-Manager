import 'package:flutter/material.dart';

import '../theme/app_accents.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// Segmented control whose selected pill slides between options instead of
/// jumping. Matches the app's SegmentedButton theme (accent fill, on-accent
/// label) but animates the indicator with [AppMotion.normal].
///
/// Honors [MediaQuery.disableAnimations] by snapping the pill instantly.
class SlidingSegmented<T> extends StatelessWidget {
  const SlidingSegmented({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
  }) : assert(values.length == labels.length && values.length >= 2);

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final index = values.indexOf(selected).clamp(0, values.length - 1);
    final accent = context.accent;
    final disabled = MediaQuery.of(context).disableAnimations;
    // NB: the LayoutBuilder must sit *inside* the padding so segWidth
    // matches the Row's actual segment width. Outside, the 3px padding
    // makes the pill overflow and clip on the last segment.
    return Container(
      decoration: BoxDecoration(
        color: context.raised,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segWidth = constraints.maxWidth / values.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: disabled ? Duration.zero : AppMotion.normal,
                curve: AppMotion.enter,
                left: index * segWidth,
                top: 0,
                bottom: 0,
                width: segWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: accent,
                    // Stadium: fully rounded ends for a true pill look.
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < values.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (values[i] != selected) onChanged(values[i]);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          alignment: Alignment.center,
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: i == index
                                  ? onAccent(accent)
                                  : context.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
