import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_accents.dart';
import '../../../core/theme/app_motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_page_route.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../transactions/widgets/month_selector.dart';

/// "Show more" drill-down behind Stats' Overview and Spending by category:
/// income/expense for one month, broken down by category — a big donut with
/// percentage callouts plus a per-category list with amounts, shares and
/// transaction counts. Everything animates on month/kind/data changes.
class StructureScreen extends ConsumerStatefulWidget {
  const StructureScreen({
    super.key,
    required this.month,
    this.initialKind = 'expense',
  });

  final DateTime month;
  final String initialKind;

  static void open(
    BuildContext context, {
    required DateTime month,
    String initialKind = 'expense',
  }) {
    Navigator.of(context).push(
      AppPageRoute(
        builder: (_) =>
            StructureScreen(month: month, initialKind: initialKind),
      ),
    );
  }

  @override
  ConsumerState<StructureScreen> createState() => _StructureScreenState();
}

class _Slice {
  const _Slice({
    required this.name,
    required this.color,
    required this.amount,
  });

  final String name;
  final Color color;
  final int amount;
}

class _StructureScreenState extends ConsumerState<StructureScreen> {
  static const _animDuration = AppMotion.slow;
  static const _animCurve = Curves.easeOutCubic;

  /// Donut geometry (fl_chart 1.x draws the ring outward from the hole).
  static const _hole = 64.0;
  static const _ringBase = 38.0;
  static const _ringTouched = 50.0;

  late DateTime _month;
  late String _kind;
  int _touched = -1;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.month.year, widget.month.month);
    _kind = widget.initialKind;
  }

  bool get _isIncome => _kind == 'income';

  void _shift(int delta) => setState(() {
        _month = DateTime(_month.year, _month.month + delta);
        _touched = -1;
      });

  Future<void> _pickMonth() async {
    final picked = await showMonthYearPicker(context, _month);
    if (picked != null) {
      setState(() {
        _month = picked;
        _touched = -1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final from = DateTime(_month.year, _month.month);
    final to = DateTime(_month.year, _month.month + 1)
        .subtract(const Duration(seconds: 1));

    return Scaffold(
      appBar: AppBar(title: const Text('Structure')),
      body: Column(
        children: [
          MonthSelector(month: _month, onShift: _shift, onPick: _pickMonth),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'income', label: Text('INCOME')),
                  ButtonSegment(value: 'expense', label: Text('EXPENSE')),
                ],
                selected: {_kind},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  _kind = s.first;
                  _touched = -1;
                }),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CategoryStat>>(
              stream: db.watchCategoryKindStats(_kind, from, to),
              builder: (context, statSnap) {
                final stats = statSnap.data ?? const <CategoryStat>[];
                return StreamBuilder<List<Category>>(
                  stream: db.watchCategories(),
                  builder: (context, catSnap) {
                    final cats = {
                      for (final c in (catSnap.data ?? const <Category>[]))
                        c.id: c,
                    };
                    return _body(stats, cats);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(List<CategoryStat> stats, Map<int, Category> cats) {
    final total = stats.fold<int>(0, (s, e) => s + e.total);
    return SingleChildScrollView(
      // Replay the stagger whenever month or kind changes.
      key: ValueKey('$_kind-${_month.year}-${_month.month}'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Entrance(child: _donutCard(stats, cats, total)),
          const SizedBox(height: 8),
          if (total == 0)
            Entrance(
              delay: const Duration(milliseconds: 120),
              child: GlassCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      _isIncome
                          ? 'No income this month'
                          : 'No expenses this month',
                      style: TextStyle(color: context.textMuted),
                    ),
                  ),
                ),
              ),
            )
          else
            for (var i = 0; i < stats.length; i++)
              Entrance(
                delay: Duration(milliseconds: 80 + (i * 45).clamp(0, 450)),
                child: _categoryRow(stats[i], cats[stats[i].categoryId],
                    total, i == stats.length - 1),
              ),
        ],
      ),
    );
  }

  Widget _donutCard(
      List<CategoryStat> stats, Map<int, Category> cats, int total) {
    if (total == 0) {
      return const SizedBox.shrink();
    }
    final slices = [
      for (final s in stats)
        _Slice(
          name: cats[s.categoryId]?.name ?? 'Unknown',
          color: cats[s.categoryId] != null
              ? colorFromHex(cats[s.categoryId]!.colorHex)
              : Colors.grey,
          amount: s.total,
        ),
    ];
    if (_touched >= slices.length) _touched = -1;
    final touched = _touched >= 0 ? slices[_touched] : null;

    // Percentage callouts with leader lines, for slices >= 5% (max 6).
    final callouts = <_Callout>[];
    var acc = 0;
    for (var i = 0; i < slices.length && callouts.length < 6; i++) {
      final share = slices[i].amount / total;
      final midDeg = -90 + 360 * (acc + slices[i].amount / 2) / total;
      acc += slices[i].amount;
      if (share < 0.05) continue;
      callouts.add(_Callout(
        midRadians: midDeg * math.pi / 180,
        outerR: _hole + (_touched == i ? _ringTouched : _ringBase),
        color: slices[i].color,
        label:
            '${(share * 100).toStringAsFixed(1).replaceAll('.', ',')}%',
      ));
    }

    final signedTotal =
        _isIncome ? formatMoney(total) : '-${formatMoney(total)}';

    return GlassCard(
      child: SizedBox(
        height: 300,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: 300,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: _hole,
                  sectionsSpace: 3,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        if (event is FlTapUpEvent &&
                            response?.touchedSection != null) {
                          final i = response!
                              .touchedSection!.touchedSectionIndex;
                          _touched = _touched == i ? -1 : i;
                        } else if (event is FlTapUpEvent) {
                          _touched = -1;
                        }
                      });
                    },
                  ),
                  sections: [
                    for (var i = 0; i < slices.length; i++)
                      PieChartSectionData(
                        value: slices[i].amount.toDouble(),
                        color: slices[i].color,
                        radius: _touched == i ? _ringTouched : _ringBase,
                        title: '',
                      ),
                  ],
                ),
                duration: _animDuration,
                curve: _animCurve,
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _CalloutPainter(callouts: callouts),
              ),
            ),
            // Center readout: total, or the tapped slice.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  touched?.name ?? (_isIncome ? 'Income' : 'Expense'),
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  touched != null
                      ? (_isIncome
                          ? formatMoney(touched.amount)
                          : '-${formatMoney(touched.amount)}')
                      : signedTotal,
                  style: AppTextStyles.amount(size: 20),
                ),
                if (touched != null)
                  Text(
                    '${(touched.amount / total * 100).toStringAsFixed(1).replaceAll('.', ',')}%',
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
    );
  }

  Widget _categoryRow(
      CategoryStat s, Category? c, int total, bool last) {
    final color =
        c != null ? colorFromHex(c.colorHex) : Colors.grey;
    final pct = total == 0 ? 0.0 : s.total / total * 100;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
                child: Icon(
                  iconForKey(c?.iconKey ?? ''),
                  color: onAccent(color),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c?.name ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pct.toStringAsFixed(1).replaceAll('.', ',')}%',
                      style: TextStyle(
                          color: context.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _isIncome
                        ? formatMoney(s.total)
                        : '-${formatMoney(s.total)}',
                    style: AppTextStyles.amount(size: 15, weight: FontWeight.w700)
                        .copyWith(
                      color: _isIncome
                          ? AppColors.income
                          : AppColors.expense,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.count} ${s.count == 1 ? 'transaction' : 'transactions'}',
                    style: TextStyle(
                        color: context.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!last) Divider(height: 1, color: context.hairline),
      ],
    );
  }
}

class _Callout {
  const _Callout({
    required this.midRadians,
    required this.outerR,
    required this.color,
    required this.label,
  });

  final double midRadians;
  final double outerR;
  final Color color;
  final String label;
}

/// Percentage labels with elbow leader lines around the donut,
/// in the reference app's style.
class _CalloutPainter extends CustomPainter {
  _CalloutPainter({required this.callouts});

  final List<_Callout> callouts;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (final c in callouts) {
      final dir =
          Offset(math.cos(c.midRadians), math.sin(c.midRadians));
      final rightSide = dir.dx >= 0;
      final edge = center + dir * (c.outerR + 2);
      final elbow = center + dir * (c.outerR + 22);
      final endX = center.dx + (rightSide ? 1 : -1) * (c.outerR + 22);
      final end = Offset(endX, elbow.dy);

      canvas.drawCircle(edge, 3, Paint()..color = c.color);
      canvas.drawPath(
        Path()
          ..moveTo(edge.dx, edge.dy)
          ..lineTo(elbow.dx, elbow.dy)
          ..lineTo(end.dx, end.dy),
        Paint()
          ..color = c.color
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: c.label,
          style: TextStyle(
            color: c.color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        rightSide
            ? Offset(end.dx + 6, end.dy - tp.height / 2)
            : Offset(end.dx - 6 - tp.width, end.dy - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_CalloutPainter oldDelegate) =>
      oldDelegate.callouts != callouts;
}
