import 'package:flutter/material.dart';

import '../utils/formatters.dart';

/// Amount input with an always-visible currency symbol.
///
/// Unlike [InputDecoration.prefixText] (which doesn't render while the
/// field is empty and unfocused), the symbol is a permanent label, so
/// the user always knows which currency they're entering.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.style,
    this.hintText = '0',
    this.autofocus = false,
  });

  final TextEditingController controller;
  final TextStyle? style;
  final String hintText;
  final bool autofocus;

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
      ],
    );
  }
}
