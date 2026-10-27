import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';

/// Money amount rendered with tabular numerals and an explicit sign.
/// Color is decorative only — the +/- sign carries the meaning.
/// [hidden] masks the figure with dots (privacy mode); transaction
/// rows leave it false, aggregate sites pass the global flag.
class AmountText extends StatelessWidget {
  const AmountText(
    this.amount, {
    super.key,
    required this.isIncome,
    this.size = 16,
    this.weight = FontWeight.w600,
    this.showSign = true,
    this.hidden = false,
  });

  final int amount;
  final bool isIncome;
  final double size;
  final FontWeight weight;
  final bool showSign;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final text = showSign
        ? formatSignedMoney(amount, isIncome: isIncome)
        : formatMoney(amount);
    return Text(
      hidden ? maskMoneyText(text) : text,
      style: AppTextStyles.amount(size: size, weight: weight).copyWith(
        color: isIncome ? AppColors.income : AppColors.expense,
      ),
    );
  }
}
