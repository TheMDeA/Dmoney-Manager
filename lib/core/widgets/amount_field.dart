import 'package:flutter/material.dart';

import '../utils/formatters.dart';
import 'calculator_sheet.dart';

/// Amount input with an always-visible currency symbol.
///
/// Unlike [InputDecoration.prefixText] (which doesn't render while the
/// field is empty and unfocused), the symbol is a permanent label, so
/// the user always knows which currency they're entering.
///
/// A small calculator button opens an expression keypad
/// (`12000+3500`) and writes the evaluated result back into the field.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.style,
    this.hintText = '0',
    this.autofocus = false,
    this.showCalculator = true,
  });

  final TextEditingController controller;
  final TextStyle? style;
  final String hintText;
  final bool autofocus;

  /// Whether to show the calculator shortcut button. Disable it where
  /// an expression makes no sense (there currently is no such place,
  /// the flag exists for future call sites).
  final bool showCalculator;

  Future<void> _openCalculator(BuildContext context) async {
    final result = await showCalculatorSheet(
      context,
      initialValue: parseAmountInput(controller.text),
    );
    if (result == null || !context.mounted) return;
    controller.text = formatAmountInput(result);
    controller.selection =
        TextSelection.collapsed(offset: controller.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final textStyle =
        style ?? Theme.of(context).textTheme.titleLarge;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(currencyFieldPrefix.trim(), style: textStyle),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsSeparatorInputFormatter()],
            style: textStyle,
            decoration: InputDecoration(
              hintText: hintText,
              border: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (showCalculator)
          IconButton(
            tooltip: 'Calculator',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.calculate_outlined, size: 22),
            onPressed: () => _openCalculator(context),
          ),
      ],
    );
  }
}
