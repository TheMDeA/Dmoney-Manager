import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_accents.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/count_up_balance.dart';
import '../../../core/widgets/count_up_money.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../data/database/app_database.dart';
import '../../../state/providers.dart';
import '../../stats/structure_screen.dart';

/// Hero total-balance card with privacy toggle and period income/expense.
///
/// Each flow column pairs its amount with a small sparkline on the right;
/// tapping a column drills into the Stats structure screen on the matching
/// tab, like the old standalone sparkline cards did.
class BalanceCard extends ConsumerWidget {
  const BalanceCard({
    super.key,
    required this.balanceHidden,
    required this.onToggleHidden,
  });

  final bool balanceHidden;
  final VoidCallback onToggleHidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final range = ref.watch(dateRangeProvider);
    final accountId = ref.watch(selectedAccountProvider);
    final now = DateTime.now();
    final drillMonth = DateTime(now.year, now.month);

    return GlassCard(
      glowColor: context.accent,
      child: StreamBuilder<List<Wallet>>(
        stream: db.watchWallets(accountId: accountId),
        builder: (context, walletsSnap) {
          final wallets = walletsSnap.data ?? const <Wallet>[];
          final total = wallets.fold<int>(0, (s, w) => s + w.balance);
          final (from, to) = _rangeBounds(range);
          return StreamBuilder<List<KindTotal>>(
            stream: db.watchKindTotals(from, to, accountId: accountId),
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
                      Text(
                        'Total balance',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.textMuted,
                        ),
                      ),
                      IconButton(
                        onPressed: onToggleHidden,
                        icon: Icon(
                          balanceHidden
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                  // The digits count down to the dot mask when hiding and
                  // count back up when revealing — no fade/swap.
                  // Tapping the balance jumps to the Stats tab.
                  InkWell(
                    onTap: () {
                      Haptics.select();
                      ref.read(tabIndexProvider.notifier).go(3);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: CountUpBalance(
                      amount: total,
                      hidden: balanceHidden,
                      style: AppTextStyles.displayBalance.copyWith(
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _flowCell(
                          context,
                          label: 'Income',
                          amount: income,
                          isIncome: true,
                          onTap: () => StructureScreen.open(
                            context,
                            month: drillMonth,
                            initialKind: 'income',
                          ),
                        ),
                      ),
                      Container(width: 1, height: 48, color: context.hairline),
                      Expanded(
                        child: _flowCell(
                          context,
                          label: 'Expense',
                          amount: expense,
                          isIncome: false,
                          onTap: () => StructureScreen.open(
                            context,
                            month: drillMonth,
                            initialKind: 'expense',
                          ),
                        ),
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

  /// Tappable income/expense column: label + amount.
  Widget _flowCell(
    BuildContext context, {
    required String label,
    required int amount,
    required bool isIncome,
    required VoidCallback onTap,
  }) {
    final color = isIncome ? AppColors.income : AppColors.expense;
    return InkWell(
      onTap: () {
        Haptics.select();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Counts up/down whenever the range (or data) changes, like the
            // total balance above — same size for income and expense.
            CountUpMoney(
              amount: amount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.amount(size: 16).copyWith(color: color),
              format: (v) => formatSignedMoney(v, isIncome: isIncome),
            ),
          ],
        ),
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
