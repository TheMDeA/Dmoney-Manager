import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_prefs.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/paylater.dart';
import '../../core/widgets/app_page_route.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'wallet_detail_screen.dart';

/// Full Paylater dashboard, opened from the Paylater summary card on the
/// Wallets screen. Shows what is owed across all paylater wallets, what
/// comes due next, installment plans, this month's paylater spending,
/// and the freeze toggle.
///
/// Interest and fee totals are deliberately absent: the data model
/// records no interest rows, so no such number is shown rather than
/// inventing one. The tenor calculator in the add-transaction sheet is
/// the only place interest appears, and only as a quote from the
/// wallet's own rate.
class PaylaterDashboardScreen extends ConsumerStatefulWidget {
  const PaylaterDashboardScreen({super.key});

  static void open(BuildContext context) {
    Navigator.push(
      context,
      AppPageRoute(builder: (_) => const PaylaterDashboardScreen()),
    );
  }

  @override
  ConsumerState<PaylaterDashboardScreen> createState() =>
      _PaylaterDashboardScreenState();
}

class _PaylaterDashboardScreenState
    extends ConsumerState<PaylaterDashboardScreen> {
  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Paylater')),
      body: StreamBuilder<List<Wallet>>(
        stream: db.watchWallets(),
        builder: (context, walSnap) {
          final wallets = walSnap.data ?? const <Wallet>[];
          final paylater = paylaterWallets(wallets);
          if (paylater.isEmpty) {
            return const EmptyState(
              icon: Icons.credit_card_outlined,
              title: 'No paylater wallets',
              message:
                  'Add a paylater wallet from the Wallets screen to track what you owe here.',
            );
          }
          final outstanding = totalPaylaterOutstanding(wallets);
          final ratio = paylaterLimitUsedRatio(wallets);
          final next = nextPaylaterDue(wallets, now);
          final dueCycle = dueThisCycle(wallets, now);
          final monthStart = DateTime(now.year, now.month, 1);
          final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          return StreamBuilder<List<InstallmentPlan>>(
            stream: db.watchInstallmentPlans(),
            builder: (context, planSnap) {
              final plans = planSnap.data ?? const <InstallmentPlan>[];
              return StreamBuilder<List<TransactionWithDetails>>(
                stream: db.watchTransactionsInRange(monthStart, monthEnd),
                builder: (context, txSnap) {
                  final monthTxs = txSnap.data ?? const <TransactionWithDetails>[];
                  final paylaterIds = paylater.map((w) => w.id).toSet();
                  final monthSpending = monthTxs
                      .where(
                        (d) =>
                            paylaterIds.contains(d.transaction.walletId) &&
                            d.transaction.kind == 'expense',
                      )
                      .fold(0, (s, d) => s + d.transaction.amount);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _heroCard(outstanding, dueCycle, ratio),
                      const SizedBox(height: 12),
                      if (next != null) ...[
                        _nextDueCard(next.wallet, next.dueDate, wallets),
                        const SizedBox(height: 12),
                      ],
                      const _SectionLabel('Providers'),
                      const SizedBox(height: 8),
                      for (final w in paylater) ...[
                        _providerCard(w),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 12),
                      _plansSection(plans, paylater),
                      const SizedBox(height: 12),
                      _costsCard(monthSpending),
                      const SizedBox(height: 12),
                      _freezeCard(),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _heroCard(int outstanding, int dueCycle, double? ratio) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total outstanding',
            style: TextStyle(color: context.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(outstanding),
            style: AppTextStyles.displayBalance.copyWith(
              fontSize: 32,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _heroStat('Due this cycle', formatMoney(dueCycle)),
              ),
              Expanded(
                child: _heroStat(
                  'Limit used',
                  ratio == null ? 'No limit set' : '${(ratio * 100).round()}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.textMuted, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _nextDueCard(Wallet wallet, DateTime dueDate, List<Wallet> wallets) {
    final amount = paylaterOutstanding(wallet);
    return GlassCard(
      glowColor: context.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next due',
            style: TextStyle(color: context.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            wallet.name,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${formatMoney(amount)} · due ${formatDate(dueDate)}',
            style: TextStyle(color: context.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _payDue(wallet, wallets),
              child: const Text('Mark as paid'),
            ),
          ),
        ],
      ),
    );
  }

  /// Pays [wallet]'s full outstanding amount from a wallet the user picks.
  /// Recorded as a transfer — the same primitive the transfer sheet uses —
  /// so the paylater balance moves back toward zero and the payment shows
  /// up in history. Afterwards the reminder is cancelled when nothing is
  /// owed anymore, or rescheduled with the new amount.
  Future<void> _payDue(Wallet wallet, List<Wallet> allWallets) async {
    final db = ref.read(databaseProvider);
    final amount = paylaterOutstanding(wallet);
    if (amount <= 0) return;
    final payers = allWallets.where((w) => w.kind != 'paylater').toList();
    if (payers.isEmpty) {
      _snack('Add a bank or cash wallet to pay from first.');
      return;
    }
    final payer = await showDialog<Wallet>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pay from'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in payers)
              ListTile(
                title: Text(p.name),
                trailing: Text(formatMoney(p.balance)),
                onTap: () => Navigator.of(context).pop(p),
              ),
          ],
        ),
      ),
    );
    if (payer == null || !mounted) return;
    Haptics.medium();
    await db.addTransfer(
      fromWalletId: payer.id,
      toWalletId: wallet.id,
      amount: amount,
      note: 'Paylater payment',
    );
    final fresh = await db.getWalletById(wallet.id);
    if (fresh != null &&
        fresh.kind == 'paylater' &&
        fresh.dueDay != null &&
        paylaterOutstanding(fresh) > 0 &&
        AppPrefs.paylaterReminders) {
      await NotificationService.schedulePaylaterReminder(
        walletId: fresh.id,
        walletName: fresh.name,
        amount: paylaterOutstanding(fresh),
        dueDate: nextDueDate(dueDay: fresh.dueDay!, from: DateTime.now()),
      );
    } else {
      await NotificationService.cancelPaylaterReminder(wallet.id);
    }
    if (!mounted) return;
    _snack('Paid ${formatMoney(amount)} to ${wallet.name}');
  }

  Widget _providerCard(Wallet w) {
    final outstanding = paylaterOutstanding(w);
    final ratio = w.creditLimit != null && w.creditLimit! > 0
        ? (outstanding / w.creditLimit!).clamp(0.0, 1.0)
        : null;
    final due = w.dueDay == null
        ? null
        : nextDueDate(dueDay: w.dueDay!, from: DateTime.now());
    return GlassCard(
      onTap: () {
        Haptics.select();
        Navigator.push(
          context,
          AppPageRoute(builder: (_) => WalletDetailScreen(walletId: w.id)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  w.name,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                formatMoney(outstanding),
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ratio != null) ...[
            _LimitBar(ratio: ratio),
            const SizedBox(height: 4),
            Text(
              '${formatMoney(outstanding)} of ${formatMoney(w.creditLimit!)} used',
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
          ] else
            Text(
              'No limit set',
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
          const SizedBox(height: 4),
          Text(
            due == null ? 'No due date set' : 'Due ${formatDate(due)}',
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _plansSection(List<InstallmentPlan> plans, List<Wallet> paylater) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionLabel('Installment plans')),
            TextButton.icon(
              onPressed: () => _addPlanSheet(paylater),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add plan'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (plans.isEmpty)
          Text(
            'No plans yet. Add one to track a multi-month purchase.',
            style: TextStyle(color: context.textMuted, fontSize: 13),
          )
        else
          for (final p in plans) ...[
            _planCard(p, paylater),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _planCard(InstallmentPlan p, List<Wallet> paylater) {
    Wallet? wallet;
    for (final w in paylater) {
      if (w.id == p.walletId) wallet = w;
    }
    final complete = p.paidCount >= p.totalCount;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.name,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${formatMoney(planRemaining(p))} left',
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
            ],
          ),
          if (wallet != null)
            Text(
              wallet.name,
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
          const SizedBox(height: 8),
          _LimitBar(ratio: planProgress(p)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${p.paidCount} of ${p.totalCount} paid · ${formatMoney(p.installmentAmount)}/mo',
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
              ),
              if (!complete)
                TextButton(
                  onPressed: () async {
                    Haptics.light();
                    await ref
                        .read(databaseProvider)
                        .markInstallmentPaid(p.id);
                  },
                  child: const Text('Pay installment'),
                )
              else
                Text(
                  'Complete',
                  style: TextStyle(
                    color: AppColors.income,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              IconButton(
                tooltip: 'Delete plan',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _confirmDeletePlan(p),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePlan(InstallmentPlan p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete plan?'),
        content: Text(
          '“${p.name}” and its progress will be removed. This does not change any transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(databaseProvider).deleteInstallmentPlan(p.id);
    }
  }

  Future<void> _addPlanSheet(List<Wallet> paylater) async {
    final nameCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    final countCtrl = TextEditingController(text: '3');
    var selectedWalletId = paylater.first.id;
    final saved = await showSnackSheet<bool>(
      context,
      (context) => StatefulBuilder(
        builder: (context, setSheetState) => FormSheet(
          title: 'Add installment plan',
          actionLabel: 'Add plan',
          onAction: () async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              _snack('Enter a name for the plan');
              return;
            }
            final total = parseAmountInput(totalCtrl.text);
            final count = int.tryParse(countCtrl.text.trim()) ?? 0;
            if (total <= 0) {
              _snack('Enter the total amount');
              return;
            }
            if (count < 2) {
              _snack('Plans need at least 2 installments');
              return;
            }
            await ref.read(databaseProvider).addInstallmentPlan(
                  walletId: selectedWalletId,
                  name: name,
                  totalAmount: total,
                  installmentAmount: (total / count).round(),
                  totalCount: count,
                );
            if (context.mounted) Navigator.of(context).pop(true);
          },
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            const FormSectionLabel('Paylater wallet'),
            FormChoiceChips<Wallet>(
              options: paylater,
              selected: paylater.firstWhere((w) => w.id == selectedWalletId),
              labelFor: (w) => w.name,
              onSelected: (w) =>
                  setSheetState(() => selectedWalletId = w.id),
            ),
            const SizedBox(height: 16),
            const FormSectionLabel('Total amount'),
            FormAmountEntry(controller: totalCtrl),
            const SizedBox(height: 16),
            TextField(
              controller: countCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of installments',
              ),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) _snack('Installment plan added');
  }

  Widget _costsCard(int monthSpending) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Costs',
            style: TextStyle(color: context.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Spent on paylater this month',
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            formatMoney(monthSpending),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _freezeCard() {
    final frozen = AppPrefs.paylaterFrozen;
    return GlassCard(
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Freeze paylater'),
        subtitle: const Text(
          'While frozen, new expenses on paylater wallets are blocked until you unfreeze.',
        ),
        value: frozen,
        onChanged: (v) async {
          Haptics.select();
          await AppPrefs.setPaylaterFrozen(v);
          if (mounted) setState(() {});
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Horizontal used-vs-limit bar. [ratio] is clamped to 0..1.
class _LimitBar extends StatelessWidget {
  const _LimitBar({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: context.textMuted.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: ratio.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: context.accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
