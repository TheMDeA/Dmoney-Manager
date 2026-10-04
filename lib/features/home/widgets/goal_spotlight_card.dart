import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/database/app_database.dart';
import '../../../state/providers.dart';

/// Home savings-goal spotlight: first *incomplete* goal with a progress ring.
/// Completed goals stay visible in Budgets; the spotlight is for what's left.
class GoalSpotlightCard extends ConsumerWidget {
  const GoalSpotlightCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<Goal>>(
      stream: db.watchGoals(),
      builder: (context, snap) {
        final goals = (snap.data ?? const <Goal>[])
            .where((g) => g.saved < g.target)
            .toList();
        if (goals.isEmpty) return const SizedBox.shrink();
        final g = goals.first;
        final ratio =
            g.target == 0 ? 0.0 : (g.saved / g.target).clamp(0.0, 1.0);
        final color = colorFromHex(g.colorHex);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Pressable(
            child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => ref.read(tabIndexProvider.notifier).go(4),
            child: GlassCard(
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(
                            value: ratio,
                            strokeWidth: 7,
                            backgroundColor: context.hairline,
                            color: color,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Text('${(ratio * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Savings goal',
                            style: TextStyle(
                                color: context.textMuted, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(g.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          '${formatMoney(g.saved)} of ${formatMoney(g.target)}',
                          style: AppTextStyles.amount(size: 12)
                              .copyWith(color: context.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.textMuted),
                ],
              ),
            ),
            ),
          ),
        );
      },
    );
  }
}
