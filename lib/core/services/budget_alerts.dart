import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../utils/app_locale.dart';
import '../utils/cash_basis.dart';
import '../utils/formatters.dart';
import 'app_prefs.dart';
import 'notification_service.dart';

/// Fires a local notification the first time a monthly budget crosses
/// 80% and 100% of its limit.
Future<void> checkBudgetAlerts(WidgetRef ref) async {
  if (!AppPrefs.budgetAlerts) return;
  final db = ref.read(databaseProvider);
  final now = DateTime.now();
  final mk = monthKey(now);
  final monthStart = DateTime(now.year, now.month);

  final budgets = await db.watchBudgets(mk).first;
  if (budgets.isEmpty) return;
  final txs = await db.getTransactionsInRange(monthStart, now);
  final cats = {
    for (final c in await db.select(db.categories).get()) c.id: c.name,
  };

  // Cash basis: a paylater purchase is unpaid borrowing and must not
  // trigger alerts, while an installment paid this month counts toward
  // its purchase's category budget. Wallet kinds decide what counts
  // (see cashExpenseOf); installment transfers are attributed through
  // their purchase's category, and an unlinked transfer into paylater
  // counts toward no budget (its own category is the hidden Transfer
  // category, which no budget uses).
  final walletKinds = {
    for (final w in await db.select(db.wallets).get()) w.id: w.kind,
  };
  final purchaseCategories = await db.planPurchaseCategories();
  final spentByCat = <int, int>{};
  for (final d in txs) {
    final t = d.transaction;
    if (cashExpenseOf(
          kind: t.kind,
          sourceWalletKind: walletKinds[t.walletId] ?? '',
          destWalletKind: t.toWalletId == null
              ? null
              : walletKinds[t.toWalletId],
          amount: t.amount,
        ) ==
        0) {
      continue;
    }
    final categoryId = spendingCategoryOf(
      t: t,
      fallbackCategoryId: t.categoryId,
      purchaseCategoryByPlanId: purchaseCategories,
    );
    spentByCat[categoryId] = (spentByCat[categoryId] ?? 0) + t.amount;
  }

  for (final b in budgets) {
    final spent = spentByCat[b.categoryId] ?? 0;
    if (b.limit <= 0) continue;
    final percent = (spent / b.limit * 100).floor();
    for (final level in [80, 100]) {
      if (percent >= level && !AppPrefs.budgetLevelNotified(b.id, mk, level)) {
        await NotificationService.showBudgetAlert(
          budgetId: b.id,
          categoryName:
              cats[b.categoryId] ??
              localizedOrFallback((l) => l.notifBudgetFallback, 'Budget'),
          percent: percent,
          over: level == 100,
        );
        await AppPrefs.markBudgetLevelNotified(b.id, mk, level);
      }
    }
  }
}
