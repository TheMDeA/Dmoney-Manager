import 'package:flutter/material.dart';
import '../../core/theme/app_motion.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/app_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ambient_glow.dart';
import '../../core/widgets/screen_header.dart';
import '../../core/theme/app_accents.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/count_up_money.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/pressable.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'wallet_detail_screen.dart';
import 'wallet_form_sheet.dart';

/// Wallets grouped under a Personal / Work / Family account switcher.
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
              action: IconButton(
                tooltip: 'Add wallet',
                onPressed: () => _addWalletDialog(context, ref),
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
                          final lastByWallet = <int, TransactionWithDetails>{};
                          for (final d in recent) {
                            lastByWallet.putIfAbsent(
                              d.transaction.walletId,
                              () => d,
                            );
                          }
                          return RefreshIndicator(
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
                                        '${wallets.length} wallets',
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
                                  for (var i = 0; i < wallets.length; i++)
                                    Entrance(
                                      key: ValueKey(wallets[i].id),
                                      delay: Duration(
                                        milliseconds: (i * 60).clamp(0, 300),
                                      ),
                                      child: _walletCard(
                                        context,
                                        wallets[i],
                                        lastByWallet[wallets[i].id],
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

  Widget _walletCard(
    BuildContext context,
    Wallet w,
    TransactionWithDetails? last,
  ) {
    final color = colorFromHex(w.colorHex);
    final negative = w.balance < 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Pressable(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            AppPageRoute(builder: (_) => WalletDetailScreen(walletId: w.id)),
          ),
          // Long-press peeks at the wallet's key figures without opening it.
          onLongPress: () => _peekWallet(context, w, last),
          child: GlassCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Hero(
                  tag: 'wallet-${w.id}',
                  child: Container(
                    width: 6,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _kindLabel(w.kind),
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (last != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${last.transaction.note.isEmpty ? last.category.name : last.transaction.note} · ${formatDate(last.transaction.date)}',
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                CountUpMoney(
                  amount: w.balance,
                  style: AppTextStyles.amount(size: 17).copyWith(
                    color: negative ? AppColors.expense : context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _kindLabel(String kind) => switch (kind) {
    'cash' => 'Cash',
    'bank' => 'Bank account',
    'ewallet' => 'E-wallet',
    'credit' => 'Credit card',
    _ => kind,
  };

  String _walletIconKey(String kind) => switch (kind) {
    'bank' => 'account_balance',
    'ewallet' => 'smartphone',
    'credit' => 'credit_card',
    _ => 'wallet',
  };

  Future<void> _addWalletDialog(BuildContext context, WidgetRef ref) =>
      showWalletFormSheet(context, ref);

  /// Long-press peek: a compact sheet with the wallet's key figures,
  /// popping in with a springy scale. Dismiss by tapping outside.
  Future<void> _peekWallet(
    BuildContext context,
    Wallet w,
    TransactionWithDetails? last,
  ) {
    Haptics.medium();
    final color = colorFromHex(w.colorHex);
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1.0),
          duration: AppMotion.normal,
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        iconForKey(_walletIconKey(w.kind)),
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
                            w.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
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
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Balance',
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  formatMoney(w.balance),
                  style: AppTextStyles.displayBalance.copyWith(
                    fontSize: 30,
                    color: w.balance < 0
                        ? AppColors.expense
                        : context.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _peekRow('Initial amount', formatMoney(w.initialAmount)),
                if (last != null)
                  _peekRow(
                    'Last transaction',
                    '${last.transaction.note.isEmpty ? last.category.name : last.transaction.note} · ${formatDate(last.transaction.date)}',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _peekRow(String label, String value) {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(color: context.textMuted, fontSize: 13),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
