import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../core/widgets/app_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../data/database/app_database.dart';
import '../../../state/providers.dart';
import '../transaction_detail_screen.dart';
import '../transaction_actions.dart';
import '../../debts/debt_detail_screen.dart';

/// Single transaction row: circular category icon, note + wallet,
/// and amount with the entry time (HH.mm).
/// Transfers render with a "From → To" subtitle.
/// Debt-linked entries show a debt badge and open the debt detail instead.
///
/// Swipe right to reveal Edit, swipe left to reveal Delete — tapping the
/// revealed action runs it (two steps, so a stray swipe can't fire anything).
/// Delete still offers the 5-second undo.
///
/// In [selectionMode] (bulk select), swipes are disabled, the leading icon
/// becomes a checkbox, tap toggles selection, and long-press also toggles.
class TransactionTile extends ConsumerWidget {
  const TransactionTile({
    super.key,
    required this.details,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelected,
  });

  final TransactionWithDetails details;

  /// Whether the surrounding list is in bulk-selection mode.
  final bool selectionMode;

  /// Whether this row is currently selected (only meaningful in
  /// [selectionMode]).
  final bool selected;

  /// Toggles this row's selection. Used for tap (in selection mode) and
  /// long-press (enters selection mode).
  final VoidCallback? onToggleSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = details.transaction;
    final c = details.category;
    final isTransfer = t.kind == 'transfer';
    final isIncome = t.kind == 'income';
    final isDebtLinked = t.debtId != null;
    final color = colorFromHex(c.colorHex);

    // Two-step swipe actions: the swipe only reveals the action — nothing
    // fires until the revealed button is tapped. The pane closes on scroll
    // or when another row is swiped.
    return Slidable(
      key: ValueKey('tx-${t.id}'),
      enabled: !selectionMode,
      closeOnScroll: true,
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.32,
        children: [
          SlidableAction(
            onPressed: (actionContext) async {
              Slidable.of(actionContext)?.close();
              Haptics.medium();
              await editTransaction(context, details);
            },
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            icon: Icons.edit_outlined,
            label: 'Edit',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.32,
        children: [
          SlidableAction(
            onPressed: (actionContext) async {
              Slidable.of(actionContext)?.close();
              Haptics.medium();
              await deleteTransactionFlow(context, ref, details);
            },
            backgroundColor: AppColors.expense,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Delete',
          ),
        ],
      ),
      child: InkWell(
        onTap: selectionMode
            ? onToggleSelected
            : () => Navigator.of(context).push(
                  AppPageRoute(
                    builder: (_) => isDebtLinked
                        ? DebtDetailScreen(debtId: t.debtId!)
                        : TransactionDetailScreen(
                            transactionId: t.id,
                            iconKey: c.iconKey,
                            colorHex: c.colorHex,
                            title: t.note.isEmpty ? c.name : t.note,
                          ),
                  ),
                ),
        onLongPress: onToggleSelected,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          children: [
            if (selectionMode)
              SizedBox(
                width: 46,
                height: 46,
                child: Checkbox(
                  value: selected,
                  onChanged: (_) => onToggleSelected?.call(),
                ),
              )
            else
              Hero(
                tag: 'tx-icon-${t.id}',
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.16),
                  ),
                  child: Icon(iconForKey(c.iconKey), color: color, size: 22),
                ),
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
                      details.wallet.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isTransfer)
                  Text(formatMoney(t.amount),
                      style: AppTextStyles.amount(size: 15))
                else
                  AmountText(t.amount, isIncome: isIncome, size: 15),
                const SizedBox(height: 2),
                Text(
                  formatTime(t.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ],
        ),
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
      return Text(details.wallet.name,
          style: TextStyle(fontSize: 12, color: muted));
    }
    return FutureBuilder<Wallet?>(
      future: ref
          .read(databaseProvider)
          .getWalletById(t.toWalletId!),
      builder: (context, snap) {
        final to = snap.data?.name ?? '…';
        return Text('${details.wallet.name} → $to',
            style: TextStyle(fontSize: 12, color: muted));
      },
    );
  }
}

