import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/app_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../../core/utils/haptics.dart';
import '../transactions/transaction_detail_screen.dart';
import 'budget_form_sheet.dart';

/// Detail view for one monthly budget: spent/left, progress, daily burn
/// chart against the limit, pace stats, and its transactions.
class BudgetDetailScreen extends ConsumerStatefulWidget {
  const BudgetDetailScreen({
    super.key,
    required this.budgetId,
    required this.month,
  });

  final int budgetId;
  final String month; // "yyyy-MM"

  @override
  ConsumerState<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends ConsumerState<BudgetDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        actions: [
          IconButton(
            tooltip: 'Edit limit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Haptics.select();
              _editLimit(context, db);
            },
          ),
          IconButton(
            tooltip: 'Delete budget',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              Haptics.select();
              _confirmDelete(context, db);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Budget>>(
        stream: db.watchBudgets(widget.month),
        builder: (context, bSnap) {
          final budgets = bSnap.data ?? const <Budget>[];
          Budget? found;
          for (final b in budgets) {
            if (b.id == widget.budgetId) found = b;
          }
          final budget = found;
          if (budget == null) {
            return Center(
              child: Text('Budget not found',
                  style: TextStyle(color: context.textMuted)),
            );
          }
          final categoryId = budget.categoryId;
          final parts = widget.month.split('-');
          final monthStart =
              DateTime(int.parse(parts[0]), int.parse(parts[1]));
          final monthEnd = DateTime(
            monthStart.year,
            monthStart.month + 1,
          ).subtract(const Duration(seconds: 1));
          return StreamBuilder<List<TransactionWithDetails>>(
            stream: db.watchTransactionsForCategory(
                categoryId, monthStart, monthEnd),
            builder: (context, txSnap) {
              final txs = (txSnap.data ?? const <TransactionWithDetails>[])
                  .where((d) => d.transaction.kind == 'expense')
                  .toList();
              return StreamBuilder<List<Category>>(
                stream: db.watchCategories(),
                builder: (context, catSnap) {
                  Category? cat;
                  for (final c in catSnap.data ?? const <Category>[]) {
                    if (c.id == categoryId) cat = c;
                  }
                  return _content(context, db, budget, cat, txs);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _content(
    BuildContext context,
    AppDatabase db,
    Budget budget,
    Category? cat,
    List<TransactionWithDetails> txs,
  ) {
    final spent = txs.fold<int>(0, (s, d) => s + d.transaction.amount);
    final left = budget.limit - spent;
    final ratio = budget.limit == 0 ? 0.0 : spent / budget.limit;

    final parts = widget.month.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final now = DateTime.now();
    final isCurrentMonth = now.year == year && now.month == month;
    final daysElapsed = isCurrentMonth ? now.day : daysInMonth;
    final daysLeft = isCurrentMonth ? daysInMonth - now.day : 0;
    final recommended =
        daysLeft > 0 ? left / (daysLeft + 1) : 0.0; // per day, incl. today
    final average = daysElapsed > 0 ? spent / daysElapsed : 0.0;

    final catColor = colorFromHex(cat?.colorHex ?? '#9CA3AF');
    final barColor = ratio >= 1
        ? AppColors.expense
        : ratio >= 0.8
            ? AppColors.warning
            : AppColors.income;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cat?.name ?? 'Budget',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _amountColumn('Spent', formatMoney(spent), context.textMuted),
              _amountColumn('Left', formatMoney(left),
                  left < 0 ? AppColors.expense : context.textMuted),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar with centered percentage.
          SizedBox(
            height: 26,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                children: [
                  Container(color: context.raised),
                  FractionallySizedBox(
                    widthFactor: ratio.clamp(0.0, 1.0),
                    child: Container(color: barColor),
                  ),
                  Center(
                    child: Text(
                      '${(ratio * 100).toStringAsFixed(2).replaceAll('.', ',')}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _infoRow('Category', cat?.name ?? '—'),
          _infoRow('Budget', formatMoney(budget.limit)),
          _infoRow(
            'Period',
            '01–${daysInMonth.toString().padLeft(2, '0')} ${_monthName(month)} $year',
            sub: isCurrentMonth ? '$daysLeft days left' : null,
          ),
          const SizedBox(height: 8),
          _dailyChart(
              context, txs, budget.limit, daysInMonth, month, year, catColor),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _paceStat('Recommended', recommended),
              ),
              Expanded(
                child: _paceStat('Average', average),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Transaction list',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (txs.isEmpty)
            Text('No transactions in this budget yet.',
                style: TextStyle(color: context.textMuted))
          else
            for (final d in txs)
              _txRow(context, d, catColor),
        ],
      ),
    );
  }

  Widget _amountColumn(String label, String value, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.amount(size: 15)),
      ],
    );
  }

  Widget _infoRow(String label, String value, {String? sub}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style:
                    TextStyle(color: context.textMuted, fontSize: 15)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                if (sub != null)
                  Text(sub,
                      style: TextStyle(
                          color: context.textMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dailyChart(
    BuildContext context,
    List<TransactionWithDetails> txs,
    int limit,
    int daysInMonth,
    int month,
    int year,
    Color catColor,
  ) {
    // Cumulative spend per day.
    final perDay = List<int>.filled(daysInMonth + 1, 0);
    for (final d in txs) {
      final day = d.transaction.date.day;
      if (day >= 1 && day <= daysInMonth) perDay[day] += d.transaction.amount;
    }
    var cumulative = 0;
    final spots = <FlSpot>[];
    for (var day = 1; day <= daysInMonth; day++) {
      cumulative += perDay[day];
      spots.add(FlSpot(day.toDouble(), cumulative.toDouble()));
    }
    final maxY =
        [limit.toDouble(), cumulative.toDouble(), 1.0].reduce((a, b) => a > b ? a : b) *
            1.15;
    final fmt = NumberFormat('#,##0', currentCurrency.locale);
    final mm = month.toString().padLeft(2, '0');

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 1,
          maxX: daysInMonth.toDouble(),
          minY: 0,
          maxY: maxY,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => context.raised,
              getTooltipItems: (items) => items
                  .map((s) => LineTooltipItem(
                        'Day ${s.x.toInt()}\n${formatMoney(s.y.toInt())}',
                        TextStyle(
                            color: context.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ))
                  .toList(),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: context.hairline,
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                interval: maxY / 5,
                getTitlesWidget: (v, _) => Text(
                  fmt.format(v.toInt()),
                  style: TextStyle(
                      color: context.textMuted, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: daysInMonth > 2 ? (daysInMonth - 1).toDouble() : 1,
                getTitlesWidget: (v, _) {
                  final day = v.toInt();
                  if (day != 1 && day != daysInMonth) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    '${day.toString().padLeft(2, '0')}/$mm',
                    style: TextStyle(
                        color: context.textMuted, fontSize: 10),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: limit.toDouble(),
                color: AppColors.expense,
                strokeWidth: 1.5,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 4, bottom: 2),
                  style: const TextStyle(
                    color: AppColors.expense,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  labelResolver: (_) => formatMoney(limit),
                ),
              ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: context.textMuted.withValues(alpha: 0.7),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: context.textMuted.withValues(alpha: 0.18),
              ),
            ),
          ],
        ),
        duration: AppMotion.slow,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Widget _paceStat(String label, double value) {
    final decimals = currentCurrency.decimals > 0 ? 2 : 0;
    final text = NumberFormat('#,##0.${'0' * decimals}',
            currentCurrency.locale)
        .format(value)
        .replaceAll('.', ',');
    return Column(
      children: [
        Text(label,
            style:
                TextStyle(color: context.textMuted, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          '${currencyFieldPrefix.trim()} $text',
          style: AppTextStyles.amount(size: 17),
        ),
      ],
    );
  }

  Widget _txRow(BuildContext context, TransactionWithDetails d, Color catColor) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        AppPageRoute(
          builder: (_) => TransactionDetailScreen(
            transactionId: d.transaction.id,
            iconKey: d.category.iconKey,
            colorHex: d.category.colorHex,
            title: d.transaction.note.isNotEmpty
                ? d.transaction.note
                : d.category.name,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Hero(
              tag: 'tx-icon-${d.transaction.id}',
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(iconForKey(d.category.iconKey),
                    color: catColor, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.transaction.note.isNotEmpty
                      ? d.transaction.note
                      : d.category.name),
                  Text(
                    formatDate(d.transaction.date),
                    style: TextStyle(
                        color: context.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              formatSignedMoney(d.transaction.amount, isIncome: false),
              style: AppTextStyles.amount(size: 15)
                  .copyWith(color: AppColors.expense),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int m) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[m - 1];
  }

  Future<void> _editLimit(BuildContext context, AppDatabase db) async {
    final result = await showEditBudgetLimitSheet(
      context,
      ref,
      budgetId: widget.budgetId,
    );
    if (result != null && result > 0) {
      await db.updateBudgetLimit(widget.budgetId, result);
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppDatabase db) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete budget?'),
        content: const Text(
            'The budget and its alerts will be removed. Transactions stay.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Haptics.medium();
              Navigator.pop(context, true);
            },
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.expense),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await db.deleteBudget(widget.budgetId);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
