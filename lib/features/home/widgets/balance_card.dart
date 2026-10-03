import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../data/database/app_database.dart';
import '../../../state/providers.dart';

/// Hero total-balance card with privacy toggle and period income/expense.
class BalanceCard extends ConsumerWidget {
  const BalanceCard({super.key, required this.balanceHidden, required this.onToggleHidden});

  final bool balanceHidden;
  final VoidCallback onToggleHidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final range = ref.watch(dateRangeProvider);

    return GlassCard(
      child: StreamBuilder<List<Wallet>>(
        stream: db.watchWallets(),
        builder: (context, walletsSnap) {
          final wallets = walletsSnap.data ?? const <Wallet>[];
          final total = wallets.fold<int>(0, (s, w) => s + w.balance);
          final (from, to) = _rangeBounds(range);
          return StreamBuilder<List<KindTotal>>(
            stream: db.watchKindTotals(from, to),
            builder: (context, txSnap) {
              final totals = {
                for (final t in (txSnap.data ?? const <KindTotal>[]))
                  t.kind: t.total,
              };
              final income = totals['income'] ?? 0;
              final expense = totals['expense'] ?? 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total balance',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: context.textMuted)),
                      IconButton(
                        onPressed: onToggleHidden,
                        icon: Icon(
                          balanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    balanceHidden ? 'Rp ••••••••' : formatMoney(total),
                    style: AppTextStyles.displayBalance.copyWith(color: context.textPrimary),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _flow(context, 'Income', income, true),
                      ),
                      Container(width: 1, height: 36, color: context.hairline),
                      Expanded(
                        child: _flow(context, 'Expenses', expense, false),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _flow(BuildContext context, String label, int amount, bool isIncome) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                size: 14,
                color: isIncome ? AppColors.income : AppColors.expense,
              ),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: context.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatSignedMoney(amount, isIncome: isIncome),
            style: AppTextStyles.amount(size: 16).copyWith(
              color: isIncome ? AppColors.income : AppColors.expense,
            ),
          ),
        ],
      ),
    );
  }

  (DateTime, DateTime) _rangeBounds(String range) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (range) {
      case 'day':
        return (DateTime(now.year, now.month, now.day), end);
      case 'week':
        return (end.subtract(const Duration(days: 7)), end);
      default:
        return (end.subtract(const Duration(days: 30)), end);
    }
  }
}
