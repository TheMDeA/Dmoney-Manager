import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/section_header.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../debts/debts_screen.dart';

/// Budgets with threshold alerts, savings goals, and a debt preview.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final mk = monthKey(DateTime.now());
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: StreamBuilder<List<Budget>>(
        stream: db.watchBudgets(mk),
        builder: (context, bSnap) {
          final budgets = bSnap.data ?? const <Budget>[];
          return StreamBuilder<List<Transaction>>(
            stream: db.watchTransactionsRaw(),
            builder: (context, txSnap) {
              final txs = txSnap.data ?? const <Transaction>[];
              final monthStart = DateTime(now.year, now.month);
              return StreamBuilder<List<Category>>(
                stream: db.watchCategories(),
                builder: (context, catSnap) {
                  final cats = {
                    for (final c in (catSnap.data ?? const <Category>[])) c.id: c
                  };
                  final spentByCat = <int, int>{};
                  for (final t in txs) {
                    if (t.kind == 'expense' && !t.date.isBefore(monthStart)) {
                      spentByCat[t.categoryId] =
                          (spentByCat[t.categoryId] ?? 0) + t.amount;
                    }
                  }
                  final overBudget = budgets.where((b) =>
                      (spentByCat[b.categoryId] ?? 0) >= b.limit);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Month progress',
                                  style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: now.day / daysInMonth,
                                backgroundColor: AppColors.hairline,
                                color: AppColors.lime,
                                borderRadius: BorderRadius.circular(4),
                                minHeight: 8,
                              ),
                              const SizedBox(height: 8),
                              Text('${now.day} of $daysInMonth days',
                                  style: const TextStyle(
                                      color: AppColors.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (overBudget.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.expense.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: AppColors.expense.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      color: AppColors.expense),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${overBudget.map((b) => cats[b.categoryId]?.name ?? 'Budget').join(', ')} ${overBudget.length == 1 ? 'has' : 'have'} reached the limit.',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        SectionHeader(
                          title: 'Budgets',
                          action: TextButton(
                            onPressed: () => _addBudgetDialog(context, ref, cats.values.toList(), mk),
                            child: const Text('Add'),
                          ),
                        ),
                        if (budgets.isEmpty)
                          const EmptyState(
                              icon: Icons.savings_outlined,
                              message: 'No budgets yet. Add one to control spending.')
                        else
                          for (final b in budgets)
                            _budgetRow(context, b, cats[b.categoryId],
                                spentByCat[b.categoryId] ?? 0),
                        const SectionHeader(title: 'Savings goals'),
                        _goalsSection(context, ref),
                        SectionHeader(
                          title: 'Debts',
                          action: TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const DebtsScreen()),
                            ),
                            child: const Text('View all'),
                          ),
                        ),
                        _debtsPreview(context, ref),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _budgetRow(BuildContext context, Budget b, Category? c, int spent) {
    final ratio = b.limit == 0 ? 0.0 : spent / b.limit;
    final color = ratio >= 1
        ? AppColors.expense
        : ratio >= 0.8
            ? AppColors.warning
            : AppColors.income;
    final catColor = colorFromHex(c?.colorHex ?? '#9CA3AF');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconForKey(c?.iconKey ?? 'other'),
                      color: catColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(c?.name ?? 'Budget',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text('${formatMoney(spent)} / ${formatMoney(b.limit)}',
                    style: AppTextStyles.amount(size: 13)),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: AppColors.hairline,
              color: color,
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            ),
            const SizedBox(height: 6),
            Text(
              ratio >= 1
                  ? 'Over budget by ${formatMoney(spent - b.limit)}'
                  : '${formatMoney(b.limit - spent)} left',
              style: TextStyle(
                  fontSize: 12,
                  color: ratio >= 1 ? AppColors.expense : AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalsSection(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<Goal>>(
      stream: db.watchGoals(),
      builder: (context, snap) {
        final goals = snap.data ?? const <Goal>[];
        if (goals.isEmpty) {
          return OutlinedButton.icon(
            onPressed: () => _addGoalDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add savings goal'),
          );
        }
        return Column(
          children: [
            for (final g in goals)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _addSavingsDialog(context, ref, g),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(g.name,
                                style:
                                    const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                                '${(g.target == 0 ? 0 : g.saved / g.target * 100).toStringAsFixed(0)}%',
                                style: AppTextStyles.amount(size: 14)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: g.target == 0
                              ? 0.0
                              : (g.saved / g.target).clamp(0.0, 1.0),
                          backgroundColor: AppColors.hairline,
                          color: colorFromHex(g.colorHex),
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 8,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${formatMoney(g.saved)} of ${formatMoney(g.target)}',
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 12)),
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_circle_outline,
                                    size: 14, color: AppColors.lime),
                                SizedBox(width: 4),
                                Text('Add savings',
                                    style: TextStyle(
                                        color: AppColors.lime, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => _addGoalDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add savings goal'),
            ),
          ],
        );
      },
    );
  }

  Widget _debtsPreview(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<Debt>>(
      stream: db.watchDebts(isPaid: false),
      builder: (context, snap) {
        final debts = (snap.data ?? const <Debt>[]).take(3).toList();
        if (debts.isEmpty) {
          return const Text('No outstanding debts.',
              style: TextStyle(color: AppColors.textMuted));
        }
        return Column(
          children: [
            for (final d in debts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor:
                      colorFromHex(d.colorHex).withValues(alpha: 0.2),
                  child: Text(d.person.characters.first,
                      style: TextStyle(color: colorFromHex(d.colorHex))),
                ),
                title: Text(d.person),
                subtitle: Text(d.direction == 'payable' ? 'You owe' : 'Owed to you'),
                trailing: Text(formatMoney(d.amount),
                    style: AppTextStyles.amount(size: 15)
                        .copyWith(color: AppColors.expense)),
              ),
          ],
        );
      },
    );
  }

  Future<void> _addBudgetDialog(
      BuildContext context, WidgetRef ref, List<Category> cats, String mk) async {
    final expenseCats = cats.where((c) => c.kind == 'expense' && c.parentId == null).toList();
    int? catId = expenseCats.isNotEmpty ? expenseCats.first.id : null;
    final limitCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: catId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in expenseCats)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => catId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: limitCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monthly limit (Rp)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    final limit = int.tryParse(limitCtrl.text) ?? 0;
    if (saved == true && catId != null && limit > 0) {
      await ref.read(databaseProvider).addBudget(
            BudgetsCompanion.insert(categoryId: catId!, month: mk, limit: limit),
          );
    }
  }

  Future<void> _addSavingsDialog(
      BuildContext context, WidgetRef ref, Goal g) async {
    final amountCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add savings to "${g.name}"'),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (Rp)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add')),
        ],
      ),
    );
    final amount = int.tryParse(amountCtrl.text) ?? 0;
    if (saved == true && amount > 0) {
      await ref
          .read(databaseProvider)
          .updateGoalSaved(g.id, g.saved + amount);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${formatMoney(amount)} added to ${g.name}')),
        );
      }
    }
  }

  Future<void> _addGoalDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add savings goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(
              controller: targetCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target (Rp)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    final target = int.tryParse(targetCtrl.text) ?? 0;
    if (saved == true && nameCtrl.text.trim().isNotEmpty && target > 0) {
      await ref.read(databaseProvider).addGoal(
            GoalsCompanion.insert(name: nameCtrl.text.trim(), target: target),
          );
    }
  }
}
