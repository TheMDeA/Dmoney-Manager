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
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () =>
              setState(() => _month = DateTime(_month.year, _month.month - 1)),
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          '${months[_month.month - 1]} ${_month.year}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        IconButton(
          onPressed: () =>
              setState(() => _month = DateTime(_month.year, _month.month + 1)),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

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
        child: Center(child: Text('No expenses this month')),
      );
    }
    final sorted = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();

    return GlassCard(
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    centerSpaceRadius: 58,
                    sectionsSpace: 3,
                    sections: [
                      for (final e in top)
                        PieChartSectionData(
                          value: e.value.toDouble(),
                          color: colorFromHex(
                            cats[e.key]?.colorHex ?? '#9CA3AF',
                          ),
                          radius: 34,
                          title: '',
                        ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      formatMoney(total),
                      style: AppTextStyles.amount(size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final e in top)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colorFromHex(cats[e.key]?.colorHex ?? '#9CA3AF'),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(cats[e.key]?.name ?? 'Other')),
                  Text(
                    '${(e.value / total * 100).toStringAsFixed(0)}%  ${formatMoney(e.value)}',
                    style: AppTextStyles.amount(size: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bars(BuildContext context, List<Transaction> txs) {
    final now = DateTime.now();
    final months = List.generate(
      6,
      (i) => DateTime(now.year, now.month - 5 + i),
    );
    const monthNames = [
      'J',
      'F',
      'M',
      'A',
      'M',
      'J',
      'J',
      'A',
      'S',
      'O',
      'N',
      'D',
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
        height: 200,
        child: BarChart(
          BarChartData(
            maxY: maxY * 1.15,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: false),
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
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

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
      final net = inMonth.fold<int>(
        0,
        (s, t) => s + (t.kind == 'income' ? t.amount : -t.amount),
      );
      spots.add(FlSpot(i.toDouble(), net.toDouble()));
    }
    return GlassCard(
      child: SizedBox(
        height: 170,
        child: LineChart(
          LineChartData(
            lineTouchData: const LineTouchData(enabled: false),
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
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }
}
