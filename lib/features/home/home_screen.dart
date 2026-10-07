import 'package:flutter/material.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/sliding_segmented.dart';
import '../../core/widgets/app_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ambient_glow.dart';
import '../../core/theme/app_accents.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/section_header.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../accounts/account_switcher_sheet.dart';
import '../debts/add_debt_sheet.dart';
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
    final accountId = ref.watch(selectedAccountProvider);

    return Scaffold(
      body: AmbientGlow(
        child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context),
                  const SizedBox(height: 12),
                  BalanceCard(
                    balanceHidden: _balanceHidden,
                    onToggleHidden: () {
                      Haptics.light();
                      setState(() => _balanceHidden = !_balanceHidden);
                    },
                  ),
                  const SizedBox(height: 12),
                  _rangeSwitcher(context, range),
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
                    onDebt: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => const AddDebtSheet(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const GoalSpotlightCard(),
                  const AiInsightCard(),
                  SectionHeader(
                    title: 'Recent transactions',
                    action: TextButton(
                      onPressed: () {
                        Haptics.select();
                        Navigator.of(context).push(
                          AppPageRoute(
                            builder: (_) => const TransactionsScreen(),
                          ),
                        );
                      },
                      child: const Text('View all'),
                    ),
                  ),
                  StreamBuilder<List<TransactionWithDetails>>(
                    stream: db.watchTransactions(
                      limit: 8,
                      accountId: accountId,
                    ),
                    builder: (context, snap) {
                      final items =
                          snap.data ?? const <TransactionWithDetails>[];
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
                              delay: Duration(
                                milliseconds: (i * 60).clamp(0, 300),
                              ),
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
        ),
    );
  }

  Future<void> _scanReceipt() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera);
      if (picked == null || !mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => AddTransactionSheet(attachedPhotoPath: picked.path),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open camera: $e')));
      }
    }
  }

  Account? _accountById(List<Account> accounts, int? id) {
    if (id == null) return null;
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  Widget _header(BuildContext context) {
    final selectedAccountId = ref.watch(selectedAccountProvider);
    final db = ref.watch(databaseProvider);
    return Row(
      children: [
        StreamBuilder<List<Account>>(
          stream: db.watchAccounts(),
          builder: (context, snap) {
            final accounts = snap.data ?? const <Account>[];
            final selected = _accountById(accounts, selectedAccountId);
            final ringColor = selected == null
                ? null
                : colorFromHex(selected.colorHex);
            return GestureDetector(
              onTap: () {
                Haptics.select();
                showAccountSwitcherSheet(context);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [context.accent, AppColors.violet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: ringColor == null
                      ? null
                      : Border.all(color: ringColor, width: 3),
                ),
                child: const Icon(Icons.person, color: Colors.black),
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.textMuted),
              ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      ref.watch(displayNameProvider),
                      style: AppTextStyles.displaySection.copyWith(
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (selectedAccountId != null)
                    StreamBuilder<List<Account>>(
                      stream: db.watchAccounts(),
                      builder: (context, snap) {
                        final accounts = snap.data ?? const <Account>[];
                        final selected = _accountById(
                          accounts,
                          selectedAccountId,
                        );
                        if (selected == null) {
                          return const SizedBox.shrink();
                        }
                        final color = colorFromHex(selected.colorHex);
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: color.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              selected.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            Haptics.select();
            Navigator.of(
              context,
            ).push(AppPageRoute(builder: (_) => const SearchScreen()));
          },
          icon: const Icon(Icons.search),
        ),
        IconButton(
          onPressed: () {
            Haptics.select();
            if (ref.read(lockEnabledProvider)) {
              ref.read(lockedProvider.notifier).lock();
            } else {
              Navigator.of(
                context,
              ).push(AppPageRoute(builder: (_) => const SettingsScreen()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Enable Password protection in More to use the lock',
                  ),
                ),
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
      child: SlidingSegmented<String>(
        values: const ['day', 'week', 'month'],
        labels: const ['Day', 'Week', 'Month'],
        selected: range,
        onChanged: (v) {
          Haptics.select();
          ref.read(dateRangeProvider.notifier).set(v);
        },
      ),
    );
  }
}
