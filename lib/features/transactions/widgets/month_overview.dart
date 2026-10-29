import 'package:flutter/material.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../state/providers.dart';

/// Income / expense / net overview for a month. Transfers stay neutral,
/// like everywhere else in the app.
class MonthOverview extends ConsumerWidget {
  const MonthOverview({
    super.key,
    required this.income,
    required this.expense,
  });

  final int income;
  final int expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hidden = ref.watch(balanceHiddenProvider);
    final total = income - expense;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.txOverview,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          _row(
            context,
            l10n.txIncome,
            Text(hidden ? maskMoneyText(formatMoney(income)) : formatMoney(income),
                style: AppTextStyles.amount(size: 15)
                    .copyWith(color: AppColors.income)),
          ),
          const SizedBox(height: 6),
          _row(
            context,
            l10n.txExpense,
            Text('-${hidden ? maskMoneyText(formatMoney(expense)) : formatMoney(expense)}',
                style: AppTextStyles.amount(size: 15)
                    .copyWith(color: AppColors.expense)),
          ),
          const SizedBox(height: 6),
          _row(
            context,
            l10n.txTotal,
            total == 0
                ? Text(hidden ? maskMoneyText(formatMoney(0)) : formatMoney(0),
                    style: AppTextStyles.amount(size: 15)
                        .copyWith(color: context.textMuted))
                : AmountText(total.abs(),
                    isIncome: total > 0, size: 15, hidden: hidden),
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
