import 'package:flutter/material.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/app_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_accents.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/section_header.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/add_transaction_sheet.dart';
import '../transactions/transfer_sheet.dart';
import '../transactions/transactions_screen.dart';
import '../transactions/widgets/transaction_tile.dart';
import 'widgets/ai_insight_card.dart';
import 'widgets/balance_card.dart';
import 'widgets/goal_spotlight_card.dart';
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
              StreamBuilder<List<KindTotal>>(
                stream: db.watchKindTotals(
                    _rangeStart(range), DateTime.now()),
                builder: (context, kindSnap) {
                  final kinds = {
                    for (final k
                        in (kindSnap.data ?? const <KindTotal>[]))
                      k.kind: k.total,
                  };
                  final income = kinds['income'] ?? 0;
                  final expense = kinds['expense'] ?? 0;
                  if (range == 'day') {
                    return StreamBuilder<List<HourlyTotal>>(
                      stream: db.watchHourlyKindTotals(
                          _rangeStart(range), DateTime.now()),
                      builder: (context, hourlySnap) {
                        final hourly =
                            hourlySnap.data ?? const <HourlyTotal>[];
                        List<double> buckets(String kind) =>
                            List.generate(24, (h) {
                          final key = h.toString().padLeft(2, '0');
                          return hourly
                              .where((t) =>
                                  t.hour == key && t.kind == kind)
                              .fold<double>(0, (s, t) => s + t.total)
                              .toDouble();
                        });
                        return _sparkRow(income, expense,
                            buckets('income'), buckets('expense'));
                      },
                    );
                  }
                  return StreamBuilder<List<DailyTotal>>(
                    stream: db.watchDailyKindTotals(
                        _rangeStart(range), DateTime.now()),
                    builder: (context, dailySnap) {
                      final now = DateTime.now();
                      final midnight = DateTime(
                          now.year, now.month, now.day);
                      final days = range == 'week' ? 7 : 30;
                      final dailyTotals =
                          dailySnap.data ?? const <DailyTotal>[];
                      List<double> buckets(String kind) =>
                          List.generate(days, (i) {
                        final day = midnight.subtract(
                            Duration(days: days - 1 - i));
                        final key =
                            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                        return dailyTotals
                            .where((t) => t.day == key && t.kind == kind)
                            .fold<double>(0, (s, t) => s + t.total)
                            .toDouble();
                      });
                      return _sparkRow(income, expense,
                          buckets('income'), buckets('expense'));
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              QuickActions(
                onTransfer: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const TransferSheet(),
                ),
                onTopUp: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) =>
                      const AddTransactionSheet(initialKind: 'income'),
                ),
                onScan: _scanReceipt,
                onMore: () => ref.read(tabIndexProvider.notifier).go(5),
              ),
              const SizedBox(height: 16),
              const GoalSpotlightCard(),
              const AiInsightCard(),
              SectionHeader(
                title: 'Recent transactions',
                action: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    AppPageRoute(builder: (_) => const TransactionsScreen()),
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
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Entrance(
                          key: ValueKey(items[i].transaction.id),
                          delay: Duration(milliseconds: (i * 60).clamp(0, 300)),
                          child: TransactionTile(details: items[i]),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanReceipt() async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.camera);
      if (picked == null || !mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => AddTransactionSheet(attachedPhotoPath: picked.path),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open camera: $e')),
        );
      }
    }
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [context.accent, AppColors.violet],
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
              Text(_greeting(),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.textMuted)),
              Text(ref.watch(displayNameProvider),
                  style: AppTextStyles.displaySection.copyWith(fontSize: 18)),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).push(
            AppPageRoute(builder: (_) => const SearchScreen()),
          ),
          icon: const Icon(Icons.search),
        ),
        IconButton(
          onPressed: () {
            if (ref.read(lockEnabledProvider)) {
              ref.read(lockedProvider.notifier).lock();
            } else {
              Navigator.of(context).push(
                AppPageRoute(builder: (_) => const SettingsScreen()),
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

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Good morning,';
    if (h < 15) return 'Good afternoon,';
    if (h < 19) return 'Good evening,';
    return 'Good night,';
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

  Widget _sparkRow(int income, int expense, List<double> incomeBuckets,
      List<double> expenseBuckets) {
    return Row(
      children: [
        StatSparklineCard(
          label: 'Income',
          amount: income,
          isIncome: true,
          dailyTotals: incomeBuckets,
        ),
        const SizedBox(width: 12),
        StatSparklineCard(
          label: 'Expenses',
          amount: expense,
          isIncome: false,
          dailyTotals: expenseBuckets,
        ),
      ],
    );
  }

  /// Midnight-aligned range start so the headline amounts and the sparkline
  /// buckets cover exactly the same period.
  DateTime _rangeStart(String range) {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    switch (range) {
      case 'day':
        return midnight;
      case 'week':
        return midnight.subtract(const Duration(days: 6));
      default:
        return midnight.subtract(const Duration(days: 29));
    }
  }
}
