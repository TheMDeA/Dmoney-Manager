import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/section_header.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../transactions/widgets/grouped_transaction_list.dart';

/// Category drill-down from the wallet detail screen: one category's
/// transactions for the wallet, grouped by date, with an overview total.
/// "View all" on the wallet screen still opens the full month-paged list.
class WalletCategoryScreen extends ConsumerWidget {
  const WalletCategoryScreen({
    super.key,
    required this.walletId,
    required this.categoryId,
  });

  final int walletId;
  final int categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<TransactionWithDetails>>(
      stream: db.watchTransactionsForWalletAndCategory(walletId, categoryId),
      builder: (context, snap) {
        final items = snap.data ?? const <TransactionWithDetails>[];
        final name =
            items.isNotEmpty ? items.first.category.name : 'Category';
        final isIncome = items.isNotEmpty &&
            items.first.transaction.kind == 'income';
        final total =
            items.fold<int>(0, (s, d) => s + d.transaction.amount);
        return Scaffold(
          appBar: AppBar(title: Text(name)),
          body: Column(
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
                child: items.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        message: 'No transactions in this category.',
                      )
                    : groupedTransactionList(items),
              ),
            ],
          ),
        );
      },
    );
  }
}
