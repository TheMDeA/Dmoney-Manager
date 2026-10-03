import 'package:flutter/material.dart';

import '../../../core/utils/category_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../data/database/app_database.dart';
import '../transaction_detail_screen.dart';

/// Single transaction row: category icon tile, note, wallet + date, amount.
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.details});

  final TransactionWithDetails details;

  @override
  Widget build(BuildContext context) {
    final t = details.transaction;
    final c = details.category;
    final isIncome = t.kind == 'income';
    final color = colorFromHex(c.colorHex);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TransactionDetailScreen(transactionId: t.id),
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
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${details.wallet.name} · ${formatDate(t.date)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            AmountText(t.amount, isIncome: isIncome, size: 15),
          ],
        ),
      ),
    );
  }
}
