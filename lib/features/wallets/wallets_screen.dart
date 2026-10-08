import 'package:flutter/material.dart';
import '../../core/theme/app_motion.dart';
import '../../core/widgets/coin_refresh_indicator.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/app_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ambient_glow.dart';
import '../../core/widgets/screen_header.dart';
import '../../core/theme/app_accents.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/count_up_money.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../transactions/add_transaction_sheet.dart';
import 'wallet_brands.dart';
import 'wallet_detail_screen.dart';
import 'wallet_form_sheet.dart';
import 'widgets/wallet_badge.dart';

/// Wallets grouped under a Personal / Work / Family account switcher,
/// rendered as a fanned card stack. Tapping a card focuses it: it slides
/// to the front and expands with quick actions and recent transactions.
class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final selectedAccount = ref.watch(selectedAccountProvider);

    return Scaffold(
      body: AmbientGlow(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: 'Wallets',
              tabIndex: 1,
              action: IconButton(
                tooltip: 'Add wallet',
                onPressed: () {
                  Haptics.select();
                  _addWalletDialog(context, ref);
                },
                icon: const Icon(Icons.add),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Account>>(
                stream: db.watchAccounts(),
                builder: (context, accSnap) {
                  final accounts = accSnap.data ?? const <Account>[];
                  return StreamBuilder<List<Wallet>>(
                    stream: db.watchWallets(accountId: selectedAccount),
                    builder: (context, walSnap) {
                      final wallets = walSnap.data ?? const <Wallet>[];
                      final total = wallets.fold<int>(
                        0,
                        (s, w) => s + w.balance,
                      );
                      return StreamBuilder<List<TransactionWithDetails>>(
                        stream: db.watchTransactions(limit: 60),
                        builder: (context, txSnap) {
                          final recent =
                              txSnap.data ?? const <TransactionWithDetails>[];
                          final recentByWallet =
                              <int, List<TransactionWithDetails>>{};
                          for (final d in recent) {
                            final list = recentByWallet.putIfAbsent(
                              d.transaction.walletId,
                              () => [],
                            );
                            if (list.length < 3) list.add(d);
                          }
                          return CoinRefreshIndicator(
                            onRefresh: () async {
                              Haptics.light();
                              await Future.delayed(
                                const Duration(milliseconds: 450),
                              );
                            },
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _accountChip(
                                        context,
                                        ref,
                                        null,
                                        'All',
                                        selectedAccount == null,
                                      ),
                                      for (final a in accounts)
                                        _accountChip(
                                          context,
                                          ref,
                                          a.id,
                                          a.name,
                                          selectedAccount == a.id,
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                GlassCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Combined balance',
                                        style: TextStyle(
                                          color: context.textMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      CountUpMoney(
                                        amount: total,
                                        style: AppTextStyles.displayBalance
                                            .copyWith(
                                              fontSize: 32,
                                              color: context.textPrimary,
                                            ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '${wallets.length} wallets · tap a card to focus it',
                                        style: TextStyle(
                                          color: context.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (wallets.isEmpty)
                                  EmptyState(
                                    icon: Icons.wallet_outlined,
                                    title: 'No wallets',
                                    message:
                                        'Add your first wallet to start tracking money.',
                                    actionLabel: 'Add wallet',
                                    onAction: () =>
                                        _addWalletDialog(context, ref),
                                  )
                                else
                                  Entrance(
                                    child: _WalletStack(
                                      wallets: wallets,
                                      recentByWallet: recentByWallet,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountChip(
    BuildContext context,
    WidgetRef ref,
    int? id,
    String label,
    bool selected,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: context.accent,
        labelStyle: TextStyle(
          color: selected
              ? Colors.black
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) =>
            ref.read(selectedAccountProvider.notifier).select(id),
      ),
    );
  }

  Future<void> _addWalletDialog(BuildContext context, WidgetRef ref) =>
      showWalletFormSheet(context, ref);
}

/// Fanned card stack of wallets. Tapping a card brings it to the front
/// and expands it with actions and recent transactions; tapping it
/// again (or another card) returns to / switches the focus.
class _WalletStack extends ConsumerStatefulWidget {
  const _WalletStack({required this.wallets, required this.recentByWallet});

  final List<Wallet> wallets;
  final Map<int, List<TransactionWithDetails>> recentByWallet;

  @override
  ConsumerState<_WalletStack> createState() => _WalletStackState();
}

class _WalletStackState extends ConsumerState<_WalletStack> {
  static const _cardH = 188.0;
  static const _peek = 88.0;
  static const _focusedH = 420.0;
  static const _tuck = 54.0;

  int? _focusedId;

  @override
  Widget build(BuildContext context) {
    final wallets = widget.wallets;
    final n = wallets.length;
    final focusedIndex = _focusedId == null
        ? -1
        : wallets.indexWhere((w) => w.id == _focusedId);
    final focused = focusedIndex >= 0;

    // Paint order: bottom cards first so the front card paints last.
    final order = <int>[];
    if (!focused) {
      for (var i = n - 1; i >= 0; i--) {
        order.add(i);
      }
    } else {
      for (var i = n - 1; i >= 0; i--) {
        if (i != focusedIndex) order.add(i);
      }
      order.add(focusedIndex);
    }

    var tuckOrder = 0;
    final stackH = focused
        ? 8 + _focusedH + 16 + _tuck * (n - 1) + 76
        : 8 + _cardH + _peek * (n - 1) + 20;

    return SizedBox(
      height: stackH,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (final i in order)
            Builder(
              builder: (context) {
                final w = wallets[i];
                final isFocused = focused && i == focusedIndex;
                final double top;
                if (!focused) {
                  top = 8 + i * _peek;
                } else if (isFocused) {
                  top = 8;
                } else {
                  top = 8 + _focusedH + 16 + (tuckOrder++) * _tuck;
                }
                return AnimatedPositioned(
                  key: ValueKey(w.id),
                  duration: AppMotion.slow,
                  curve: AppMotion.enter,
                  top: top,
                  left: 0,
                  right: 0,
                  height: isFocused ? _focusedH : _cardH,
                  child: AnimatedOpacity(
                    duration: AppMotion.normal,
                    opacity: focused && !isFocused ? 0.55 : 1.0,
                    child: _stackCard(context, w, isFocused),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _stackCard(BuildContext context, Wallet w, bool focused) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = colorFromHex(w.colorHex);
    final brand = walletBrandForWallet(
      logoTemplate: w.logoTemplate,
      kind: w.kind,
    );
    final negative = w.balance < 0;
    final recent = widget.recentByWallet[w.id] ?? const <TransactionWithDetails>[];
    final last = recent.isNotEmpty ? recent.first : null;

    return GestureDetector(
      onTap: () {
        Haptics.select();
        setState(() => _focusedId = focused ? null : w.id);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.38 : 0.3),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Color.lerp(const Color(0xFF1D1F22), color, 0.16)!,
                      const Color(0xFF131416),
                    ]
                  : [
                      Color.lerp(Colors.white, color, 0.14)!,
                      Colors.white,
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.28 : 0.2),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Brand accent bar, like a card's edge stripe.
              Positioned(
                left: 0,
                top: 22,
                bottom: 22,
                child: Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.8),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      w.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (focused) ...[
                                    const SizedBox(width: 4),
                                    _editButton(w),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _kindLabel(w.kind),
                                style: TextStyle(
                                  color: context.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Hero(
                          tag: 'wallet-${w.id}',
                          child: WalletBadge(brand: brand),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    CountUpMoney(
                      amount: w.balance,
                      style: AppTextStyles.amount(size: 26).copyWith(
                        color: negative
                            ? AppColors.expense
                            : context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (last != null)
                      Text(
                        '${last.transaction.note.isEmpty ? last.category.name : last.transaction.note} · ${formatDate(last.transaction.date)}',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        'No transactions yet',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    if (focused) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _action(
                            context,
                            icon: Icons.swap_horiz,
                            label: 'Transfer',
                            onTap: () => _transfer(w),
                          ),
                          const SizedBox(width: 10),
                          _action(
                            context,
                            icon: Icons.add_card_outlined,
                            label: 'Top up',
                            onTap: () => _topUp(w),
                          ),
                          const SizedBox(width: 10),
                          _action(
                            context,
                            icon: Icons.history,
                            label: 'History',
                            onTap: () => _history(w),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 1,
                        color: context.textMuted.withValues(alpha: 0.18),
                      ),
                      const SizedBox(height: 4),
                      for (final d in recent)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.transaction.note.isEmpty
                                          ? d.category.name
                                          : d.transaction.note,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      formatDate(d.transaction.date),
                                      style: TextStyle(
                                        color: context.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatMoney(_signedAmount(d)),
                                style: AppTextStyles.amount(size: 13.5)
                                    .copyWith(
                                      color: _amountColor(d),
                                    ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editButton(Wallet w) {
    return GestureDetector(
      onTap: () {
        Haptics.select();
        showWalletFormSheet(context, ref, existing: w);
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.edit_outlined,
          size: 16,
          color: context.textMuted,
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Haptics.select();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: context.textMuted.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.textMuted.withValues(alpha: 0.14),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: context.accent),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _transfer(Wallet w) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTransactionSheet(
        initialKind: 'transfer',
        initialWalletId: w.id,
      ),
    );
  }

  void _topUp(Wallet w) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTransactionSheet(
        initialKind: 'income',
        initialWalletId: w.id,
      ),
    );
  }

  void _history(Wallet w) {
    Navigator.of(
      context,
    ).push(AppPageRoute(builder: (_) => WalletDetailScreen(walletId: w.id)));
  }

  int _signedAmount(TransactionWithDetails d) {
    final a = d.transaction.amount;
    return d.transaction.kind == 'expense' ? -a : a;
  }

  Color _amountColor(TransactionWithDetails d) {
    return switch (d.transaction.kind) {
      'expense' => AppColors.expense,
      'income' => AppColors.income,
      _ => context.textPrimary,
    };
  }

  String _kindLabel(String kind) => switch (kind) {
    'cash' => 'Cash',
    'bank' => 'Bank account',
    'ewallet' => 'E-wallet',
    'credit' => 'Credit card',
    _ => kind,
  };
}
