import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Tiny sparkline micro-graph, extracted from the old home stat cards.
/// Now lives beside the income/expense columns inside the balance card.
class MiniSparkline extends StatelessWidget {
  const MiniSparkline({super.key, required this.values, required this.color});

  final List<double> values;
  final Color color;

  /// Winsorize runaway spikes at 2x the 90th percentile so a single huge
  /// bucket doesn't flatten the rest of the shape. The spike stays the
  /// tallest point — it just stops dominating the scale.
  List<double> _calm(List<double> values) {
    if (values.length < 4) return values;
    final sorted = [...values]..sort();
    final p90 =
        sorted[(sorted.length * 0.9).floor().clamp(0, sorted.length - 1)];
    if (p90 <= 0) return values;
    final cap = p90 * 2;
    return [for (final v in values) v > cap ? cap : v];
  }

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < values.length; i++)
        FlSpot(i.toDouble(), _calm(values)[i]),
    ];
    return LineChart(
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
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.35),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: AppMotion.slow,
      curve: AppMotion.enter,
    );
  }
}
