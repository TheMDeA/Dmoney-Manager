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
///
/// When [hidden] is true the digits count down to zero and land on a dot
/// mask (keeping the format's sign/currency prefix); revealing counts back
/// up. Mirrors [CountUpBalance]'s privacy toggle.
class CountUpMoney extends StatefulWidget {
  const CountUpMoney({
    super.key,
    required this.amount,
    this.style,
    this.format = formatMoney,
    this.maxLines,
    this.overflow,
    this.hidden = false,
  });

  final int amount;
  final TextStyle? style;
  final String Function(int) format;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool hidden;

  @override
  State<CountUpMoney> createState() => _CountUpMoneyState();
}

class _CountUpMoneyState extends State<CountUpMoney> {
  late int _from = widget.hidden ? 0 : widget.amount;
  late int _latest = _from;
  var _toggled = false;

  @override
  void didUpdateWidget(covariant CountUpMoney oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Retarget from wherever the animation currently is, so rapid
    // successive changes chain smoothly instead of jumping.
    final toggled = oldWidget.hidden != widget.hidden;
    if (toggled || oldWidget.amount != widget.amount) {
      _from = _latest;
      _toggled = toggled;
    }
  }

  /// Dot mask derived from the format: the trailing number becomes dots,
  /// keeping any sign/currency prefix (e.g. '+Rp ••••••••').
  String _maskText() =>
      widget.format(0).replaceAll(RegExp(r'[0-9.,]+$'), '••••••••');

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
          masked ? _maskText() : widget.format(value),
          style: widget.style,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
        );
      },
      onEnd: () {
        _from = target;
        _toggled = false;
      },
    );
  }
}
