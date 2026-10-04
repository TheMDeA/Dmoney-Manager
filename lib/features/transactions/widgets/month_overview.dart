import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/amount_text.dart';

/// Income / expense / net overview for a month. Transfers stay neutral,
/// like everywhere else in the app.
class MonthOverview extends StatelessWidget {
  const MonthOverview({
    super.key,
    required this.income,
    required this.expense,
  });

  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    final total = income - expense;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          _row(
            context,
            'Income',
            Text(formatMoney(income),
                style: TextStyle(
                    color: AppColors.income,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
          const SizedBox(height: 6),
          _row(
            context,
            'Expense',
            Text('-${formatMoney(expense)}',
                style: TextStyle(
                    color: AppColors.expense,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
          const SizedBox(height: 6),
          _row(
            context,
            'Total',
            total == 0
                ? Text(formatMoney(0),
                    style: TextStyle(
                        color: context.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 15))
                : AmountText(total.abs(),
                    isIncome: total > 0, size: 15),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, Widget value) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                color: context.textMuted, fontSize: 14)),
        const Spacer(),
        value,
      ],
    );
  }
}
