import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../transactions/widgets/grouped_transaction_list.dart';

/// Category drill-down from the wallet detail screen: one category's
/// transactions for the wallet, grouped by date, with an overview total.
/// "View all" on the wallet screen still opens the full month-paged list.
///
/// The category's display info (name/icon/color) is passed in so the app
/// bar — including the hero icon shared with the wallet detail screen —
/// renders synchronously, without waiting for the transaction stream.
class WalletCategoryScreen extends ConsumerWidget {
  const WalletCategoryScreen({
    super.key,
    required this.walletId,
    required this.categoryId,
    required this.categoryName,
    required this.iconKey,
    required this.colorHex,
  });

  final int walletId;
  final int categoryId;
  final String categoryName;
  final String iconKey;
  final String colorHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final catColor = colorFromHex(colorHex);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'walletcat-$walletId-$categoryId',
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(iconForKey(iconKey), color: catColor, size: 18),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(child: Text(categoryName)),
          ],
        ),
      ),
      body: StreamBuilder<List<TransactionWithDetails>>(
        stream:
            db.watchTransactionsForWalletAndCategory(walletId, categoryId),
        builder: (context, snap) {
          final items = snap.data ?? const <TransactionWithDetails>[];
          final isIncome = items.isNotEmpty &&
              items.first.transaction.kind == 'income';
          final total =
              items.fold<int>(0, (s, d) => s + d.transaction.amount);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: const SectionHeader(title: 'Overview'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Entrance(
                  child: GlassCard(
                    child: Row(
                      children: [
                        const Text('Total',
                            style: TextStyle(fontSize: 15)),
                        const Spacer(),
                        Text(
                          formatSignedMoney(total, isIncome: isIncome),
                          style:
                              AppTextStyles.amount(size: 17).copyWith(
                            color: isIncome
                                ? AppColors.income
                                : AppColors.expense,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: !snap.hasData
                    ? const SkeletonTransactionList()
                    : items.isEmpty
                        ? const EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'No transactions',
                            message:
                                'Nothing recorded in this category yet.',
                          )
                        : GroupedTransactionList(items: items),
              ),
            ],
          );
        },
      ),
    );
  }
}
