import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/section_header.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/transactions_screen.dart';
import '../transactions/widgets/transaction_tile.dart';
import 'widgets/ai_insight_card.dart';
import 'widgets/balance_card.dart';
import 'widgets/quick_actions.dart';
import 'widgets/stat_sparkline_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _balanceHidden = false;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final range = ref.watch(dateRangeProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context),
              const SizedBox(height: 12),
              BalanceCard(
                balanceHidden: _balanceHidden,
                onToggleHidden: () => setState(() => _balanceHidden = !_balanceHidden),
              ),
              const SizedBox(height: 12),
              _rangeSwitcher(context, range),
              const SizedBox(height: 12),
              StreamBuilder<List<Transaction>>(
                stream: db.watchTransactionsRaw(),
                builder: (context, snap) {
                  final txs = snap.data ?? const <Transaction>[];
                  final now = DateTime.now();
                  List<double> daily(String kind) {
                    return List.generate(7, (i) {
                      final day = DateTime(now.year, now.month, now.day)
                          .subtract(Duration(days: 6 - i));
                      return txs
                          .where((t) =>
                              t.kind == kind &&
                              t.date.year == day.year &&
                              t.date.month == day.month &&
                              t.date.day == day.day)
                          .fold<double>(0, (s, t) => s + t.amount)
                          .toDouble();
                    });
                  }

                  final from = _rangeStart(range);
                  final inRange = txs.where((t) => !t.date.isBefore(from));
                  final income = inRange
                      .where((t) => t.kind == 'income')
                      .fold<int>(0, (s, t) => s + t.amount);
                  final expense = inRange
                      .where((t) => t.kind == 'expense')
                      .fold<int>(0, (s, t) => s + t.amount);
                  return Row(
                    children: [
                      StatSparklineCard(
                        label: 'Income',
                        amount: income,
                        isIncome: true,
                        dailyTotals: daily('income'),
                      ),
                      const SizedBox(width: 12),
                      StatSparklineCard(
                        label: 'Expenses',
                        amount: expense,
                        isIncome: false,
                        dailyTotals: daily('expense'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const QuickActions(),
              const SizedBox(height: 16),
              const AiInsightCard(),
              SectionHeader(
                title: 'Recent transactions',
                action: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                  ),
                  child: const Text('See all'),
                ),
              ),
              StreamBuilder<List<TransactionWithDetails>>(
                stream: db.watchTransactions(limit: 8),
                builder: (context, snap) {
                  final items = snap.data ?? const <TransactionWithDetails>[];
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No transactions yet')),
                    );
                  }
                  return Column(
                    children: [for (final d in items) TransactionTile(details: d)],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.lime, AppColors.violet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(Icons.person, color: Colors.black),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Good evening,',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textMuted)),
              Text('Track every rupiah',
                  style: AppTextStyles.displaySection.copyWith(fontSize: 18)),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SearchScreen()),
          ),
          icon: const Icon(Icons.search),
        ),
        IconButton(
          onPressed: () {
            if (ref.read(lockEnabledProvider)) {
              ref.read(lockedProvider.notifier).lock();
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Enable Password protection in More to use the lock')),
              );
            }
          },
          icon: const Icon(Icons.lock_outline),
        ),
      ],
    );
  }

  Widget _rangeSwitcher(BuildContext context, String range) {
    return Center(
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'day', label: Text('Day')),
          ButtonSegment(value: 'week', label: Text('Week')),
          ButtonSegment(value: 'month', label: Text('Month')),
        ],
        selected: {range},
        onSelectionChanged: (s) =>
            ref.read(dateRangeProvider.notifier).set(s.first),
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  DateTime _rangeStart(String range) {
    final now = DateTime.now();
    switch (range) {
      case 'day':
        return DateTime(now.year, now.month, now.day);
      case 'week':
        return now.subtract(const Duration(days: 7));
      default:
        return now.subtract(const Duration(days: 30));
    }
  }
}
