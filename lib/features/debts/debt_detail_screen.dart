import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/services/app_prefs.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/form_sheet.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'edit_debt_sheet.dart';
import 'record_payment_sheet.dart';

/// Detail view for one debt: received/left progress, info, payment history,
/// record-payment FAB, plus edit/delete.
class DebtDetailScreen extends ConsumerStatefulWidget {
  const DebtDetailScreen({super.key, required this.debtId});

  final int debtId;

  @override
  ConsumerState<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends ConsumerState<DebtDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debt'),
        actions: [
          IconButton(
            tooltip: 'Edit debt',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editDebt(context, db),
          ),
          IconButton(
            tooltip: 'Delete debt',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, db),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _recordPayment(context, db),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Debt>>(
        stream: db.watchDebts(),
        builder: (context, dSnap) {
          Debt? debt;
          for (final d in dSnap.data ?? const <Debt>[]) {
            if (d.id == widget.debtId) debt = d;
          }
          if (debt == null) {
            return Center(
              child: Text('Debt not found',
                  style: TextStyle(color: context.textMuted)),
            );
          }
          final d = debt;
          return StreamBuilder<List<DebtPayment>>(
            stream: db.watchDebtPayments(d.id),
            builder: (context, pSnap) {
              final payments = pSnap.data ?? const <DebtPayment>[];
              return StreamBuilder<List<Wallet>>(
                stream: db.watchWallets(),
                builder: (context, wSnap) {
                  final wallets = wSnap.data ?? const <Wallet>[];
                  Wallet? wallet;
                  for (final w in wallets) {
                    if (w.id == d.walletId) wallet = w;
                  }
                  return _content(context, db, d, payments, wallets, wallet);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _content(
    BuildContext context,
    AppDatabase db,
    Debt debt,
    List<DebtPayment> payments,
    List<Wallet> wallets,
    Wallet? wallet,
  ) {
    final received = payments.fold<int>(0, (s, p) => s + p.amount);
    final left = debt.amount - received;
    final ratio = debt.amount == 0 ? 0.0 : received / debt.amount;
    final receivable = debt.direction == 'receivable';
    final color = colorFromHex(debt.colorHex);
    final dateFmt = DateFormat('dd/MM/yyyy, HH.mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color,
                child: Text(
                  debt.person.characters.first.toUpperCase(),
                  style: TextStyle(
                      color: onAccent(color),
                      fontWeight: FontWeight.w700,
                      fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.person,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      receivable ? 'I lent' : 'I owe',
                      style: TextStyle(
                          color: context.textMuted, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _amountColumn(receivable ? 'Received' : 'Paid',
                  formatMoney(received), context.textMuted),
              _amountColumn('Left', formatMoney(left),
                  left < 0 ? AppColors.expense : context.textMuted),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 26,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                children: [
                  Container(color: context.raised),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: ratio.clamp(0.0, 1.0)),
                    duration: AppMotion.slow,
                    curve: AppMotion.enter,
                    builder: (context, v, _) => FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        color: debt.isPaid
                            ? AppColors.income
                            : AppColors.expense,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      '${(ratio * 100).toStringAsFixed(2).replaceAll('.', ',')}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _infoRow('Amount', formatMoney(debt.amount)),
          _infoRow('Date', dateFmt.format(debt.createdAt)),
          _infoRow('Wallet', wallet?.name ?? '—'),
          if (debt.note.isNotEmpty) _infoRow('Note', debt.note),
          const SizedBox(height: 28),
          Text(
            'Transactions',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (payments.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No transaction yet',
                    style: TextStyle(color: context.textMuted, fontSize: 15)),
              ),
            )
          else
            for (final p in payments) _paymentRow(context, db, debt, p, wallets),
        ],
      ),
    );
  }

  Widget _amountColumn(String label, String value, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.amount(size: 15)),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style:
                    TextStyle(color: context.textMuted, fontSize: 15)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _paymentRow(BuildContext context, AppDatabase db, Debt debt,
      DebtPayment p, List<Wallet> wallets) {
    Wallet? w;
    for (final x in wallets) {
      if (x.id == p.walletId) w = x;
    }
    final receivable = debt.direction == 'receivable';
    return Dismissible(
      key: ValueKey(p.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: AppColors.expense),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete payment?'),
            content: const Text(
                'The payment will be removed and the wallet balance adjusted back.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.expense),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await db.deleteDebtPayment(p, debt);
        }
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: (receivable ? AppColors.income : AppColors.expense)
                    .withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                receivable ? Icons.south_west : Icons.north_east,
                color: receivable ? AppColors.income : AppColors.expense,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.note.isNotEmpty ? p.note : 'Payment'),
                  Text(
                    '${formatDate(p.date)}${w != null ? ' · ${w.name}' : ''}',
                    style: TextStyle(
                        color: context.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '${receivable ? '+' : '-'}${formatMoney(p.amount)}',
              style: AppTextStyles.amount(size: 15).copyWith(
                  color:
                      receivable ? AppColors.income : AppColors.expense),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordPayment(BuildContext context, AppDatabase db) async {
    final debt = await db.getDebtById(widget.debtId);
    if (debt == null || !context.mounted) return;
    final result = await showFormSheet<DebtPaymentInput>(
      context,
      (_) => RecordPaymentSheet(debt: debt),
    );
    if (result != null && result.amount > 0) {
      await db.recordDebtPayment(
        debt: debt,
        amount: result.amount,
        date: result.date,
        note: result.note,
        walletId: result.walletId,
      );
    }
  }

  Future<void> _editDebt(BuildContext context, AppDatabase db) async {
    final debt = await db.getDebtById(widget.debtId);
    if (debt == null || !context.mounted) return;
    final result = await showFormSheet<DebtEditInput>(
      context,
      (_) => EditDebtSheet(debt: debt),
    );
    if (result == null || !context.mounted) return;
    await db.updateDebt(
      id: debt.id,
      person: result.person,
      note: result.note,
      amount: result.amount,
      dueDate: result.dueDate,
      walletId: result.walletId,
      recordAsTransaction: result.recordAsTransaction,
    );
    // Keep the reminder in sync with edits.
    if (result.dueDate != null && AppPrefs.debtReminders) {
      await NotificationService.scheduleDebtReminder(
        debtId: debt.id,
        person: result.person,
        amount: result.amount,
        payable: debt.direction == 'payable',
        dueDate: result.dueDate!,
      );
    } else {
      await NotificationService.cancelDebtReminder(debt.id);
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppDatabase db) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete debt?'),
        content: const Text(
            'The debt and its payment history will be removed, and wallet balances adjusted back.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.expense),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await NotificationService.cancelDebtReminder(widget.debtId);
      await db.deleteDebt(widget.debtId);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
