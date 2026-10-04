import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/amount_text.dart';

/// Date group header: big day number, weekday + month/year, and the day's
/// net total. Shared by the transaction history and wallet screens.
class DateGroupHeader extends StatelessWidget {
  const DateGroupHeader({
    super.key,
    required this.day,
    required this.net,
  });

  final DateTime day;
  final int net;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            day.day.toString().padLeft(2, '0'),
            style: const TextStyle(
                fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE').format(day),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                DateFormat('MMM yyyy').format(day),
                style: TextStyle(
                    fontSize: 12, color: context.textMuted),
              ),
            ],
          ),
          const Spacer(),
          net == 0
              ? Text(formatMoney(0),
                  style: AppTextStyles.amount(size: 15)
                      .copyWith(color: context.textMuted))
              : AmountText(net.abs(), isIncome: net > 0, size: 15),
        ],
      ),
    );
  }
}
