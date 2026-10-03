import 'package:flutter/material.dart';
import '../../../core/widgets/app_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../data/database/app_database.dart';
import '../../../state/providers.dart';
import '../transaction_detail_screen.dart';
import '../../debts/debt_detail_screen.dart';

/// Single transaction row: category icon tile, note, wallet + date, amount.
/// Transfers render with a swap icon and "From → To" subtitle.
/// Debt-linked entries show a debt badge and open the debt detail instead.
class TransactionTile extends ConsumerWidget {
  const TransactionTile({super.key, required this.details});

  final TransactionWithDetails details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = details.transaction;
    final c = details.category;
    final isTransfer = t.kind == 'transfer';
    final isIncome = t.kind == 'income';
    final isDebtLinked = t.debtId != null;
    final color = colorFromHex(c.colorHex);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        AppPageRoute(
          builder: (_) => isDebtLinked
              ? DebtDetailScreen(debtId: t.debtId!)
              : TransactionDetailScreen(transactionId: t.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(iconForKey(c.iconKey), color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.note.isEmpty ? c.name : t.note,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (isTransfer)
                    _transferSubtitle(context, ref, t)
                  else
                    Text(
                      '${details.wallet.name} · ${formatDate(t.date)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                  if (isDebtLinked)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.handshake_outlined,
                            size: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.55),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Debt',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (isTransfer)
              Text(formatMoney(t.amount), style: AppTextStyles.amount(size: 15))
            else
              AmountText(t.amount, isIncome: isIncome, size: 15),
          ],
        ),
      ),
    );
  }

  Widget _transferSubtitle(BuildContext context, WidgetRef ref, Transaction t) {
    final muted = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: 0.55);
    if (t.toWalletId == null) {
      return Text('${details.wallet.name} · ${formatDate(t.date)}',
          style: TextStyle(fontSize: 12, color: muted));
    }
    return FutureBuilder<Wallet?>(
      future: ref
          .read(databaseProvider)
          .getWalletById(t.toWalletId!),
      builder: (context, snap) {
        final to = snap.data?.name ?? '…';
        return Text('${details.wallet.name} → $to · ${formatDate(t.date)}',
            style: TextStyle(fontSize: 12, color: muted));
      },
    );
  }
}

