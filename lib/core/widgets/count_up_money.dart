import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../utils/formatters.dart';

/// Money amount that counts up/down to its new value whenever [amount]
/// changes, instead of jumping. Tabular figures (from the style) keep the
/// digits from jittering mid-tween.
///
/// [format] renders each intermediate value; defaults to [formatMoney].
/// Pass a custom formatter for signed/prefixed displays, e.g.
/// `(v) => '-${formatMoney(v)}'`.
class CountUpMoney extends StatefulWidget {
  const CountUpMoney({
    super.key,
    required this.amount,
    this.style,
    this.format = formatMoney,
  });

  final int amount;
  final TextStyle? style;
  final String Function(int) format;

  @override
  State<CountUpMoney> createState() => _CountUpMoneyState();
}

class _CountUpMoneyState extends State<CountUpMoney> {
  late int _from = widget.amount;
  late int _latest = widget.amount;

  @override
  void didUpdateWidget(covariant CountUpMoney oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Retarget from wherever the animation currently is, so rapid
    // successive changes chain smoothly instead of jumping.
    if (oldWidget.amount != widget.amount) _from = _latest;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: _from, end: widget.amount),
      duration: AppMotion.slow,
      curve: AppMotion.enter,
      builder: (context, value, _) {
        _latest = value;
        return Text(widget.format(value), style: widget.style);
      },
      onEnd: () => _from = widget.amount,
    );
  }
}
