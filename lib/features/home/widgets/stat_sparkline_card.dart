import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_card.dart';

/// Small stat card with an inline sparkline micro-graph.
class StatSparklineCard extends StatelessWidget {
  const StatSparklineCard({
    super.key,
    required this.label,
    required this.amount,
    required this.isIncome,
    required this.dailyTotals,
  });

  final String label;
  final int amount;
  final bool isIncome;
  final List<double> dailyTotals;

  @override
  Widget build(BuildContext context) {
    final color = isIncome ? AppColors.income : AppColors.expense;
    final spots = [
      for (var i = 0; i < dailyTotals.length; i++)
        FlSpot(i.toDouble(), dailyTotals[i]),
    ];
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              formatSignedMoney(amount, isIncome: isIncome),
              style: AppTextStyles.amount(size: 17).copyWith(color: color),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
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
                      color: color,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
