import 'package:flutter/material.dart';

import '../theme/app_accents.dart';
import '../theme/app_colors.dart';
import '../utils/expression.dart';
import '../utils/formatters.dart';
import '../utils/haptics.dart';

/// Shows the calculator and completes with the chosen integer amount,
/// or `null` when dismissed.
Future<int?> showCalculatorSheet(BuildContext context,
    {int initialValue = 0}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (_) => CalculatorSheet(initialValue: initialValue),
  );
}

/// Mini calculator keypad: builds an arithmetic expression with a live
/// result preview. "=" pops the sheet with the rounded integer result.
class CalculatorSheet extends StatefulWidget {
  const CalculatorSheet({super.key, this.initialValue = 0});

  final int initialValue;

  @override
  State<CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<CalculatorSheet> {
  var _expr = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialValue > 0) {
      _expr = widget.initialValue.toString();
    }
  }

  double? get _result =>
      _expr.isEmpty ? null : evaluateExpression(_expr);

  bool _isOp(String c) => c == '+' || c == '-' || c == '*' || c == '/';

  void _input(String key) {
    setState(() {
      switch (key) {
        case 'C':
          _expr = '';
        case 'back':
          if (_expr.isNotEmpty) {
            _expr = _expr.substring(0, _expr.length - 1);
          }
        case '(':
          if (_expr.isEmpty ||
              _isOp(_expr[_expr.length - 1]) ||
              _expr[_expr.length - 1] == '(') {
            _expr += '(';
          }
        case ')':
          final open = '('.allMatches(_expr).length;
          final close = ')'.allMatches(_expr).length;
          if (open > close &&
              _expr.isNotEmpty &&
              !_isOp(_expr[_expr.length - 1]) &&
              _expr[_expr.length - 1] != '(') {
            _expr += ')';
          }
        case '.':
          // One dot per number segment.
          final seg = _expr.split(RegExp(r'[+\-*/()]')).last;
          if (!seg.contains('.')) {
            _expr += _expr.isEmpty || _isOp(_expr[_expr.length - 1]) ||
                    _expr[_expr.length - 1] == '('
                ? '0.'
                : '.';
          }
        case '+':
        case '-':
        case '*':
        case '/':
          if (_expr.isEmpty) {
            if (key == '-') _expr = '-'; // allow leading unary minus
          } else if (_isOp(_expr[_expr.length - 1])) {
            // Replace a trailing operator, but allow '(-' style sequences.
            if (key == '-' && _expr[_expr.length - 1] != '-') {
              _expr += '-';
            } else {
              _expr =
                  '${_expr.substring(0, _expr.length - 1)}$key';
            }
          } else if (_expr[_expr.length - 1] != '(') {
            _expr += key;
          } else if (key == '-') {
            _expr += '-';
          }
        default: // digits
          _expr += key;
      }
    });
  }

  void _apply() {
    final r = _result;
    if (r == null) return;
    Navigator.of(context).pop(r.round());
  }

  String _pretty(String expr) => expr
      .replaceAll('*', '×')
      .replaceAll('/', '÷')
      .replaceAll('-', '−');

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            // Expression + live result.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.raised,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _pretty(_expr.isEmpty ? '0' : _expr),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      color: context.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result == null
                        ? '—'
                        : '= ${formatAmountInput(result.round())}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: result == null
                          ? context.textMuted
                          : context.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _row(['C', '(', ')', '÷'], isOpKey: (k) => k != 'C'),
            _row(['7', '8', '9', '×']),
            _row(['4', '5', '6', '−']),
            _row(['1', '2', '3', '+']),
            _row(['0', '.', 'back', '=']),
          ],
        ),
      ),
    );
  }

  Widget _row(List<String> keys, {bool Function(String)? isOpKey}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _key(keys[i], isOpKey: isOpKey)),
          ],
        ],
      ),
    );
  }

  Widget _key(String key, {bool Function(String)? isOpKey}) {
    final onAccentColor = onAccent(context.accent);
    final opKey = (isOpKey?.call(key) ?? false) ||
        key == '×' ||
        key == '÷' ||
        key == '−' ||
        key == '+' ||
        key == '=';
    final danger = key == 'C';
    Widget label;
    if (key == 'back') {
      label = const Icon(Icons.backspace_outlined, size: 22);
    } else {
      label = Text(
        key,
        style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w600),
      );
    }
    return Material(
      color: key == '='
          ? context.accent
          : danger
              ? AppColors.expense.withValues(alpha: 0.14)
              : context.raised,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Haptics.select();
          if (key == '=') {
            _apply();
          } else {
            _input(switch (key) {
              '×' => '*',
              '÷' => '/',
              '−' => '-',
              _ => key,
            });
          }
        },
        child: Container(
          height: 56,
          alignment: Alignment.center,
          child: key == '='
              ? Theme(
                  data: Theme.of(context).copyWith(
                    iconTheme: IconThemeData(
                        color: onAccentColor, size: 22),
                  ),
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: onAccentColor,
                    ),
                    child: label,
                  ),
                )
              : IconTheme(
                  data: IconThemeData(
                    color: danger
                        ? AppColors.expense
                        : opKey
                            ? context.accent
                            : context.textPrimary,
                  ),
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: danger
                          ? AppColors.expense
                          : opKey
                              ? context.accent
                              : context.textPrimary,
                    ),
                    child: label,
                  ),
                ),
        ),
      ),
    );
  }
}
