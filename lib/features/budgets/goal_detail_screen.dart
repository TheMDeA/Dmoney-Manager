import 'package:flutter/material.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_locale.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/form_sheet.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'goal_deposit_sheet.dart';
import 'goal_form_sheet.dart';

/// Detail view for one savings goal: saved/remain progress, deadline info,
/// deposit/withdraw actions, and the full deposit history.
class GoalDetailScreen extends ConsumerStatefulWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final int goalId;

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final l10n = AppLocalizations.of(context)!;
    // Privacy mode: goal figures mask, deposit/withdrawal rows stay.
    final hidden = ref.watch(balanceHiddenProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.goalTitle),
        actions: [
          IconButton(
            tooltip: l10n.goalEditTooltip,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editGoal(context, db),
          ),
          IconButton(
            tooltip: l10n.goalDeleteTooltip,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, db),
          ),
        ],
      ),
      body: StreamBuilder<List<Goal>>(
        stream: db.watchGoals(),
        builder: (context, gSnap) {
          Goal? goal;
          for (final g in gSnap.data ?? const <Goal>[]) {
            if (g.id == widget.goalId) goal = g;
          }
          if (goal == null) {
            return Center(
              child: Text(l10n.goalNotFound,
                  style: TextStyle(color: context.textMuted)),
            );
          }
          final g = goal;
          return StreamBuilder<List<GoalDeposit>>(
            stream: db.watchGoalDeposits(g.id),
            builder: (context, dSnap) {
              final deposits = dSnap.data ?? const <GoalDeposit>[];
              return _content(context, db, g, deposits, hidden);
            },
          );
        },
      ),
    );
  }

  Widget _content(
    BuildContext context,
    AppDatabase db,
    Goal goal,
    List<GoalDeposit> deposits,
    bool hidden,
  ) {
    final l10n = AppLocalizations.of(context)!;
    String m(int v) =>
        hidden ? maskMoneyText(formatMoney(v)) : formatMoney(v);
    final ratio =
        goal.target == 0 ? 0.0 : goal.saved / goal.target;
    final remain = goal.target - goal.saved;
    final goalColor = colorFromHex(goal.colorHex);
    final now = DateTime.now();
    final daysLeft = goal.deadline
        ?.difference(DateTime(now.year, now.month, now.day))
        .inDays;

    // Group deposits by day, newest first.
    final byDay = <DateTime, List<GoalDeposit>>{};
    for (final d in deposits) {
      final day = DateTime(d.date.year, d.date.month, d.date.day);
      byDay.putIfAbsent(day, () => []).add(d);
    }
    final days = byDay.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            goal.name,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _amountColumn(
                  l10n.goalSaved, m(goal.saved), context.textMuted),
              _amountColumn(l10n.goalRemain, m(remain),
                  remain < 0 ? AppColors.expense : context.textMuted),
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
                      child: Container(color: goalColor),
                    ),
                  ),
                  Center(
                    child: Text(
                      formatPercent(ratio * 100, 2),
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
          _infoRow(l10n.goalAmountLabel, m(goal.target)),
          _infoRow(
            l10n.goalDateLabel,
            goal.deadline == null ? '—' : formatDate(goal.deadline!),
            sub: daysLeft == null
                ? null
                : daysLeft < 0
                    ? l10n.goalOverdue(-daysLeft)
                    : l10n.goalDaysLeft(daysLeft),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  context,
                  icon: Icons.savings_outlined,
                  label: l10n.goalDepositAction,
                  onTap: () => _depositDialog(context, db, goal, true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _actionButton(
                  context,
                  icon: Icons.atm_outlined,
                  label: l10n.goalWithdrawAction,
                  onTap: () => _depositDialog(context, db, goal, false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (deposits.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(l10n.goalNoDeposits,
                    style: TextStyle(
                        color: context.textMuted, fontSize: 15)),
              ),
            )
          else
            for (final day in days) _dayGroup(context, db, day, byDay[day]!, hidden),
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

  Widget _infoRow(String label, String value, {String? sub}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    color: context.textMuted, fontSize: 15)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                if (sub != null)
                  Text(sub,
                      style: TextStyle(
                          color: context.textMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: context.textPrimary, size: 34),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: context.accent,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayGroup(BuildContext context, AppDatabase db, DateTime day,
      List<GoalDeposit> ds, bool hidden) {
    final dayTotal = ds.fold<int>(0, (s, d) => s + d.amount);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Text(
                day.day.toString().padLeft(2, '0'),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE', appLocaleCode)
                          .format(day),
                      style: TextStyle(
                          color: context.textPrimary, fontSize: 14),
                    ),
                    Text(
                      DateFormat('MMM yyyy', appLocaleCode)
                          .format(day),
                      style: TextStyle(
                          color: context.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text(
                hidden
                    ? maskMoneyText(
                        formatSignedMoney(dayTotal, isIncome: dayTotal >= 0))
                    : formatSignedMoney(dayTotal, isIncome: dayTotal >= 0),
                style: AppTextStyles.amount(size: 15),
              ),
            ],
          ),
        ),
        for (final d in ds) _depositRow(context, db, d),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _depositRow(
      BuildContext context, AppDatabase db, GoalDeposit d) {
    final l10n = AppLocalizations.of(context)!;
    final isDeposit = d.amount >= 0;
    final timeFmt = DateFormat('HH.mm');
    return Dismissible(
      key: ValueKey(d.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child:
            const Icon(Icons.delete_outline, color: AppColors.expense),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return AlertDialog(
              title: Text(l10n.goalDeleteEntryTitle),
              content: Text(l10n.goalDeleteEntryMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () {
                    Haptics.medium();
                    Navigator.pop(context, true);
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.expense),
                  child: Text(l10n.commonDelete),
                ),
              ],
            );
          },
        );
        if (confirmed == true) {
          await db.deleteGoalDeposit(d);
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
                color: AppColors.income.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(23),
              ),
              child: Icon(
                isDeposit ? Icons.savings_outlined : Icons.atm_outlined,
                color: isDeposit ? AppColors.income : AppColors.expense,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                d.note.isNotEmpty
                    ? d.note
                    : (isDeposit ? l10n.goalDeposit : l10n.goalWithdraw),
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatSignedMoney(d.amount, isIncome: isDeposit),
                  style: AppTextStyles.amount(size: 15).copyWith(
                      color: isDeposit
                          ? AppColors.income
                          : AppColors.expense),
                ),
                Text(
                  timeFmt.format(d.date),
                  style: TextStyle(
                      color: context.textMuted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _depositDialog(
      BuildContext context, AppDatabase db, Goal goal, bool isDeposit) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showFormSheet<GoalDepositInput>(
      context,
      (_) => GoalDepositSheet(goal: goal, isDeposit: isDeposit),
    );
    final amount = result?.amount ?? 0;
    if (result != null && amount > 0 && context.mounted) {
      final wasComplete = goal.target > 0 && goal.saved >= goal.target;
      await db.recordGoalDeposit(
        goalId: goal.id,
        amount: isDeposit ? amount : -amount,
        date: DateTime.now(),
        note: result.note,
      );
      if (!context.mounted) return;
      // Celebrate the moment a deposit pushes the goal to 100%.
      final updated = await db.getGoalById(goal.id);
      if (!context.mounted) return;
      if (isDeposit &&
          !wasComplete &&
          updated != null &&
          updated.target > 0 &&
          updated.saved >= updated.target) {
        await _celebrateGoal(context, updated);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isDeposit
                  ? l10n.goalAddedTo(formatMoney(amount), goal.name)
                  : l10n.goalWithdrawnFrom(formatMoney(amount), goal.name))),
        );
      }
    }
  }

  /// Full-screen-ish celebration when a goal reaches 100%: the trophy pops
  /// in with an elastic bounce, a ripple ring expands behind it, and the
  /// phone buzzes. Shown once, at the moment of completion.
  Future<void> _celebrateGoal(BuildContext context, Goal goal) {
    final l10n = AppLocalizations.of(context)!;
    Haptics.medium();
    // Modal dialog: capture the flag at open (the Home eye can't be
    // reached while it is up).
    final hidden = ref.read(balanceHiddenProvider);
    String m(int v) =>
        hidden ? maskMoneyText(formatMoney(v)) : formatMoney(v);
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.5, end: 1.8),
                    duration: AppMotion.slow,
                    curve: Curves.easeOut,
                    builder: (context, scale, child) => Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: (1.8 - scale).clamp(0.0, 1.0),
                        child: child,
                      ),
                    ),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.income.withValues(alpha: 0.5),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.2, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.income,
                      ),
                      child: const Icon(Icons.emoji_events_outlined,
                          color: Colors.white, size: 48),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                l10n.goalCompleteTitle,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.goalCompleteMessage(goal.name, m(goal.saved)),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.goalAwesome),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editGoal(BuildContext context, AppDatabase db) async {
    final goal = await db.getGoalById(widget.goalId);
    if (goal == null || !context.mounted) return;
    await showGoalFormSheet(context, ref, existing: goal);
  }

  Future<void> _confirmDelete(BuildContext context, AppDatabase db) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.goalDeleteTitle),
          content: Text(l10n.goalDeleteMessage),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.commonCancel)),
            FilledButton(
              onPressed: () {
                Haptics.medium();
                Navigator.pop(context, true);
              },
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.expense),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );
    if (confirmed == true && context.mounted) {
      await db.deleteGoal(widget.goalId);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
