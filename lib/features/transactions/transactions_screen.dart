import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/empty_state.dart';
import '../../core/widgets/month_scrubber.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/utils/haptics.dart';
import 'add_transaction_sheet.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'widgets/grouped_transaction_list.dart';
import 'widgets/month_overview.dart';
import 'widgets/month_selector.dart';

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
                child: !snap.hasData
                    ? const SkeletonTransactionList()
                    : items.isEmpty
                        ? EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'No transactions',
                            message:
                                'Nothing recorded this month yet.',
                            actionLabel: 'Add transaction',
                            onAction: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) =>
                                  const AddTransactionSheet(),
                            ),
                          )
                        : MonthScrubber(
                            month: _month,
                            onShift: _shift,
                            child: RefreshIndicator(
                              onRefresh: () async {
                                Haptics.light();
                                // Local-first data: the streams are already live.
                                // The gesture still gets its satisfying snap.
                                await Future.delayed(
                                    const Duration(milliseconds: 450));
                              },
                              child: GroupedTransactionList(items: items),
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}
