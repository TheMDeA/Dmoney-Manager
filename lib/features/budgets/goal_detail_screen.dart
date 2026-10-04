import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal'),
        actions: [
          IconButton(
            tooltip: 'Edit goal',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editGoal(context, db),
          ),
          IconButton(
            tooltip: 'Delete goal',
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
              child: Text('Goal not found',
                  style: TextStyle(color: context.textMuted)),
            );
          }
          final g = goal;
          return StreamBuilder<List<GoalDeposit>>(
            stream: db.watchGoalDeposits(g.id),
            builder: (context, dSnap) {
              final deposits = dSnap.data ?? const <GoalDeposit>[];
              return _content(context, db, g, deposits);
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
  ) {
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
                  'Saved', formatMoney(goal.saved), context.textMuted),
              _amountColumn('Remain', formatMoney(remain),
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
          _infoRow('Amount', formatMoney(goal.target)),
          _infoRow(
            'Goal date',
            goal.deadline == null ? '—' : formatDate(goal.deadline!),
            sub: daysLeft == null
                ? null
                : daysLeft < 0
                    ? 'Overdue by ${-daysLeft} days'
                    : '$daysLeft days left',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  context,
                  icon: Icons.savings_outlined,
                  label: 'DEPOSIT',
                  onTap: () => _depositDialog(context, db, goal, true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _actionButton(
                  context,
                  icon: Icons.atm_outlined,
                  label: 'WITHDRAW',
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
                child: Text('No deposits yet',
                    style: TextStyle(
                        color: context.textMuted, fontSize: 15)),
              ),
            )
          else
            for (final day in days) _dayGroup(context, db, day, byDay[day]!),
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
      List<GoalDeposit> ds) {
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
                      DateFormat('EEEE', currentCurrency.locale)
                          .format(day),
                      style: TextStyle(
                          color: context.textPrimary, fontSize: 14),
                    ),
                    Text(
                      DateFormat('MMM yyyy', currentCurrency.locale)
                          .format(day),
                      style: TextStyle(
                          color: context.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text(
                formatSignedMoney(dayTotal, isIncome: dayTotal >= 0),
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
          builder: (context) => AlertDialog(
            title: const Text('Delete entry?'),
            content: const Text(
                'The goal\'s saved total will be adjusted back.'),
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
                    : (isDeposit ? 'Deposit' : 'Withdraw'),
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
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isDeposit
            ? 'Deposit to "${goal.name}"'
            : 'Withdraw from "${goal.name}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: InputDecoration(
                  labelText: 'Amount (${currentCurrency.code})'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration:
                  const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(isDeposit ? 'Deposit' : 'Withdraw')),
        ],
      ),
    );
    final amount = parseAmountInput(amountCtrl.text);
    if (saved == true && amount > 0 && context.mounted) {
      final wasComplete = goal.target > 0 && goal.saved >= goal.target;
      await db.recordGoalDeposit(
        goalId: goal.id,
        amount: isDeposit ? amount : -amount,
        date: DateTime.now(),
        note: noteCtrl.text.trim(),
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
              content: Text(
                  '${formatMoney(amount)} ${isDeposit ? 'added to' : 'withdrawn from'} ${goal.name}')),
        );
      }
    }
  }

  /// Full-screen-ish celebration when a goal reaches 100%: the trophy pops
  /// in with an elastic bounce, a ripple ring expands behind it, and the
  /// phone buzzes. Shown once, at the moment of completion.
  Future<void> _celebrateGoal(BuildContext context, Goal goal) {
    Haptics.medium();
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
                    duration: const Duration(milliseconds: 700),
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
              const Text(
                'Goal complete!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                '${goal.name} — ${formatMoney(goal.saved)} saved',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Awesome'),
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
    final nameCtrl = TextEditingController(text: goal.name);
    final targetCtrl =
        TextEditingController(text: formatAmountInput(goal.target));
    DateTime? deadline = goal.deadline;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit goal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  decoration: InputDecoration(
                      labelText: 'Target (${currentCurrency.code})'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: deadline ??
                          DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 10)),
                    );
                    if (picked != null) {
                      setState(() => deadline = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(deadline == null
                      ? 'Goal date (optional)'
                      : formatDate(deadline!)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    final target = parseAmountInput(targetCtrl.text);
    if (saved == true &&
        nameCtrl.text.trim().isNotEmpty &&
        target > 0) {
      await db.updateGoal(
        id: goal.id,
        name: nameCtrl.text.trim(),
        target: target,
        deadline: deadline,
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppDatabase db) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete goal?'),
        content: const Text(
            'The goal and its deposit history will be removed permanently.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
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
      await db.deleteGoal(widget.goalId);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
