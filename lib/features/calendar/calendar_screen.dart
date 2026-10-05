import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/amount_text.dart';
import '../../core/widgets/count_up_money.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../transactions/widgets/transaction_tile.dart';

/// Per-day totals for one calendar cell.
class _DayTotal {
  int income = 0;
  int expense = 0;
  final items = <TransactionWithDetails>[];
}

/// Month calendar: per-day income/expense/net in every cell,
/// month summary on top, tap a day for its transactions.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  late DateTime _month =
      DateTime(DateTime.now().year, DateTime.now().month);
  int _slideDir = 1;

  void _shift(int delta) => setState(() {
        _slideDir = delta.sign;
        _month = DateTime(_month.year, _month.month + delta);
      });

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final accountId = ref.watch(selectedAccountProvider);
    final first = DateTime(_month.year, _month.month);
    // Sunday-first grid covering 6 weeks.
    final gridStart =
        first.subtract(Duration(days: first.weekday % 7));
    final gridEnd =
        gridStart.add(const Duration(days: 42)).subtract(
              const Duration(seconds: 1),
            );
    final today = DateTime.now();
    final todayKey =
        DateTime(today.year, today.month, today.day);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: StreamBuilder<List<TransactionWithDetails>>(
        stream: db.watchTransactionsInRange(gridStart, gridEnd,
            accountId: accountId),
        builder: (context, snap) {
          final items = snap.data ?? const <TransactionWithDetails>[];
          final totals = <DateTime, _DayTotal>{};
          for (final d in items) {
            final t = d.transaction;
            final key = DateTime(t.date.year, t.date.month, t.date.day);
            final day = totals.putIfAbsent(key, _DayTotal.new);
            day.items.add(d);
            if (t.kind == 'income') {
              day.income += t.amount;
            } else if (t.kind == 'expense') {
              day.expense += t.amount;
            }
          }
          var monthIncome = 0;
          var monthExpense = 0;
          for (final d in items) {
            final t = d.transaction;
            if (t.date.year != _month.year ||
                t.date.month != _month.month) {
              continue;
            }
            if (t.kind == 'income') {
              monthIncome += t.amount;
            } else if (t.kind == 'expense') {
              monthExpense += t.amount;
            }
          }
          return Column(
            children: [
              _monthSelector(),
              _summary(monthIncome, monthExpense),
              _weekdayHeader(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppMotion.normal,
                  layoutBuilder:
                      (currentChild, previousChildren) => Stack(
                    children: [
                      ...previousChildren,
                      ?currentChild,
                    ],
                  ),
                  transitionBuilder: (child, animation) {
                    // Direction-aware slide: the incoming month enters
                    // from the tapped side, the outgoing exits opposite.
                    final monthKey =
                        (child.key! as ValueKey<DateTime>).value;
                    final incoming = monthKey == _month;
                    final begin = incoming
                        ? Offset(0.3 * _slideDir, 0)
                        : Offset(-0.3 * _slideDir, 0);
                    final position =
                        Tween<Offset>(begin: begin, end: Offset.zero)
                            .animate(CurvedAnimation(
                      parent: animation,
                      curve: incoming
                          ? AppMotion.enter
                          : AppMotion.exit,
                    ));
                    return ClipRect(
                      child: FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: position,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_month),
                    child: _grid(gridStart, totals, todayKey),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------- header --------------------------------

  Widget _monthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => _shift(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          DateFormat('MMM yyyy').format(_month),
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 16),
        ),
        IconButton(
          onPressed: () => _shift(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _summary(int income, int expense) {
    final total = income - expense;
    Widget cell(String label, Widget value) => Expanded(
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(
                      color: context.textMuted, fontSize: 13)),
              const SizedBox(height: 4),
              value,
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          cell(
            'Income',
            CountUpMoney(
              amount: income,
              style: AppTextStyles.amount(size: 15, weight: FontWeight.w700)
                  .copyWith(color: AppColors.income),
            ),
          ),
          cell(
            'Expense',
            CountUpMoney(
              amount: expense,
              format: (v) => '-${formatMoney(v)}',
              style: AppTextStyles.amount(size: 15, weight: FontWeight.w700)
                  .copyWith(color: AppColors.expense),
            ),
          ),
          cell(
            'Total',
            CountUpMoney(
              amount: total,
              format: (v) =>
                  v >= 0 ? formatMoney(v) : '-${formatMoney(-v)}',
              style: AppTextStyles.amount(size: 15, weight: FontWeight.w700)
                  .copyWith(
                      color: total == 0
                          ? context.textMuted
                          : total > 0
                              ? AppColors.income
                              : AppColors.expense),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekdayHeader() {
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  _weekdays[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: i == 0
                        ? AppColors.expense
                        : context.textMuted,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // -------------------------------- grid --------------------------------

  Widget _grid(DateTime gridStart, Map<DateTime, _DayTotal> totals,
      DateTime todayKey) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.62,
      ),
      itemCount: 42,
      itemBuilder: (_, i) {
        final day = gridStart.add(Duration(days: i));
        final key = DateTime(day.year, day.month, day.day);
        final total = totals[key];
        return _dayCell(day, total, key == todayKey);
      },
    );
  }

  Widget _dayCell(DateTime day, _DayTotal? total, bool isToday) {
    final inMonth = day.month == _month.month;
    final isSunday = day.weekday == DateTime.sunday;
    final income = total?.income ?? 0;
    final expense = total?.expense ?? 0;
    final hasData = income > 0 || expense > 0;
    final net = income - expense;
    final muted = context.textMuted;
    final dimmed = inMonth ? 1.0 : 0.35;

    // "7/1" style label for the 1st, like classic money-manager apps.
    final dayLabel = day.day == 1
        ? '${day.month}/${day.day}'
        : '${day.day}';

    return InkWell(
      onTap: hasData ? () => _showDay(day, total!.items) : null,
      child: Opacity(
        opacity: dimmed,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: context.hairline, width: 0.5),
            color: isToday
                ? context.accent.withValues(alpha: 0.12)
                : null,
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dayLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isToday ? FontWeight.w800 : FontWeight.w600,
                  color: isToday
                      ? context.accent
                      : isSunday
                          ? AppColors.expense
                          : context.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              if (income > 0)
                Text(
                  formatAmountInput(income),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10, color: AppColors.income),
                ),
              if (expense > 0)
                Text(
                  '-${formatAmountInput(expense)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10, color: AppColors.expense),
                ),
              if (hasData)
                Text(
                  net >= 0
                      ? formatAmountInput(net)
                      : '-${formatAmountInput(-net)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10,
                      color: muted,
                      fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------- day sheet --------------------------------

  void _showDay(DateTime day, List<TransactionWithDetails> items) {
    var net = 0;
    for (final d in items) {
      final t = d.transaction;
      net += t.kind == 'income'
          ? t.amount
          : (t.kind == 'expense' ? -t.amount : 0);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Text(
                    DateFormat('d MMM yyyy').format(day),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const Spacer(),
                  net == 0
                      ? Text(formatMoney(0),
                          style: TextStyle(color: context.textMuted))
                      : AmountText(net.abs(),
                          isIncome: net > 0, size: 15),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: items.length,
                itemBuilder: (_, i) =>
                    TransactionTile(details: items[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
