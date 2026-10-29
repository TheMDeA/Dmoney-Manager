import 'package:flutter/material.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/app_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ambient_glow.dart';
import '../../core/widgets/screen_header.dart';
import '../../core/theme/app_accents.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/count_up_money.dart';
import '../../core/widgets/animated_progress_bar.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/section_header.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../debts/debts_screen.dart';
import '../debts/debt_detail_screen.dart';
import 'budget_detail_screen.dart';
import 'budget_form_sheet.dart';
import 'goal_detail_screen.dart';
import 'goal_form_sheet.dart';

/// Budgets with threshold alerts, savings goals, and a debt preview.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final accountId = ref.watch(selectedAccountProvider);
    final hidden = ref.watch(balanceHiddenProvider);
    final mk = monthKey(DateTime.now());
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: AmbientGlow(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(title: l10n.budgetsTitle, tabIndex: 4),
            Expanded(
              child: StreamBuilder<List<Budget>>(
                stream: db.watchBudgets(mk),
                builder: (context, bSnap) {
                  final budgets = bSnap.data ?? const <Budget>[];
                  final monthStart = DateTime(now.year, now.month);
                  final monthEnd = DateTime(
                    now.year,
                    now.month + 1,
                  ).subtract(const Duration(seconds: 1));
                  return StreamBuilder<List<CategoryTotal>>(
                    stream: db.watchCategoryExpenseTotals(
                      monthStart,
                      monthEnd,
                      accountId: accountId,
                    ),
                    builder: (context, totalsSnap) {
                      final spentByCat = {
                        for (final t
                            in (totalsSnap.data ?? const <CategoryTotal>[]))
                          t.categoryId: t.total,
                      };
                      return StreamBuilder<List<Category>>(
                        stream: db.watchCategories(),
                        builder: (context, catSnap) {
                          final cats = {
                            for (final c
                                in (catSnap.data ?? const <Category>[]))
                              c.id: c,
                          };
                          final overBudget = budgets.where(
                            (b) => (spentByCat[b.categoryId] ?? 0) >= b.limit,
                          );

                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GlassCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.budgetsMonthProgress,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 8),
                                      AnimatedProgressBar(
                                        value: now.day / daysInMonth,
                                        backgroundColor: context.hairline,
                                        color: context.accent,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        l10n.budgetsDaysProgress(now.day, daysInMonth),
                                        style: TextStyle(
                                          color: context.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (overBudget.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AppColors.expense.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppColors.expense.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.warning_amber_rounded,
                                            color: AppColors.expense,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              l10n.budgetsOverLimit(overBudget.map((b) => cats[b.categoryId]?.name ?? l10n.budgetsFallbackName).join(', ')),
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                SectionHeader(
                                  title: l10n.budgetsTitle,
                                  action: TextButton(
                                    onPressed: () =>
                                        _addBudgetDialog(context, ref, mk),
                                    child: Text(l10n.commonAdd),
                                  ),
                                ),
                                if (budgets.isEmpty)
                                  EmptyState(
                                    icon: Icons.savings_outlined,
                                    title: l10n.budgetsEmptyTitle,
                                    message: l10n.budgetsEmptyMessage,
                                    actionLabel: l10n.budgetsAddBudget,
                                    onAction: () =>
                                        _addBudgetDialog(context, ref, mk),
                                  )
                                else
                                  for (var i = 0; i < budgets.length; i++)
                                    Entrance(
                                      key: ValueKey(budgets[i].id),
                                      delay: Duration(
                                        milliseconds: (i * 60).clamp(0, 300),
                                      ),
                                      child: _budgetRow(
                                        context,
                                        budgets[i],
                                        cats[budgets[i].categoryId],
                                        spentByCat[budgets[i].categoryId] ?? 0,
                                        mk,
                                        hidden,
                                      ),
                                    ),
                                SectionHeader(title: l10n.budgetsSavingsGoals),
                                _goalsSection(context, ref),
                                SectionHeader(
                                  title: l10n.debtsTitle,
                                  action: TextButton(
                                    onPressed: () => Navigator.of(context).push(
                                      AppPageRoute(
                                        builder: (_) => const DebtsScreen(),
                                      ),
                                    ),
                                    child: Text(l10n.budgetsViewAll),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _budgetRow(
    BuildContext context,
    Budget b,
    Category? c,
    int spent,
    String mk,
    bool hidden,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final ratio = b.limit == 0 ? 0.0 : spent / b.limit;
    final color = ratio >= 1
        ? AppColors.expense
        : ratio >= 0.8
        ? AppColors.warning
        : AppColors.income;
    final catColor = colorFromHex(c?.colorHex ?? '#9CA3AF');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Pressable(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            AppPageRoute(
              builder: (_) => BudgetDetailScreen(budgetId: b.id, month: mk),
            ),
          ),
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
                      child: Icon(
                        iconForKey(c?.iconKey ?? 'other'),
                        color: catColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        c?.name ?? l10n.budgetsFallbackName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CountUpMoney(
                          amount: spent,
                          hidden: hidden,
                          style: AppTextStyles.amount(size: 13),
                        ),
                        Text(
                          ' / ${hidden ? maskMoneyText(formatMoney(b.limit)) : formatMoney(b.limit)}',
                          style: AppTextStyles.amount(size: 13),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedProgressBar(
                  value: ratio,
                  backgroundColor: context.hairline,
                  color: color,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ratio >= 1) ...[
                      Text(
                        '${l10n.budgetsOverBy} ',
                        style: AppTextStyles.amount(
                          size: 12,
                        ).copyWith(color: AppColors.expense),
                      ),
                      CountUpMoney(
                        amount: spent - b.limit,
                        hidden: hidden,
                        style: AppTextStyles.amount(
                          size: 12,
                        ).copyWith(color: AppColors.expense),
                      ),
                    ] else ...[
                      CountUpMoney(
                        amount: b.limit - spent,
                        hidden: hidden,
                        style: AppTextStyles.amount(
                          size: 12,
                        ).copyWith(color: context.textMuted),
                      ),
                      Text(
                        ' ${l10n.budgetsLeftSuffix}',
                        style: AppTextStyles.amount(
                          size: 12,
                        ).copyWith(color: context.textMuted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _goalsSection(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(databaseProvider);
    final hidden = ref.watch(balanceHiddenProvider);
    return StreamBuilder<List<Goal>>(
      stream: db.watchGoals(),
      builder: (context, snap) {
        final goals = snap.data ?? const <Goal>[];
        if (goals.isEmpty) {
          return OutlinedButton.icon(
            onPressed: () => _addGoalDialog(context, ref),
            icon: const Icon(Icons.add),
            label: Text(l10n.budgetsAddSavingsGoal),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < goals.length; i++)
              Entrance(
                key: ValueKey(goals[i].id),
                delay: Duration(milliseconds: (i * 60).clamp(0, 300)),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Pressable(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(context).push(
                        AppPageRoute(
                          builder: (_) => GoalDetailScreen(goalId: goals[i].id),
                        ),
                      ),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  goals[i].name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${(goals[i].target == 0 ? 0 : goals[i].saved / goals[i].target * 100).toStringAsFixed(0)}%',
                                  style: AppTextStyles.amount(size: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            AnimatedProgressBar(
                              value: goals[i].target == 0
                                  ? 0.0
                                  : goals[i].saved / goals[i].target,
                              backgroundColor: context.hairline,
                              color: colorFromHex(goals[i].colorHex),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CountUpMoney(
                                      amount: goals[i].saved,
                                      hidden: hidden,
                                      style: AppTextStyles.amount(
                                        size: 12,
                                      ).copyWith(color: context.textMuted),
                                    ),
                                    Text(
                                      ' ${l10n.budgetsOfAmount(hidden ? maskMoneyText(formatMoney(goals[i].target)) : formatMoney(goals[i].target))}',
                                      style: AppTextStyles.amount(
                                        size: 12,
                                      ).copyWith(color: context.textMuted),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_circle_outline,
                                      size: 14,
                                      color: context.accent,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      l10n.budgetsAddSavings,
                                      style: TextStyle(
                                        color: context.accent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => _addGoalDialog(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l10n.budgetsAddSavingsGoal),
            ),
          ],
        );
      },
    );
  }

  Widget _debtsPreview(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(databaseProvider);
    final hidden = ref.watch(balanceHiddenProvider);
    return StreamBuilder<List<Debt>>(
      stream: db.watchDebts(isPaid: false),
      builder: (context, snap) {
        final debts = (snap.data ?? const <Debt>[]).take(3).toList();
        if (debts.isEmpty) {
          return Text(
            l10n.budgetsNoOutstandingDebts,
            style: TextStyle(color: context.textMuted),
          );
        }
        return Column(
          children: [
            for (final d in debts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Haptics.select();
                  Navigator.of(context).push(
                    AppPageRoute(
                      builder: (_) => DebtDetailScreen(debtId: d.id),
                    ),
                  );
                },
                leading: CircleAvatar(
                  backgroundColor: colorFromHex(
                    d.colorHex,
                  ).withValues(alpha: 0.2),
                  child: Text(
                    d.person.characters.first,
                    style: TextStyle(color: colorFromHex(d.colorHex)),
                  ),
                ),
                title: Text(d.person),
                subtitle: Text(
                  d.direction == 'payable' ? l10n.debtYouOwe : l10n.debtOwedToYou,
                ),
                trailing: Text(
                  hidden ? maskMoneyText(formatMoney(d.amount)) : formatMoney(d.amount),
                  style: AppTextStyles.amount(
                    size: 15,
                  ).copyWith(color: AppColors.expense),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _addBudgetDialog(
    BuildContext context,
    WidgetRef ref,
    String mk,
  ) => showBudgetFormSheet(context, ref, monthKey: mk);

  Future<void> _addGoalDialog(BuildContext context, WidgetRef ref) =>
      showGoalFormSheet(context, ref);
}
