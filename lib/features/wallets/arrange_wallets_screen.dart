import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/app_page_route.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'wallet_brands.dart';
import 'widgets/wallet_badge.dart';

/// Arrange Wallets: drag-to-reorder mini wallet cards. The order is
/// persisted via [AppDatabase.reorderWallets] and reflected immediately
/// in the card stack on the Wallets page. Shows all wallets regardless
/// of the account filter, so the global order is always what you see.
class ArrangeWalletsScreen extends ConsumerWidget {
  const ArrangeWalletsScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      AppPageRoute(builder: (_) => const ArrangeWalletsScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Arrange Wallets')),
      body: StreamBuilder<List<Wallet>>(
        stream: db.watchWallets(),
        builder: (context, snap) {
          final wallets = snap.data ?? const <Wallet>[];
          if (wallets.isEmpty) {
            return const EmptyState(
              icon: Icons.wallet_outlined,
              title: 'No wallets yet',
              message: 'Add a wallet first, then arrange them here.',
            );
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: wallets.length,
            onReorderStart: (_) => Haptics.light(),
            onReorderEnd: (_) => Haptics.light(),
            onReorderItem: (oldIndex, newIndex) async {
              final reordered = wallets.toList();
              final moved = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, moved);
              await db.reorderWallets(
                [for (final w in reordered) w.id],
              );
            },
            itemBuilder: (context, i) =>
                _walletRow(context, wallets[i], i),
          );
        },
      ),
    );
  }

  /// Mini wallet card: drag handle, brand color edge stripe, name +
  /// balance, and a compact logo badge. Explicit Row layout (no ListTile)
  /// so the badge can never squeeze the name out.
  Widget _walletRow(BuildContext context, Wallet w, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = colorFromHex(w.colorHex);
    final brand = walletBrandForWallet(
      logoTemplate: w.logoTemplate,
      kind: w.kind,
    );
    return Container(
      key: ValueKey(w.id),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.drag_indicator,
                color: context.textMuted,
              ),
            ),
          ),
          // Brand edge stripe, like the stack cards.
          Container(
            width: 5,
            height: 56,
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(3),
                left: Radius.circular(3),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    w.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatMoney(w.balance),
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: WalletBadge(brand: brand, height: 28),
          ),
        ],
      ),
    );
  }
}
