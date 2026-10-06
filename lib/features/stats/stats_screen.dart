import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ambient_glow.dart';
import '../../core/widgets/screen_header.dart';
import '../../../core/theme/app_motion.dart';
import '../../core/theme/app_accents.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/count_up_money.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/app_page_route.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../transactions/transactions_screen.dart';
import 'structure_screen.dart';

/// Reports: expense donut, 6-month income/expense bars, net-savings trend.
/// All charts are live (driven by the transaction stream), tappable, and
/// animate on every data change.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  static const _animDuration = AppMotion.slow;
  static const _animCurve = Curves.easeOutCubic;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int _touchedDonutIndex = -1;
  int _netWorthRange = 6;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final accountId = ref.watch(selectedAccountProvider);
    final monthStart = DateTime(_month.year, _month.month);
    final monthEnd = DateTime(
      _month.year,
      _month.month + 1,
    ).subtract(const Duration(seconds: 1));
    final now = DateTime.now();
    final sixMonthStart = DateTime(now.year, now.month - 5);
    final sixMonthEnd = DateTime(
      now.year,
      now.month + 1,
    ).subtract(const Duration(seconds: 1));
    final prevStart = DateTime(_month.year, _month.month - 1);
    final prevEnd = monthStart.subtract(const Duration(seconds: 1));

    return Scaffold(
      body: AmbientGlow(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader(title: 'Stats', tabIndex: 3),
            Expanded(
              child: StreamBuilder<List<CategoryTotal>>(
                stream: db.watchCategoryExpenseTotals(
                  monthStart,
                  monthEnd,
                  accountId: accountId,
                ),
                builder: (context, donutSnap) {
                  if (!donutSnap.hasData) {
                    return const SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 96),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 160, height: 20),
                          SizedBox(height: 12),
                          SkeletonBox(height: 110, radius: 20),
                          SizedBox(height: 16),
                          SkeletonBox(width: 120, height: 18),
                          SizedBox(height: 12),
                          SkeletonBox(height: 220, radius: 20),
                        ],
                      ),
                    );
                  }
                  final donutTotals = donutSnap.data ?? const <CategoryTotal>[];
                  return StreamBuilder<List<MonthlyTotal>>(
                    stream: db.watchMonthlyKindTotals(
                      sixMonthStart,
                      sixMonthEnd,
                      accountId: accountId,
                    ),
                    builder: (context, monthlySnap) {
                      final monthlyTotals =
                          monthlySnap.data ?? const <MonthlyTotal>[];
                      return StreamBuilder<List<Category>>(
                        stream: db.watchCategories(),
                        builder: (context, catSnap) {
                          final cats = {
                            for (final c
                                in (catSnap.data ?? const <Category>[]))
                              c.id: c,
                          };
                          return StreamBuilder<List<CategoryTotal>>(
                            stream: db.watchCategoryExpenseTotals(
                              prevStart,
                              prevEnd,
                              accountId: accountId,
                            ),
                            builder: (context, prevSnap) {
                              final prevTotals =
                                  prevSnap.data ?? const <CategoryTotal>[];
                              return SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  96,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _monthSelector(context),
                                    _overviewSection(
                                      context,
                                      db,
                                      monthStart,
                                      monthEnd,
                                      accountId,
                                    ),
                                    const SectionHeader(title: 'Insights'),
                                    _insightsCard(
                                      context,
                                      donutTotals,
                                      prevTotals,
                                      cats,
                                    ),
                                    SectionHeader(
                                      title: 'Spending by category',
                                      action: TextButton(
                                        onPressed: () {
                                          Haptics.select();
                                          StructureScreen.open(
                                            context,
                                            month: _month,
                                          );
                                        },
                                        child: const Text('Show more'),
                                      ),
                                    ),
                                    _donut(context, donutTotals, cats),
                                    const SectionHeader(title: 'Last 6 months'),
                                    _bars(context, monthlyTotals),
                                    SectionHeader(title: 'Net savings trend'),
                                    _trendLine(context, monthlyTotals),
                                    SectionHeader(
                                      title: 'Net worth',
                                      action: _netWorthRangeChips(),
                                    ),
                                    _netWorthCard(context, db, accountId),
                                    SizedBox(height: 8),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthSelector(BuildContext context) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    void shift(int delta) => setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _touchedDonutIndex = -1;
    });
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {
            Haptics.select();
            shift(-1);
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          '${months[_month.month - 1]} ${_month.year}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        IconButton(
          onPressed: () {
            Haptics.select();
            shift(1);
          },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  /// Overview: opening/ending balance plus the month's income/expense/total,
  /// with a "Show more" link to the transaction history for the month.
  /// Opening/ending are derived from the current wallet total minus the
  /// net of later transactions (balance adjustments fold into the nearest
  /// month).
  Widget _overviewSection(
    BuildContext context,
    AppDatabase db,
    DateTime monthStart,
    DateTime monthEnd,
    int? accountId,
  ) {
    final afterStart = monthEnd.add(const Duration(seconds: 1));
    final now = DateTime.now();
    return StreamBuilder<List<Wallet>>(
      stream: db.watchWallets(accountId: accountId),
      builder: (context, wSnap) {
        final current = (wSnap.data ?? const <Wallet>[]).fold<int>(
          0,
          (s, w) => s + w.balance,
        );
        return StreamBuilder<List<KindTotal>>(
          stream: db.watchKindTotals(
            monthStart,
            monthEnd,
            accountId: accountId,
          ),
          builder: (context, mSnap) {
            final kinds = {
              for (final k in (mSnap.data ?? const <KindTotal>[]))
                k.kind: k.total,
            };
            final income = kinds['income'] ?? 0;
            final expense = kinds['expense'] ?? 0;
            final monthNet = income - expense;
            return StreamBuilder<List<KindTotal>>(
              stream: db.watchKindTotals(afterStart, now, accountId: accountId),
              builder: (context, aSnap) {
                final afterNet = _netOf(aSnap.data);
                final opening = current - monthNet - afterNet;
                final ending = current - afterNet;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Balance'),
                    Entrance(
                      child: GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: _balanceCell(
                                  context,
                                  'Opening balance',
                                  opening,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 44,
                                color: context.hairline,
                              ),
                              Expanded(
                                child: _balanceCell(
                                  context,
                                  'Ending balance',
                                  ending,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SectionHeader(title: 'Overview'),
                    Entrance(
                      delay: const Duration(milliseconds: 80),
                      child: GlassCard(
                        child: Column(
                          children: [
                            _overviewRow(
                              context,
                              'Income',
                              income,
                              AppColors.income,
                            ),
                            _overviewRow(
                              context,
                              'Expense',
                              expense,
                              AppColors.expense,
                              format: (v) => '-${formatMoney(v)}',
                            ),
                            _overviewRow(
                              context,
                              'Total',
                              income - expense,
                              null,
                            ),
                            Divider(height: 1, color: context.hairline),
                            InkWell(
                              onTap: () {
                                Haptics.select();
                                Navigator.of(context).push(
                                  AppPageRoute(
                                    builder: (_) => TransactionsScreen(
                                      initialMonth: _month,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Show more',
                                      style: TextStyle(
                                        color: context.textMuted,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.chevron_right,
                                      color: context.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  int _netOf(List<KindTotal>? rows) {
    var income = 0;
    var expense = 0;
    for (final r in rows ?? const <KindTotal>[]) {
      if (r.kind == 'income') income = r.total;
      if (r.kind == 'expense') expense = r.total;
    }
    return income - expense;
  }

  Widget _balanceCell(BuildContext context, String label, int amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        CountUpMoney(amount: amount, style: AppTextStyles.amount(size: 17)),
      ],
    );
  }

  Widget _overviewRow(
    BuildContext context,
    String label,
    int amount,
    Color? valueColor, {
    String Function(int) format = formatMoney,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          CountUpMoney(
            amount: amount,
            format: format,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  String _prevMonthLabel() {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final p = DateTime(_month.year, _month.month - 1);
    return '${names[p.month - 1]} ${p.year}';
  }

  // -------------------------------- insights --------------------------------

  /// Smart takeaways comparing the selected month against the previous
  /// one: biggest category, largest movers, and daily spending pace.
  /// Noise guards: a category must represent at least 3% of the month's
  /// spending, and movers need a >= 15% swing to be worth mentioning.
  List<({IconData icon, Color color, String title, String subtitle})>
  _buildInsights(
    BuildContext context,
    List<CategoryTotal> cur,
    List<CategoryTotal> prev,
    Map<int, Category> cats,
  ) {
    final insights =
        <({IconData icon, Color color, String title, String subtitle})>[];
    final curTotal = cur.fold<int>(0, (s, e) => s + e.total);
    if (curTotal == 0) return insights;
    final prevTotal = prev.fold<int>(0, (s, e) => s + e.total);
    final prevLabel = _prevMonthLabel();
    final curMap = {for (final e in cur) e.categoryId: e.total};
    final prevMap = {for (final e in prev) e.categoryId: e.total};
    String nameOf(int id) => cats[id]?.name ?? 'Other';
    (IconData, Color) badgeOf(int id) {
      final c = cats[id];
      return (
        c == null ? Icons.category_outlined : iconForKey(c.iconKey),
        c == null ? context.accent : colorFromHex(c.colorHex),
      );
    }

    // 1. Biggest category.
    final top = cur.first; // already sorted largest-first by the DB
    final share = (top.total / curTotal * 100).round();
    final (topIcon, topColor) = badgeOf(top.categoryId);
    insights.add((
      icon: topIcon,
      color: topColor,
      title: '${nameOf(top.categoryId)} leads your spending',
      subtitle: '${formatMoney(top.total)} · $share% of this month',
    ));

    // 2-3. Biggest riser and faller vs last month.
    final threshold = (curTotal * 0.03).ceil().clamp(1, 1 << 62);
    var riserId = -1;
    var riserPct = 0.0;
    var newId = -1;
    var newAmount = 0;
    var fallerId = -1;
    var fallerPct = 0.0;
    var goneId = -1;
    var goneAmount = 0;
    for (final id in {...curMap.keys, ...prevMap.keys}) {
      final c = curMap[id] ?? 0;
      final p = prevMap[id] ?? 0;
      if ((c > p ? c : p) < threshold) continue;
      if (p == 0) {
        if (c > newAmount) {
          newId = id;
          newAmount = c;
        }
      } else if (c == 0) {
        if (p > goneAmount) {
          goneId = id;
          goneAmount = p;
        }
      } else {
        final pct = (c - p) / p;
        if (pct >= 0.15 && pct > riserPct) {
          riserId = id;
          riserPct = pct;
        } else if (pct <= -0.15 && pct < fallerPct) {
          fallerId = id;
          fallerPct = pct;
        }
      }
    }
    if (riserId != -1) {
      final pct = (riserPct * 100).round();
      insights.add((
        icon: Icons.trending_up,
        color: AppColors.expense,
        title: '${nameOf(riserId)} up $pct%',
        subtitle:
            '${formatMoney(prevMap[riserId]!)} → ${formatMoney(curMap[riserId]!)} vs $prevLabel',
      ));
    } else if (newId != -1) {
      final badgeColor = badgeOf(newId).$2;
      insights.add((
        icon: Icons.fiber_new_outlined,
        color: badgeColor,
        title: 'New spending on ${nameOf(newId)}',
        subtitle: '${formatMoney(newAmount)} this month',
      ));
    }
    if (fallerId != -1) {
      final pct = (-fallerPct * 100).round();
      insights.add((
        icon: Icons.trending_down,
        color: AppColors.income,
        title: '${nameOf(fallerId)} down $pct%',
        subtitle:
            'Saved ${formatMoney(prevMap[fallerId]! - curMap[fallerId]!)} vs $prevLabel',
      ));
    } else if (goneId != -1) {
      insights.add((
        icon: Icons.check_circle_outline,
        color: AppColors.income,
        title: 'No ${nameOf(goneId)} spending',
        subtitle: 'Was ${formatMoney(goneAmount)} in $prevLabel',
      ));
    }

    // 4. Daily pace.
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final elapsed = isCurrent ? now.day : daysInMonth;
    final prevDays = DateTime(_month.year, _month.month, 0).day;
    if (elapsed >= 3 && prevTotal > 0) {
      final paceCur = (curTotal / elapsed).round();
      final pacePrev = (prevTotal / prevDays).round();
      final up = paceCur > pacePrev;
      insights.add((
        icon: Icons.speed_outlined,
        color: up ? AppColors.expense : AppColors.income,
        title: 'Daily pace ${formatMoney(paceCur)}',
        subtitle:
            '${up ? 'Above' : 'Below'} ${formatMoney(pacePrev)}/day in $prevLabel',
      ));
    }
    return insights;
  }

  Widget _insightsCard(
    BuildContext context,
    List<CategoryTotal> cur,
    List<CategoryTotal> prev,
    Map<int, Category> cats,
  ) {
    final insights = _buildInsights(context, cur, prev, cats);
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: insights.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Insights will appear here once you start tracking spending.',
                style: TextStyle(color: context.textMuted, fontSize: 13),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < insights.length; i++)
                  Entrance(
                    delay: Duration(milliseconds: 60 * i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: insights[i].color.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              insights[i].icon,
                              size: 20,
                              color: insights[i].color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  insights[i].title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  insights[i].subtitle,
                                  style: TextStyle(
                                    color: context.textMuted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  // -------------------------------- donut --------------------------------

  /// A donut slice: either a real category or the aggregated "Other".
  ({String name, String colorHex, int amount}) _sliceOf(
    CategoryTotal e,
    Map<int, Category> cats,
  ) => (
    name: cats[e.categoryId]?.name ?? 'Other',
    colorHex: cats[e.categoryId]?.colorHex ?? '#9CA3AF',
    amount: e.total,
  );

  Widget _donut(
    BuildContext context,
    List<CategoryTotal> totals,
    Map<int, Category> cats,
  ) {
    // Already grouped and sorted by the database.
    final sorted = totals;
    final total = sorted.fold<int>(0, (s, e) => s + e.total);
    if (total == 0) {
      return GlassCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'No expenses this month',
              style: TextStyle(color: context.textMuted),
            ),
          ),
        ),
      );
    }

    // Top 5 slices + an aggregated "Other" so no spending goes missing.
    final slices = <({String name, String colorHex, int amount})>[
      for (final e in sorted.take(5)) _sliceOf(e, cats),
      if (sorted.length > 5)
        (
          name: 'Other',
          colorHex: '#9CA3AF',
          amount: sorted.skip(5).fold<int>(0, (s, e) => s + e.total),
        ),
    ];
    if (_touchedDonutIndex >= slices.length) _touchedDonutIndex = -1;
    final touched = _touchedDonutIndex >= 0 ? slices[_touchedDonutIndex] : null;

    return GlassCard(
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    centerSpaceRadius: 58,
                    sectionsSpace: 3,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (event is FlTapUpEvent &&
                              response?.touchedSection != null) {
                            final i =
                                response!.touchedSection!.touchedSectionIndex;
                            _touchedDonutIndex = _touchedDonutIndex == i
                                ? -1
                                : i;
                          } else if (event is FlTapUpEvent) {
                            _touchedDonutIndex = -1;
                          }
                        });
                      },
                    ),
                    sections: [
                      for (var i = 0; i < slices.length; i++)
                        PieChartSectionData(
                          value: slices[i].amount.toDouble(),
                          color: colorFromHex(slices[i].colorHex),
                          radius: _touchedDonutIndex == i ? 44 : 34,
                          title: '',
                        ),
                    ],
                  ),
                  duration: _animDuration,
                  curve: _animCurve,
                ),
                // Center readout: total, or the tapped slice.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      touched?.name ?? 'Total',
                      style: TextStyle(color: context.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatMoney(touched?.amount ?? total),
                      style: AppTextStyles.amount(size: 18),
                    ),
                    if (touched != null)
                      Text(
                        '${(touched.amount / total * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: context.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < slices.length; i++)
            _legendRow(
              colorHex: slices[i].colorHex,
              name: slices[i].name,
              amount: slices[i].amount,
              total: total,
              selected: _touchedDonutIndex == i,
              onTap: () {
                Haptics.select();
                setState(() {
                  _touchedDonutIndex = _touchedDonutIndex == i ? -1 : i;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _legendRow({
    required String colorHex,
    required String name,
    required int amount,
    required int total,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: selected
              ? context.accent.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colorFromHex(colorHex),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(name)),
            Text(
              '${(amount / total * 100).toStringAsFixed(0)}%  ${formatMoney(amount)}',
              style: AppTextStyles.amount(size: 13),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------- bars ---------------------------------

  /// Lookup: 'yyyy-MM' -> kind -> total, from the pre-aggregated stream.
  Map<String, Map<String, int>> _monthlyLookup(List<MonthlyTotal> totals) {
    final map = <String, Map<String, int>>{};
    for (final t in totals) {
      map.putIfAbsent(t.month, () => {})[t.kind] = t.total;
    }
    return map;
  }

  String _monthKey(DateTime m) =>
      '${m.year}-${m.month.toString().padLeft(2, '0')}';

  Widget _bars(BuildContext context, List<MonthlyTotal> totals) {
    final now = DateTime.now();
    final months = List.generate(
      6,
      (i) => DateTime(now.year, now.month - 5 + i),
    );
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final lookup = _monthlyLookup(totals);

    double maxY = 1;
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < months.length; i++) {
      final kinds = lookup[_monthKey(months[i])] ?? const {};
      final income = (kinds['income'] ?? 0).toDouble();
      final expense = (kinds['expense'] ?? 0).toDouble();
      if (income > maxY) maxY = income;
      if (expense > maxY) maxY = expense;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: income,
              width: 9,
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppColors.income,
                  AppColors.income.withValues(alpha: 0.55),
                ],
              ),
            ),
            BarChartRodData(
              toY: expense,
              width: 9,
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppColors.expense,
                  AppColors.expense.withValues(alpha: 0.55),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      child: SizedBox(
        height: 210,
        child: BarChart(
          BarChartData(
            maxY: maxY * 1.15,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => context.raised,
                // Keep the tooltip inside the card instead of overflowing
                // its edges when touching edge bars.
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final m = months[group.x.toInt()];
                  final isIncome = rodIndex == 0;
                  return BarTooltipItem(
                    '${_monthLabel(m)}\n',
                    TextStyle(color: context.textMuted, fontSize: 11),
                    children: [
                      TextSpan(
                        text:
                            '${isIncome ? 'Income' : 'Expense'}: ${formatMoney(rod.toY.toInt())}',
                        style: TextStyle(
                          color: isIncome
                              ? AppColors.income
                              : AppColors.expense,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      monthNames[months[v.toInt()].month - 1],
                      style: TextStyle(fontSize: 11, color: context.textMuted),
                    ),
                  ),
                ),
              ),
            ),
            barGroups: groups,
          ),
          duration: _animDuration,
          curve: _animCurve,
        ),
      ),
    );
  }

  // -------------------------------- trend --------------------------------

  Widget _trendLine(BuildContext context, List<MonthlyTotal> totals) {
    final now = DateTime.now();
    final months = List.generate(
      6,
      (i) => DateTime(now.year, now.month - 5 + i),
    );
    final lookup = _monthlyLookup(totals);
    final spots = <FlSpot>[];
    for (var i = 0; i < months.length; i++) {
      final kinds = lookup[_monthKey(months[i])] ?? const {};
      // Transfers move money between wallets — neutral for net savings.
      final net = (kinds['income'] ?? 0) - (kinds['expense'] ?? 0);
      spots.add(FlSpot(i.toDouble(), net.toDouble()));
    }

    // Axis bounds from the data so the min/max labels sit exactly on the
    // extreme dots.
    var minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    var maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (minY == maxY) {
      // Flat line (e.g. no data yet) — give the chart some room.
      final pad = maxY.abs() * 0.1;
      minY -= pad > 0 ? pad : 1;
      maxY += pad > 0 ? pad : 1;
    }

    return GlassCard(
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => context.raised,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                getTooltipItems: (touchedSpots) => touchedSpots
                    .map(
                      (s) => LineTooltipItem(
                        '${_monthLabel(months[s.x.toInt()])}\n${formatMoney(s.y.toInt())}',
                        TextStyle(
                          color: context.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: maxY - minY,
                  getTitlesWidget: (v, meta) {
                    // Only the extremes — keeps the chart clean.
                    final isExtreme = (v - meta.min).abs() < 1e-6 ||
                        (v - meta.max).abs() < 1e-6;
                    if (!isExtreme) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        _compactMoney(v.round()),
                        style: TextStyle(
                          fontSize: 10,
                          color: context.textMuted,
                        ),
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (v, _) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _shortMonth(months[v.toInt()].month),
                      style: TextStyle(
                        fontSize: 10,
                        color: context.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: context.accent,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: context.accent.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
          duration: _animDuration,
          curve: _animCurve,
        ),
      ),
    );
  }

  /// Compact money for chart axis labels, e.g. 5_000_000 -> "5M".
  String _compactMoney(int amount) {
    String trim(double v) {
      final s = v.toStringAsFixed(1);
      return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    }

    final abs = amount.abs();
    if (abs >= 1000000000) return '${trim(amount / 1000000000)}B';
    if (abs >= 1000000) return '${trim(amount / 1000000)}M';
    if (abs >= 1000) return '${trim(amount / 1000)}K';
    return formatMoney(amount);
  }

  String _shortMonth(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month - 1];
  }

  String _monthLabel(DateTime m) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${names[m.month - 1]} ${m.year}';
  }

  // ------------------------------- net worth ------------------------------

  Widget _netWorthRangeChips() {
    const options = [3, 6, 12];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final m in options)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: ChoiceChip(
              label: Text('${m}M'),
              selected: _netWorthRange == m,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              selectedColor: context.accent,
              labelStyle: TextStyle(
                fontSize: 12,
                color: _netWorthRange == m
                    ? onAccent(context.accent)
                    : context.textMuted,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) => setState(() => _netWorthRange = m),
            ),
          ),
      ],
    );
  }

  /// Total balance over time, derived backwards from today's total using
  /// monthly income/expense sums (transfers are neutral).
  Widget _netWorthCard(BuildContext context, AppDatabase db, int? accountId) {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - 11);
    final to = DateTime(
      now.year,
      now.month + 1,
    ).subtract(const Duration(seconds: 1));
    return StreamBuilder<List<Wallet>>(
      stream: db.watchWallets(accountId: accountId),
      builder: (context, wSnap) {
        final wallets = wSnap.data ?? const <Wallet>[];
        final currentTotal = wallets.fold<int>(0, (s, w) => s + w.balance);
        return StreamBuilder<List<MonthlyTotal>>(
          stream: db.watchMonthlyKindTotals(from, to, accountId: accountId),
          builder: (context, mSnap) {
            final totals = mSnap.data ?? const <MonthlyTotal>[];
            return _netWorthChart(context, currentTotal, totals);
          },
        );
      },
    );
  }

  Widget _netWorthChart(
    BuildContext context,
    int currentTotal,
    List<MonthlyTotal> totals,
  ) {
    final now = DateTime.now();
    final n = _netWorthRange;
    final months = List.generate(
      n,
      (i) => DateTime(now.year, now.month - n + 1 + i),
    );
    final lookup = _monthlyLookup(totals);
    // Net worth at the end of each month, walked backwards from today.
    var worth = currentTotal.toDouble();
    final points = List<double>.filled(n, 0);
    for (var i = n - 1; i >= 0; i--) {
      points[i] = worth;
      final kinds = lookup[_monthKey(months[i])] ?? const {};
      worth -= ((kinds['income'] ?? 0) - (kinds['expense'] ?? 0));
    }
    final delta = points.last - points.first;
    final pct = points.first == 0 ? 0.0 : delta / points.first.abs() * 100;
    final up = delta >= 0;
    final spots = [for (var i = 0; i < n; i++) FlSpot(i.toDouble(), points[i])];
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total net worth',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textMuted),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              CountUpMoney(
                amount: currentTotal,
                style: AppTextStyles.displayBalance.copyWith(
                  fontSize: 28,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (up ? AppColors.income : AppColors.expense).withValues(
                    alpha: 0.14,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${up ? '+' : ''}${formatMoney(delta.toInt())} (${up ? '+' : ''}${pct.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: up ? AppColors.income : AppColors.expense,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            // Line-draw effect: the chart is revealed left-to-right, as if
            // the line is being drawn. Replays when the range changes.
            child: TweenAnimationBuilder<double>(
              key: ValueKey(_netWorthRange),
              tween: Tween(begin: 0.0, end: 1.0),
              duration: AppMotion.slow,
              curve: AppMotion.enter,
              builder: (context, progress, child) => ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.01, 1.0),
                  child: child,
                ),
              ),
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => context.raised,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      tooltipPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      getTooltipItems: (touchedSpots) => touchedSpots
                          .map(
                            (s) => LineTooltipItem(
                              '${_monthLabel(months[s.x.toInt()])}\n${formatMoney(s.y.toInt())}',
                              TextStyle(
                                color: context.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: context.accent,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            context.accent.withValues(alpha: 0.32),
                            context.accent.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                duration: _animDuration,
                curve: _animCurve,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
