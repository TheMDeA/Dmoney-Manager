import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../utils/formatters.dart';

/// Total-balance display with a count-up privacy toggle.
///
/// Instead of fading between the amount and the dots, the digits visibly
/// count down to zero when hiding (landing on the dot mask) and count back
/// up from zero when revealing. Balance changes while visible keep the
/// regular slow count-up.
///
/// The tween always retargets from the currently displayed value, so rapid
/// toggles or data updates chain smoothly instead of jumping.
class CountUpBalance extends StatefulWidget {
  const CountUpBalance({
    super.key,
    required this.amount,
    required this.hidden,
    this.style,
  });

  final int amount;
  final bool hidden;
  final TextStyle? style;

  @override
  State<CountUpBalance> createState() => _CountUpBalanceState();
}

class _CountUpBalanceState extends State<CountUpBalance> {
  late int _from = widget.hidden ? 0 : widget.amount;
  late int _latest = _from;
  var _toggled = false;

  @override
  void didUpdateWidget(covariant CountUpBalance oldWidget) {
    super.didUpdateWidget(oldWidget);
    final toggled = oldWidget.hidden != widget.hidden;
    if (toggled || oldWidget.amount != widget.amount) {
      _from = _latest;
      _toggled = toggled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.hidden ? 0 : widget.amount;
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: _from, end: target),
      // The privacy toggle is a micro-interaction (fast); data changes
      // are emphasis moments (slow), matching the motion spec.
      duration: _toggled ? AppMotion.fast : AppMotion.slow,
      curve: AppMotion.enter,
      builder: (context, value, _) {
        _latest = value;
        final masked = widget.hidden && value == 0;
        return Text(
          masked
              ? '${currentCurrency.symbol} ••••••••'
              : formatMoney(value),
          style: widget.style,
        );
      },
      onEnd: () {
        _from = target;
        _toggled = false;
      },
    );
  }
}
