import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/database/app_database.dart';
import '../../../state/providers.dart';

/// Collapsible AI insight zone — data-driven. Cycles through up to three
/// insights every few seconds with a cross-fade, so the card stays alive
/// without competing with the balance or transactions for priority.
class AiInsightCard extends ConsumerStatefulWidget {
  const AiInsightCard({super.key});

  @override
  ConsumerState<AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends ConsumerState<AiInsightCard> {
  bool _expanded = false;
  int _index = 0;
  Timer? _cycle;

  @override
  void dispose() {
    _cycle?.cancel();
    super.dispose();
  }

  void _maybeStartCycle(int count) {
    if (count < 2) {
      _cycle?.cancel();
      _cycle = null;
      return;
    }
    _cycle ??= Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      setState(() => _index++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<TransactionWithDetails>>(
      stream: db.watchTransactions(),
      builder: (context, snap) {
        final all = snap.data ?? const <TransactionWithDetails>[];
        final insights = _computeInsights(all);
        if (insights.isEmpty) return const SizedBox.shrink();
        _maybeStartCycle(insights.length);
        final insight = insights[_index % insights.length];
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
                          child: AnimatedSwitcher(
                            duration: AppMotion.normal,
                            switchInCurve: AppMotion.enter,
                            switchOutCurve: AppMotion.exit,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: animation.drive(
                                  Tween(
                                          begin: const Offset(0, 0.35),
                                          end: Offset.zero)
                                      .chain(CurveTween(
                                          curve: AppMotion.enter)),
                                ),
                                child: child,
                              ),
                            ),
                            child: Text(
                              insight.$1,
                              key: ValueKey(insight.$1),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: context.textMuted,
                        ),
                      ],
                    ),
                    if (_expanded) ...[
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: AppMotion.normal,
                        child: Text(
                          insight.$2,
                          key: ValueKey(insight.$2),
                          style: TextStyle(
                              fontSize: 13,
                              color: context.textMuted,
                              height: 1.5),
                        ),
                      ),
                    ],
                    if (insights.length > 1) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < insights.length; i++)
                            AnimatedContainer(
                              duration: AppMotion.fast,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _index % insights.length ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: i == _index % insights.length
                                    ? AppColors.violet
                                    : AppColors.violet
                                        .withValues(alpha: 0.3),
                              ),
                            ),
                        ],
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

  /// Returns up to three (headline, detail) insights, or empty when there is
  /// nothing to say.
  List<(String, String)> _computeInsights(List<TransactionWithDetails> all) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    final monthAgo = DateTime(now.year, now.month - 1, now.day);

    final thisWeek = <int, int>{};
    final lastWeek = <int, int>{};
    final thisMonth = <int, int>{};
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
      if (!t.date.isBefore(monthAgo)) {
        thisMonth[t.categoryId] = (thisMonth[t.categoryId] ?? 0) + t.amount;
      }
    }
    final out = <(String, String)>[];

    // 1. Fastest-rising category vs last week.
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
    if (topCat != null) {
      final pct = (topRise * 100).toStringAsFixed(0);
      final spent = formatMoney(thisWeek.entries
          .firstWhere((e) => names[e.key] == topCat)
          .value);
      out.add((
        '$topCat spending is $pct% higher than last week.',
        'You spent $spent on $topCat in the last 7 days. Small cuts here compound fast.',
      ));
    }

    // 2. Biggest category this month.
    if (thisMonth.isNotEmpty) {
      final biggest =
          thisMonth.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final name = names[biggest.key] ?? 'Unknown';
      out.add((
        '$name leads your spending this month.',
        '${formatMoney(biggest.value)} on $name in the last 30 days.',
      ));
    }

    // 3. Daily pace this week.
    final weekTotal = thisWeek.values.fold<int>(0, (s, v) => s + v);
    if (weekTotal > 0) {
      final pace = weekTotal ~/ 7;
      out.add((
        'You\'re spending about ${formatMoney(pace)} a day.',
        '${formatMoney(weekTotal)} total in the last 7 days.',
      ));
    }

    if (out.isEmpty) return const [];
    return out.take(3).toList();
  }
}
