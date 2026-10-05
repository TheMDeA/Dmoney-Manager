import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_accents.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/database/app_database.dart';
import '../../../state/providers.dart';

/// Collapsible AI insight zone — data-driven. Each session shows 3 randomly
/// picked insights drawn from every eligible type (up to thirteen), cycling
/// every few seconds with a cross-fade, so the card stays alive without
/// competing with the balance or transactions for priority.
///
/// The cycle pauses while the card is expanded so text never changes
/// mid-read, and the dots are tappable shortcuts to each insight.
class AiInsightCard extends ConsumerStatefulWidget {
  const AiInsightCard({super.key});

  @override
  ConsumerState<AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends ConsumerState<AiInsightCard> {
  bool _expanded = false;
  int _index = 0;
  Timer? _cycle;
  Timer? _refresh;
  final _rng = Random();

  /// Insights chosen for this session (max 3, randomly picked).
  List<(String, String)> _sessionInsights = const [];

  /// Latest full eligible set, for the periodic re-pick.
  List<(String, String)> _latestEligible = const [];

  /// Headline key of the last eligible set — the session re-picks whenever
  /// the eligible set itself changes (e.g. first data arrival).
  String _lastEligibleKey = '';
  bool _pendingRepick = false;

  // Memoized eligible set: the 6-second cycle ticks must not rescan the
  // whole transaction table — only genuine data changes recompute.
  List<TransactionWithDetails>? _lastAll;
  List<(String, String)> _eligibleCache = const [];

  @override
  void initState() {
    super.initState();
    // Re-pick the session's 3 insights every 10 minutes so a long-lived
    // home screen still feels fresh. Skipped while expanded so the text
    // never changes mid-read.
    _refresh = Timer.periodic(const Duration(minutes: 10), (_) {
      if (!mounted || _expanded || _latestEligible.isEmpty) return;
      setState(_pickSession);
    });
  }

  @override
  void dispose() {
    _cycle?.cancel();
    _refresh?.cancel();
    super.dispose();
  }

  /// Randomly picks up to 3 insights for this session from the eligible set.
  void _pickSession() {
    final pool = [..._latestEligible]..shuffle(_rng);
    _sessionInsights = pool.take(3).toList();
    _index = 0;
  }

  List<(String, String)> _eligibleInsights(List<TransactionWithDetails> all) {
    if (!identical(all, _lastAll)) {
      _lastAll = all;
      _eligibleCache = _computeInsights(all);
    }
    return _eligibleCache;
  }

  void _maybeStartCycle(int count) {
    if (count < 2 || _expanded) {
      _cycle?.cancel();
      _cycle = null;
      return;
    }
    _cycle ??= Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || _expanded) return;
      setState(() => _index++);
    });
  }

  void _restartCycle() {
    _cycle?.cancel();
    _cycle = null;
    _maybeStartCycle(_sessionInsights.length);
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final accountId = ref.watch(selectedAccountProvider);
    return StreamBuilder<List<TransactionWithDetails>>(
      stream: db.watchTransactions(accountId: accountId),
      builder: (context, snap) {
        final all = snap.data ?? const <TransactionWithDetails>[];
        final eligible = _eligibleInsights(all);
        _latestEligible = eligible;
        final key = eligible.map((e) => e.$1).join('|');
        if (key != _lastEligibleKey) {
          _lastEligibleKey = key;
          if (_expanded) {
            // Never yank the text mid-read; re-pick on collapse instead.
            _pendingRepick = true;
          } else if (eligible.isNotEmpty) {
            _pickSession();
          } else {
            _sessionInsights = const [];
          }
        }
        if (_sessionInsights.isEmpty) return const SizedBox.shrink();
        _maybeStartCycle(_sessionInsights.length);
        final insight = _sessionInsights[_index % _sessionInsights.length];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            decoration: BoxDecoration(
              color: context.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.accent.withValues(alpha: 0.25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Haptics.select();
                    setState(() {
                      _expanded = !_expanded;
                      if (!_expanded && _pendingRepick) {
                        _pendingRepick = false;
                        _pickSession();
                      }
                    });
                  },
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      _sessionInsights.length > 1 ? 6 : 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_outlined,
                              size: 18,
                              color: context.accent,
                            ),
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
                                            end: Offset.zero,
                                          ).chain(
                                            CurveTween(curve: AppMotion.enter),
                                          ),
                                        ),
                                        child: child,
                                      ),
                                    ),
                                child: Text(
                                  insight.$1,
                                  key: ValueKey(insight.$1),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
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
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Dots live outside the InkWell so tapping one never
                // toggles expand/collapse.
                if (_sessionInsights.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _sessionInsights.length; i++)
                          GestureDetector(
                            key: ValueKey('insight_dot_$i'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              Haptics.select();
                              setState(() => _index = i);
                              _restartCycle();
                            },
                            // Generous hit area around the tiny dot.
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 8,
                              ),
                              child: AnimatedContainer(
                                duration: AppMotion.fast,
                                width: i == _index % _sessionInsights.length
                                    ? 16
                                    : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: i == _index % _sessionInsights.length
                                      ? context.accent
                                      : context.accent.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Returns up to thirteen (headline, detail) insights, or empty when there
  /// is nothing to say. Each insight appears only when its data is
  /// meaningful, so the eligible set varies with the user's history.
  List<(String, String)> _computeInsights(List<TransactionWithDetails> all) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    final monthAgo = DateTime(now.year, now.month - 1, now.day);

    final thisWeek = <int, int>{};
    final lastWeek = <int, int>{};
    final thisMonth = <int, int>{};
    final names = <int, String>{};
    final debtCats = <int>{};
    for (final d in all) {
      final t = d.transaction;
      if (t.kind != 'expense') continue;
      names[t.categoryId] = d.category.name;
      if (d.category.kind == 'debt') debtCats.add(t.categoryId);
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
    int? topCatId;
    double topRise = 0;
    for (final e in thisWeek.entries) {
      final prev = lastWeek[e.key] ?? 0;
      final rise = prev == 0
          ? (e.value > 0 ? 1.0 : 0.0)
          : (e.value - prev) / prev;
      if (rise > topRise && e.value >= 50000) {
        topRise = rise;
        topCatId = e.key;
      }
    }
    if (topCatId != null) {
      final topCat = names[topCatId] ?? 'Unknown';
      final pct = (topRise * 100).toStringAsFixed(0);
      final spent = formatMoney(
        thisWeek.entries.firstWhere((e) => names[e.key] == topCat).value,
      );
      // Debt repayments aren't "spending" — phrase them correctly.
      if (debtCats.contains(topCatId)) {
        out.add((
          '$topCat repayments are $pct% higher than last week.',
          'You repaid $spent on $topCat debt in the last 7 days.',
        ));
      } else {
        out.add((
          '$topCat spending is $pct% higher than last week.',
          'You spent $spent on $topCat in the last 7 days. Small cuts here compound fast.',
        ));
      }
    }

    // 2. Biggest category this month.
    if (thisMonth.isNotEmpty) {
      final biggest = thisMonth.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
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

    // ---- newer insight types (4-13) ----

    // Extra aggregates shared by the newer insights.
    final today = DateTime(now.year, now.month, now.day);
    final twoMonthsAgo = DateTime(now.year, now.month - 2, now.day);
    var monthTotal = 0, prevMonthTotal = 0, incomeTotal = 0;
    var weekendTotal = 0, weekdayTotal = 0;
    var cashTotal = 0, cashlessTotal = 0;
    var lateTotal = 0, lateCount = 0;
    var smallTotal = 0, smallCount = 0;
    final merchTotals = <String, int>{};
    final merchCounts = <String, int>{};
    final spendDays = <DateTime>{};
    final dowTotals = List.filled(8, 0);
    Transaction? biggestTx;
    for (final d in all) {
      final t = d.transaction;
      if (t.kind == 'income') {
        if (!t.date.isBefore(monthAgo)) incomeTotal += t.amount;
        continue;
      }
      if (t.kind != 'expense') continue;
      if (t.date.isBefore(monthAgo)) {
        if (!t.date.isBefore(twoMonthsAgo)) prevMonthTotal += t.amount;
        continue;
      }
      monthTotal += t.amount;
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      spendDays.add(day);
      final wd = t.date.weekday;
      dowTotals[wd] += t.amount;
      if (wd == DateTime.saturday || wd == DateTime.sunday) {
        weekendTotal += t.amount;
      } else {
        weekdayTotal += t.amount;
      }
      if (d.wallet.kind == 'cash') {
        cashTotal += t.amount;
      } else {
        cashlessTotal += t.amount;
      }
      if (t.date.hour >= 22) {
        lateTotal += t.amount;
        lateCount++;
      }
      if (biggestTx == null || t.amount > biggestTx.amount) biggestTx = t;
      final note = t.note.trim();
      if (note.isNotEmpty) {
        merchTotals[note] = (merchTotals[note] ?? 0) + t.amount;
        merchCounts[note] = (merchCounts[note] ?? 0) + 1;
      }
      if (!t.date.isBefore(weekAgo) && t.amount < 50000) {
        smallTotal += t.amount;
        smallCount++;
      }
    }

    // 4. Top merchant (by description) this month.
    if (merchTotals.isNotEmpty) {
      final top = merchTotals.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      final count = merchCounts[top.key] ?? 1;
      out.add((
        '${top.key} is your top merchant this month.',
        '${formatMoney(top.value)} across $count '
            '${count == 1 ? 'visit' : 'visits'} · '
            '${formatMoney(top.value ~/ count)} on average.',
      ));
    }

    // 5. Month-over-month spending change.
    if (prevMonthTotal > 0 && monthTotal > 0) {
      final pct = ((monthTotal - prevMonthTotal) / prevMonthTotal * 100)
          .round();
      final prevName = DateFormat(
        'MMMM',
      ).format(DateTime(now.year, now.month - 1));
      if (pct <= -5) {
        out.add((
          'Spending is ${-pct}% lower than last month.',
          '${formatMoney(monthTotal)} vs ${formatMoney(prevMonthTotal)} '
              'in $prevName. Keep it going.',
        ));
      } else if (pct >= 5) {
        out.add((
          'Spending is $pct% higher than last month.',
          '${formatMoney(monthTotal)} vs ${formatMoney(prevMonthTotal)} '
              'in $prevName. Worth a glance.',
        ));
      }
    }

    // 6. No-spend streak (capped at the 30-day window; needs some history
    // so a fresh database doesn't claim a "streak").
    var streak = 0;
    var cursor = today;
    while (!spendDays.contains(cursor) && streak < 30) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    if (streak >= 1 && monthTotal + prevMonthTotal > 0) {
      var longest = 0, run = 0;
      for (var i = 29; i >= 0; i--) {
        final d = today.subtract(Duration(days: i));
        if (spendDays.contains(d)) {
          run = 0;
        } else {
          run++;
          if (run > longest) longest = run;
        }
      }
      out.add((
        streak == 1
            ? '1 day without spending.'
            : '$streak days without spending.',
        'Your longest no-spend streak this month: $longest days. '
            'Every quiet day is money kept.',
      ));
    }

    // 7. Weekend vs weekday skew.
    var weekendDays = 0, weekdayDays = 0;
    for (var i = 0; i < 30; i++) {
      final d = today.subtract(Duration(days: i));
      if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
        weekendDays++;
      } else {
        weekdayDays++;
      }
    }
    if (weekendDays > 0 &&
        weekdayDays > 0 &&
        weekdayTotal > 0 &&
        weekendTotal > 0) {
      final ratio = (weekendTotal / weekendDays) / (weekdayTotal / weekdayDays);
      if (ratio >= 1.5) {
        out.add((
          'Weekends cost you ${ratio.toStringAsFixed(1)}× weekdays.',
          '${formatMoney((weekendTotal / weekendDays).round())} per weekend day '
              'vs ${formatMoney((weekdayTotal / weekdayDays).round())} on weekdays.',
        ));
      }
    }

    // 8. Savings rate.
    if (incomeTotal > 0 && incomeTotal > monthTotal) {
      final saved = incomeTotal - monthTotal;
      final pct = (saved / incomeTotal * 100).round();
      out.add((
        'You kept $pct% of what you earned.',
        '${formatMoney(saved)} saved in the last 30 days — income minus spending.',
      ));
    }

    // 9. Cash vs cashless share.
    final spendTotal = cashTotal + cashlessTotal;
    if (spendTotal > 0) {
      final pct = (cashlessTotal / spendTotal * 100).round();
      if (pct >= 60) {
        out.add((
          '$pct% of your spending is cashless.',
          '${formatMoney(cashlessTotal)} via bank & e-wallet vs '
              '${formatMoney(cashTotal)} in cash.',
        ));
      } else if (pct <= 40) {
        out.add((
          '${100 - pct}% of your spending is cash.',
          '${formatMoney(cashTotal)} in cash vs '
              '${formatMoney(cashlessTotal)} via bank & e-wallet.',
        ));
      }
    }

    // 10. Biggest single transaction this month.
    final big = biggestTx;
    if (big != null && monthTotal > 0) {
      final share = (big.amount / monthTotal * 100).round();
      final label = big.note.trim().isNotEmpty ? big.note.trim() : 'Unknown';
      out.add((
        'Biggest hit this month: ${formatMoney(big.amount)}.',
        '$label on ${DateFormat('MMM d').format(big.date)} — one transaction, '
            '$share% of the month.',
      ));
    }

    // 11. Late-night spending.
    if (lateCount >= 3) {
      out.add((
        '${formatMoney(lateTotal)} spent after 10 PM.',
        '$lateCount late-night transactions in the last 30 days. '
            'Tired you spends more.',
      ));
    }

    // 12. Biggest spending weekday.
    const dowNames = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dowCounts = List.filled(8, 0);
    for (var i = 0; i < 30; i++) {
      dowCounts[today.subtract(Duration(days: i)).weekday]++;
    }
    final overallDaily = monthTotal / 30;
    var bestWd = 0;
    var bestAvg = 0.0;
    for (var w = 1; w <= 7; w++) {
      if (dowCounts[w] == 0) continue;
      final avg = dowTotals[w] / dowCounts[w];
      if (avg > bestAvg) {
        bestAvg = avg;
        bestWd = w;
      }
    }
    if (bestWd > 0 && overallDaily > 0 && bestAvg >= overallDaily * 1.5) {
      out.add((
        'Your biggest spending day: ${dowNames[bestWd]}s.',
        '${formatMoney(bestAvg.round())} on average every ${dowNames[bestWd]}.',
      ));
    }

    // 13. Small leaks.
    if (smallCount >= 5) {
      out.add((
        'Small leaks: ${formatMoney(smallTotal)}.',
        '$smallCount purchases under ${formatMoney(50000)} this week. '
            'They add up quietly.',
      ));
    }

    if (out.isEmpty) return const [];
    return out;
  }
}
