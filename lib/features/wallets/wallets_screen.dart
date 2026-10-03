import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// Wallets grouped under a Personal / Work / Family account switcher.
class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final selectedAccount = ref.watch(selectedAccountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets'),
        actions: [
          IconButton(
            tooltip: 'Add wallet',
            onPressed: () => _addWalletDialog(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<List<Account>>(
        stream: db.watchAccounts(),
        builder: (context, accSnap) {
          final accounts = accSnap.data ?? const <Account>[];
          return StreamBuilder<List<Wallet>>(
            stream: db.watchWallets(accountId: selectedAccount),
            builder: (context, walSnap) {
              final wallets = walSnap.data ?? const <Wallet>[];
              final total = wallets.fold<int>(0, (s, w) => s + w.balance);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _accountChip(context, ref, null, 'All', selectedAccount == null),
                        for (final a in accounts)
                          _accountChip(context, ref, a.id, a.name, selectedAccount == a.id),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Combined balance',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(formatIDR(total),
                            style: AppTextStyles.displayBalance
                                .copyWith(fontSize: 32, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('${wallets.length} wallets',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (wallets.isEmpty)
                    const EmptyState(
                      icon: Icons.wallet_outlined,
                      message: 'No wallets here yet.',
                    )
                  else
                    for (final w in wallets) _walletCard(context, w),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _accountChip(BuildContext context, WidgetRef ref, int? id, String label, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.lime,
        labelStyle: TextStyle(
          color: selected ? Colors.black : Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => ref.read(selectedAccountProvider.notifier).select(id),
      ),
    );
  }

  Widget _walletCard(BuildContext context, Wallet w) {
    final color = colorFromHex(w.colorHex);
    final negative = w.balance < 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(_kindLabel(w.kind),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Text(
              formatIDR(w.balance),
              style: AppTextStyles.amount(size: 17).copyWith(
                color: negative ? AppColors.expense : AppColors.textPrimary,
              ),
            ),
          ],
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

  Future<void> _addWalletDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    String kind = 'cash';
    final accounts = await ref.read(databaseProvider).watchAccounts().first;
    int? accountId = accounts.isNotEmpty ? accounts.first.id : null;

    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add wallet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank account')),
                  DropdownMenuItem(value: 'ewallet', child: Text('E-wallet')),
                  DropdownMenuItem(value: 'credit', child: Text('Credit card')),
                ],
                onChanged: (v) => setState(() => kind = v ?? 'cash'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: accountId,
                decoration: const InputDecoration(labelText: 'Account'),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => accountId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (saved == true && nameCtrl.text.trim().isNotEmpty && accountId != null) {
      await ref.read(databaseProvider).addWallet(WalletsCompanion.insert(
            accountId: accountId!,
            name: nameCtrl.text.trim(),
            kind: kind,
          ));
    }
  }
}
