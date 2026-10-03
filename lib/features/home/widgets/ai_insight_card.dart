import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';
import '../../../state/providers.dart';

/// Collapsible AI insight zone — data-driven: spots the category whose
/// spending rose the most versus last week. Kept visually quiet so it never
/// competes with the balance or transactions for priority.
class AiInsightCard extends ConsumerStatefulWidget {
  const AiInsightCard({super.key});

  @override
  ConsumerState<AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends ConsumerState<AiInsightCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<TransactionWithDetails>>(
      stream: db.watchTransactions(),
      builder: (context, snap) {
        final all = snap.data ?? const <TransactionWithDetails>[];
        final insight = _computeInsight(all);
        if (insight == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppColors.violet.withValues(alpha: 0.25)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_outlined,
                            size: 18, color: AppColors.violet),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            insight.$1,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                    if (_expanded) ...[
                      const SizedBox(height: 8),
                      Text(
                        insight.$2,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            height: 1.5),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Returns (headline, detail) or null when there is nothing to say.
  (String, String)? _computeInsight(List<TransactionWithDetails> all) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

    final thisWeek = <int, int>{};
    final lastWeek = <int, int>{};
    final names = <int, String>{};
    for (final d in all) {
      final t = d.transaction;
      if (t.kind != 'expense') continue;
      names[t.categoryId] = d.category.name;
      if (!t.date.isBefore(weekAgo)) {
        thisWeek[t.categoryId] = (thisWeek[t.categoryId] ?? 0) + t.amount;
      } else if (!t.date.isBefore(twoWeeksAgo)) {
        lastWeek[t.categoryId] = (lastWeek[t.categoryId] ?? 0) + t.amount;
      }
    }
    String? topCat;
    double topRise = 0;
    for (final e in thisWeek.entries) {
      final prev = lastWeek[e.key] ?? 0;
      final rise =
          prev == 0 ? (e.value > 0 ? 1.0 : 0.0) : (e.value - prev) / prev;
      if (rise > topRise && e.value >= 50000) {
        topRise = rise;
        topCat = names[e.key];
      }
    }
    if (topCat == null) {
      final total = thisWeek.values.fold<int>(0, (s, v) => s + v);
      if (total == 0) return null;
      return (
        'Spending is steady this week.',
        'You spent ${formatMoney(total)} in the last 7 days — nicely under control.'
      );
    }
    final pct = (topRise * 100).toStringAsFixed(0);
    final spent = formatMoney(thisWeek.entries
        .firstWhere((e) => names[e.key] == topCat)
        .value);
    return (
      '$topCat spending is $pct% higher than last week.',
      'You spent $spent on $topCat in the last 7 days. Small cuts here compound fast.',
    );
  }
}
