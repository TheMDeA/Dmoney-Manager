import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';

import '../theme/app_accents.dart';

/// Pull-to-refresh with a coin that drops in as you pull and spins while
/// refreshing, replacing the stock circular spinner.
///
/// The data is local-first so refreshes are cosmetic; the gesture keeps
/// its satisfying snap, now with a coin drop.
class CoinRefreshIndicator extends StatelessWidget {
  const CoinRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      offsetToArmed: 90,
      builder: (context, child, controller) => Stack(
        children: [
          child,
          _CoinIndicator(controller: controller),
        ],
      ),
      child: child,
    );
  }
}

class _CoinIndicator extends StatefulWidget {
  const _CoinIndicator({required this.controller});

  final IndicatorController controller;

  @override
  State<_CoinIndicator> createState() => _CoinIndicatorState();
}

class _CoinIndicatorState extends State<_CoinIndicator>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (c.isLoading && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!c.isLoading && _spin.isAnimating) {
      _spin.stop();
      _spin.reset();
    }
    final value = c.value.clamp(0.0, 1.0);
    final visible = c.isLoading || c.isDragging || c.isArmed;
    if (!visible) return const SizedBox.shrink();
    final accent = context.accent;
    return Positioned(
      top: 12,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: c.isLoading ? 1.0 : (value * 1.4).clamp(0.0, 1.0),
        child: Center(
          child: Transform.translate(
            // The coin drops from above as the pull progresses.
            offset: Offset(0, c.isLoading ? 0 : -28 * (1 - value)),
            child: Transform.scale(
              scale: c.isLoading ? 1.0 : 0.6 + 0.4 * value,
              child: RotationTransition(
                turns: _spin,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                    border: Border.all(
                      color: accent.withValues(alpha: 0.4),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Rp',
                    style: TextStyle(
                      color: onAccent(accent),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
