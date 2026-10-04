import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/empty_state.dart';
import '../../core/widgets/entrance.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'widgets/date_group_header.dart';
import 'widgets/month_overview.dart';
import 'widgets/month_selector.dart';
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

  Future<void> _pickMonth() async {
    final picked = await showMonthYearPicker(context, _month);
    if (picked != null) setState(() => _month = picked);
  }

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
            onPressed: _pickMonth,
          ),
        ],
      ),
      body: StreamBuilder<List<TransactionWithDetails>>(
        stream: db.watchTransactionsInRange(start, end),
        builder: (context, snap) {
          final items = snap.data ?? const <TransactionWithDetails>[];
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
          return Column(
            children: [
              MonthSelector(
                month: _month,
                onShift: _shift,
                onPick: _pickMonth,
              ),
              MonthOverview(income: income, expense: expense),
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
      children.add(DateGroupHeader(day: day, net: net));
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
}
