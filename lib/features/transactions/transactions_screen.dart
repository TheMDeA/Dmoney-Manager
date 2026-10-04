import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_accents.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/amount_text.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/entrance.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'widgets/transaction_tile.dart';

/// Transaction history: month pager, income/expense overview,
/// and transactions grouped by date with daily totals.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late DateTime _month =
      DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int delta) => setState(() {
        _month = DateTime(_month.year, _month.month + delta);
      });

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final start = DateTime(_month.year, _month.month);
    final end = DateTime(_month.year, _month.month + 1)
        .subtract(const Duration(seconds: 1));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: [
          IconButton(
            tooltip: 'Pick month',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => _pickMonth(context),
          ),
        ],
      ),
      body: StreamBuilder<List<TransactionWithDetails>>(
        stream: db.watchTransactionsInRange(start, end),
        builder: (context, snap) {
          final items = snap.data ?? const <TransactionWithDetails>[];
          return Column(
            children: [
              _monthSelector(context),
              _overview(items),
              Expanded(
                child: items.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        message:
                            'No transactions this month. Tap + to record one.',
                      )
                    : _groupedList(items),
              ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------- month --------------------------------

  Widget _monthSelector(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => _shift(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        GestureDetector(
          onTap: () => _pickMonth(context),
          child: Text(
            DateFormat('MMM yyyy').format(_month),
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        IconButton(
          onPressed: () => _shift(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (_) => _MonthPicker(initial: _month),
    );
    if (picked != null) setState(() => _month = picked);
  }

  // -------------------------------- overview --------------------------------

  Widget _overview(List<TransactionWithDetails> items) {
    var income = 0;
    var expense = 0;
    for (final d in items) {
      final t = d.transaction;
      if (t.kind == 'income') {
        income += t.amount;
      } else if (t.kind == 'expense') {
        expense += t.amount;
      }
    }
    final total = income - expense;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          _overviewRow(
            'Income',
            Text(formatMoney(income),
                style: TextStyle(
                    color: AppColors.income,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
          const SizedBox(height: 6),
          _overviewRow(
            'Expense',
            Text('-${formatMoney(expense)}',
                style: TextStyle(
                    color: AppColors.expense,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
          const SizedBox(height: 6),
          _overviewRow(
            'Total',
            total == 0
                ? Text(formatMoney(0),
                    style: TextStyle(
                        color: context.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 15))
                : AmountText(total.abs(),
                    isIncome: total > 0, size: 15),
          ),
        ],
      ),
    );
  }

  Widget _overviewRow(String label, Widget value) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                color: context.textMuted, fontSize: 14)),
        const Spacer(),
        value,
      ],
    );
  }

  // -------------------------------- groups --------------------------------

  Widget _groupedList(List<TransactionWithDetails> items) {
    // Items arrive newest-first; slice them into per-day groups.
    final children = <Widget>[];
    var i = 0;
    while (i < items.length) {
      final d0 = items[i].transaction.date;
      final day = DateTime(d0.year, d0.month, d0.day);
      var j = i;
      var net = 0;
      while (j < items.length) {
        final t = items[j].transaction;
        if (t.date.year != day.year ||
            t.date.month != day.month ||
            t.date.day != day.day) {
          break;
        }
        net += t.kind == 'income'
            ? t.amount
            : (t.kind == 'expense' ? -t.amount : 0);
        j++;
      }
      children.add(_dayHeader(day, net));
      for (var k = i; k < j; k++) {
        children.add(
          Entrance(
            key: ValueKey('tx-${items[k].transaction.id}'),
            delay: Duration(milliseconds: (40 * (k - i)).clamp(0, 320)),
            child: TransactionTile(details: items[k]),
          ),
        );
      }
      i = j;
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: children,
    );
  }

  Widget _dayHeader(DateTime day, int net) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            day.day.toString().padLeft(2, '0'),
            style: const TextStyle(
                fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE').format(day),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                DateFormat('MMM yyyy').format(day),
                style: TextStyle(
                    fontSize: 12, color: context.textMuted),
              ),
            ],
          ),
          const Spacer(),
          net == 0
              ? Text(formatMoney(0),
                  style: TextStyle(
                      color: context.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 15))
              : AmountText(net.abs(), isIncome: net > 0, size: 15),
        ],
      ),
    );
  }
}

/// Bottom-sheet month/year picker for the history screen.
class _MonthPicker extends StatefulWidget {
  const _MonthPicker({required this.initial});

  final DateTime initial;

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  static const _names = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '$_year',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18),
                ),
                IconButton(
                  onPressed: _year < now.year
                      ? () => setState(() => _year++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.8,
              ),
              itemCount: 12,
              itemBuilder: (_, m) {
                final selected = _year == widget.initial.year &&
                    m + 1 == widget.initial.month;
                final future =
                    _year > now.year || (_year == now.year && m + 1 > now.month);
                return Material(
                  color: selected
                      ? context.accent
                      : context.raised,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: future
                        ? null
                        : () => Navigator.of(context)
                            .pop(DateTime(_year, m + 1)),
                    child: Center(
                      child: Text(
                        _names[m],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : future
                                  ? context.textMuted.withValues(alpha: 0.4)
                                  : context.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
