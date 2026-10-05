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
    final calmed = _calm(values);
    final spots = [
      for (var i = 0; i < calmed.length; i++) FlSpot(i.toDouble(), calmed[i]),
    ];
    final maxVal = calmed.fold<double>(0, (m, v) => v > m ? v : m);
    // Headroom so the line never glues itself to the container edge: a flat
    // zero line (e.g. no income yet) would otherwise sit exactly on the
    // bottom boundary, and a tall spike would touch the top.
    final headroom = maxVal > 0 ? maxVal * 0.25 : 1.0;
    // Horizontal breathing room so the endpoints don't touch the left/right
    // edges of the box (the 2.5px stroke would otherwise get clipped there).
    final double? minX = calmed.isNotEmpty ? -0.35 : null;
    final double? maxX = calmed.isNotEmpty ? calmed.length - 1 + 0.35 : null;
    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: -headroom * 0.2,
        maxY: maxVal + headroom,
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
