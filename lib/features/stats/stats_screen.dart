import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/section_header.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// Reports: expense donut, 6-month income/expense bars, net-savings trend.
/// All charts are live (driven by the transaction stream), tappable, and
/// animate on every data change.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  static const _animDuration = Duration(milliseconds: 800);
  static const _animCurve = Curves.easeOutCubic;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int _touchedDonutIndex = -1;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final monthStart = DateTime(_month.year, _month.month);
    final monthEnd = DateTime(
      _month.year,
      _month.month + 1,
    ).subtract(const Duration(seconds: 1));

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: StreamBuilder<List<Transaction>>(
        stream: db.watchTransactionsRaw(),
        builder: (context, txSnap) {
          final txs = txSnap.data ?? const <Transaction>[];
          return StreamBuilder<List<Category>>(
            stream: db.watchCategories(),
            builder: (context, catSnap) {
              final cats = {
                for (final c in (catSnap.data ?? const <Category>[])) c.id: c,
              };
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _monthSelector(context),
                    const SectionHeader(title: 'Spending by category'),
                    _donut(context, txs, cats, monthStart, monthEnd),
                    const SectionHeader(title: 'Last 6 months'),
                    _bars(context, txs),
                    const SectionHeader(title: 'Net savings trend'),
                    _trendLine(context, txs),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _monthSelector(BuildContext context) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    void shift(int delta) => setState(() {
          _month = DateTime(_month.year, _month.month + delta);
          _touchedDonutIndex = -1;
        });
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => shift(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          '${months[_month.month - 1]} ${_month.year}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        IconButton(
          onPressed: () => shift(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  // -------------------------------- donut --------------------------------

  /// A donut slice: either a real category or the aggregated "Other".
  ({String name, String colorHex, int amount}) _sliceOf(
    MapEntry<int, int> e,
    Map<int, Category> cats,
  ) =>
      (
        name: cats[e.key]?.name ?? 'Other',
        colorHex: cats[e.key]?.colorHex ?? '#9CA3AF',
        amount: e.value,
      );

  Widget _donut(
    BuildContext context,
    List<Transaction> txs,
    Map<int, Category> cats,
    DateTime from,
    DateTime to,
  ) {
    final expenses = txs.where(
      (t) =>
          t.kind == 'expense' && !t.date.isBefore(from) && !t.date.isAfter(to),
    );
    final byCat = <int, int>{};
    for (final t in expenses) {
      byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amount;
    }
    final total = byCat.values.fold<int>(0, (s, v) => s + v);
    if (total == 0) {
      return const GlassCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'No expenses this month',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }

    final sorted = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // Top 5 slices + an aggregated "Other" so no spending goes missing.
    final slices = <({String name, String colorHex, int amount})>[
      for (final e in sorted.take(5)) _sliceOf(e, cats),
      if (sorted.length > 5)
        (
          name: 'Other',
          colorHex: '#9CA3AF',
          amount: sorted.skip(5).fold<int>(0, (s, e) => s + e.value),
        ),
    ];
    if (_touchedDonutIndex >= slices.length) _touchedDonutIndex = -1;
    final touched =
        _touchedDonutIndex >= 0 ? slices[_touchedDonutIndex] : null;

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
                            final i = response!
                                .touchedSection!.touchedSectionIndex;
                            _touchedDonutIndex =
                                _touchedDonutIndex == i ? -1 : i;
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
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatMoney(touched?.amount ?? total),
                      style: AppTextStyles.amount(size: 18),
                    ),
                    if (touched != null)
                      Text(
                        '${(touched.amount / total * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: AppColors.lime,
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
              onTap: () => setState(() {
                _touchedDonutIndex = _touchedDonutIndex == i ? -1 : i;
              }),
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
              ? AppColors.lime.withValues(alpha: 0.08)
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

  Widget _bars(BuildContext context, List<Transaction> txs) {
    final now = DateTime.now();
    final months = List.generate(
      6,
      (i) => DateTime(now.year, now.month - 5 + i),
    );
    const monthNames = [
      'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D',
    ];

    double maxY = 1;
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < months.length; i++) {
      final m = months[i];
      final from = DateTime(m.year, m.month);
      final to = DateTime(
        m.year,
        m.month + 1,
      ).subtract(const Duration(seconds: 1));
      final inMonth = txs.where(
        (t) => !t.date.isBefore(from) && !t.date.isAfter(to),
      );
      final income = inMonth
          .where((t) => t.kind == 'income')
          .fold<int>(0, (s, t) => s + t.amount)
          .toDouble();
      final expense = inMonth
          .where((t) => t.kind == 'expense')
          .fold<int>(0, (s, t) => s + t.amount)
          .toDouble();
      if (income > maxY) maxY = income;
      if (expense > maxY) maxY = expense;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: income,
              color: AppColors.income,
              width: 9,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: expense,
              color: AppColors.expense,
              width: 9,
              borderRadius: BorderRadius.circular(4),
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
                getTooltipColor: (_) => AppColors.bgRaised,
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final m = months[group.x.toInt()];
                  final isIncome = rodIndex == 0;
                  return BarTooltipItem(
                    '${_monthLabel(m)}\n',
                    const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
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
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
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

  Widget _trendLine(BuildContext context, List<Transaction> txs) {
    final now = DateTime.now();
    final months = List.generate(
      6,
      (i) => DateTime(now.year, now.month - 5 + i),
    );
    final spots = <FlSpot>[];
    for (var i = 0; i < months.length; i++) {
      final m = months[i];
      final from = DateTime(m.year, m.month);
      final to = DateTime(
        m.year,
        m.month + 1,
      ).subtract(const Duration(seconds: 1));
      final inMonth = txs.where(
        (t) => !t.date.isBefore(from) && !t.date.isAfter(to),
      );
      // Transfers move money between wallets — neutral for net savings.
      final net = inMonth.fold<int>(
        0,
        (s, t) => switch (t.kind) {
          'income' => s + t.amount,
          'expense' => s - t.amount,
          _ => s,
        },
      );
      spots.add(FlSpot(i.toDouble(), net.toDouble()));
    }
    return GlassCard(
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.bgRaised,
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                getTooltipItems: (touchedSpots) => touchedSpots
                    .map(
                      (s) => LineTooltipItem(
                        '${_monthLabel(months[s.x.toInt()])}\n${formatMoney(s.y.toInt())}',
                        const TextStyle(
                          color: AppColors.lime,
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
                color: AppColors.lime,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.lime.withValues(alpha: 0.12),
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

  String _monthLabel(DateTime m) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${names[m.month - 1]} ${m.year}';
  }
}
