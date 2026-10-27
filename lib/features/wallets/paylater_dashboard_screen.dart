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
import '../categories/category_picker_section.dart';
import '../transactions/widgets/transaction_tile.dart';
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
    final hidden = ref.watch(balanceHiddenProvider);
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
                  // Repayments are transfers, so they never appear in
                  // spending above — surface them as their own line
                  // instead of reclassifying them as expenses (which
                  // would stop the debt from going down).
                  final monthRepayments = paylaterRepayments(
                    monthTxs.map((d) => d.transaction),
                    paylaterIds,
                  );
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _heroCard(outstanding, dueCycle, ratio, hidden),
                      const SizedBox(height: 12),
                      if (next != null) ...[
                        _nextDueCard(
                            next.wallet, next.dueDate, wallets, plans, hidden),
                        const SizedBox(height: 12),
                      ],
                      const _SectionLabel('Providers'),
                      const SizedBox(height: 8),
                      for (final w in paylater) ...[
                        _providerCard(w, hidden),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 12),
                      _plansSection(plans, paylater, wallets, hidden),
                      const SizedBox(height: 12),
                      _costsCard(monthSpending, monthRepayments, hidden),
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

  Widget _heroCard(
      int outstanding, int dueCycle, double? ratio, bool hidden) {
    String m(int v) =>
        hidden ? maskMoneyText(formatMoney(v)) : formatMoney(v);
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
            m(outstanding),
            style: AppTextStyles.displayBalance.copyWith(
              fontSize: 32,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _heroStat('Due this cycle', m(dueCycle)),
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

  Widget _nextDueCard(
    Wallet wallet,
    DateTime dueDate,
    List<Wallet> wallets,
    List<InstallmentPlan> plans,
    bool hidden,
  ) {
    // The button pays what this card shows: one installment when the
    // wallet has a single payable plan, otherwise the full outstanding.
    // The date follows the same rule: the plan's next installment date
    // in the single-plan case, the wallet's due date otherwise.
    final plan = singlePayablePlan(plans, wallet.id);
    final amount =
        plan == null ? paylaterOutstanding(wallet) : installmentDueAmount(plan);
    final shownDue = plan == null
        ? dueDate
        : (nextInstallmentDueDate(plan, wallet.dueDay) ?? dueDate);
    String m(int v) =>
        hidden ? maskMoneyText(formatMoney(v)) : formatMoney(v);
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
            '${m(amount)} · due ${formatDate(shownDue)}',
            style: TextStyle(color: context.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _payDue(wallet, wallets),
              child: Text(plan == null ? 'Mark as paid' : 'Pay installment'),
            ),
          ),
        ],
      ),
    );
  }

  /// Pays what the Next due card shows: one installment when the wallet
  /// has a single payable plan, otherwise the full outstanding amount.
  /// A single plan's payment goes through the installment flow, so it is
  /// linked to the plan and advances its counter; the reminder is then
  /// refreshed with the new outstanding amount (or cancelled when
  /// nothing is owed anymore).
  Future<void> _payDue(Wallet wallet, List<Wallet> allWallets) async {
    final db = ref.read(databaseProvider);
    final plan = singlePayablePlan(
      await db.plansForWallet(wallet.id),
      wallet.id,
    );
    if (!mounted) return;
    if (plan != null) {
      await _payInstallment(plan, wallet, allWallets);
      await _refreshDueReminder(wallet.id);
      return;
    }
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
                trailing: Text(ref.read(balanceHiddenProvider)
                    ? maskMoneyText(formatMoney(p.balance))
                    : formatMoney(p.balance)),
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
    await _refreshDueReminder(wallet.id);
    if (!mounted) return;
    _snack('Paid ${formatMoney(amount)} to ${wallet.name}');
  }

  /// Reschedules the wallet's due reminder with its current outstanding
  /// amount, or cancels it when nothing is owed anymore.
  Future<void> _refreshDueReminder(int walletId) async {
    final fresh = await ref.read(databaseProvider).getWalletById(walletId);
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
      await NotificationService.cancelPaylaterReminder(walletId);
    }
  }

  /// Pays one installment of [p] as a real transfer — same pattern as
  /// [_payDue]: pick a payer wallet, record the transfer, then advance
  /// the plan counter. The amount is capped by the plan's own remaining
  /// only, never by the wallet balance, so a plan whose purchase was
  /// never recorded as an expense can still be paid off. Previously
  /// this button only bumped the counter and created no transaction,
  /// so the payment appeared nowhere else in the app.
  Future<void> _payInstallment(
    InstallmentPlan p,
    Wallet? planWallet,
    List<Wallet> allWallets,
  ) async {
    if (planWallet == null) {
      _snack('Wallet not found for this plan.');
      return;
    }
    final db = ref.read(databaseProvider);
    final amount = installmentDueAmount(p);
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
            for (final pay in payers)
              ListTile(
                title: Text(pay.name),
                trailing: Text(ref.read(balanceHiddenProvider)
                    ? maskMoneyText(formatMoney(pay.balance))
                    : formatMoney(pay.balance)),
                onTap: () => Navigator.of(context).pop(pay),
              ),
          ],
        ),
      ),
    );
    if (payer == null || !mounted) return;
    Haptics.medium();
    await db.addTransfer(
      fromWalletId: payer.id,
      toWalletId: planWallet.id,
      amount: amount,
      note: 'Installment payment: ${p.name}',
      planId: p.id,
    );
    await db.markInstallmentPaid(p.id);
    if (!mounted) return;
    _snack('Paid ${formatMoney(amount)} installment for ${p.name}');
  }

  Widget _providerCard(Wallet w, bool hidden) {
    String m(int v) =>
        hidden ? maskMoneyText(formatMoney(v)) : formatMoney(v);
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
                m(outstanding),
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
              '${m(outstanding)} of ${m(w.creditLimit!)} used',
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

  Widget _plansSection(
    List<InstallmentPlan> plans,
    List<Wallet> paylater,
    List<Wallet> allWallets,
    bool hidden,
  ) {
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
            _planCard(p, paylater, allWallets, hidden),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _planCard(
    InstallmentPlan p,
    List<Wallet> paylater,
    List<Wallet> allWallets,
    bool hidden,
  ) {
    String m(int v) =>
        hidden ? maskMoneyText(formatMoney(v)) : formatMoney(v);
    Wallet? wallet;
    for (final w in paylater) {
      if (w.id == p.walletId) wallet = w;
    }
    final complete = p.paidCount >= p.totalCount;
    final due = nextInstallmentDueDate(p, wallet?.dueDay);
    // Tapping the card opens the plan's history: its purchase plus
    // every installment payment. The buttons inside still win their
    // own taps.
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _showPlanHistory(p),
      child: GlassCard(
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
                '${m(planRemaining(p))} left',
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
                  due == null
                      ? '${p.paidCount} of ${p.totalCount} paid · ${m(p.installmentAmount)}/mo'
                      : '${p.paidCount} of ${p.totalCount} paid · ${m(p.installmentAmount)}/mo · Due ${formatDate(due)}',
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
              ),
              if (!complete)
                TextButton(
                  onPressed: () => _payInstallment(p, wallet, allWallets),
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
    ),
    );
  }

  /// History for one plan: its purchase expense plus every installment
  /// payment, newest first. Rows open their transaction detail on tap.
  Future<void> _showPlanHistory(InstallmentPlan p) async {
    final db = ref.read(databaseProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                p.name,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<TransactionWithDetails>>(
                stream: db.watchPlanTransactions(p.id),
                builder: (context, snap) {
                  final txs = snap.data ?? const <TransactionWithDetails>[];
                  if (txs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No transactions linked to this plan yet.',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: txs.length,
                    itemBuilder: (context, i) => TransactionTile(
                      details: txs[i],
                      showDate: true,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePlan(InstallmentPlan p) async {
    final linked = await ref.read(databaseProvider).planTransactions(p.id);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete plan?'),
        content: Text(
          linked.isEmpty
              ? '“${p.name}” and its progress will be removed.'
              : '“${p.name}” and its ${linked.length} linked '
                  '${linked.length == 1 ? 'transaction' : 'transactions'} '
                  'will be removed, and wallet balances restored.',
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
    int? selectedCategoryId;
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
            if (selectedCategoryId == null) {
              _snack('Pick a category for the purchase');
              return;
            }
            // A plan's purchase is a new paylater expense, so the freeze
            // gate applies here too — otherwise plans would bypass it.
            if (AppPrefs.paylaterFrozen) {
              final unfreeze = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Paylater is frozen'),
                  content: const Text(
                    'New paylater purchases are blocked while frozen. '
                    'Unfreeze to add this plan?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Unfreeze'),
                    ),
                  ],
                ),
              );
              if (unfreeze != true) return;
              await AppPrefs.setPaylaterFrozen(false);
            }
            await ref.read(databaseProvider).addPlanWithPurchase(
                  walletId: selectedWalletId,
                  name: name,
                  totalAmount: total,
                  installmentAmount: (total / count).round(),
                  totalCount: count,
                  categoryId: selectedCategoryId!,
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
            const SizedBox(height: 16),
            CategoryPickerSection(
              kind: 'expense',
              selectedId: selectedCategoryId,
              onSelected: (c) =>
                  setSheetState(() => selectedCategoryId = c.id),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) _snack('Installment plan added');
  }

  Widget _costsCard(int monthSpending, int monthRepayments, bool hidden) {
    String m(int v) =>
        hidden ? maskMoneyText(formatMoney(v)) : formatMoney(v);
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
            m(monthSpending),
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paid this month',
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            m(monthRepayments),
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
