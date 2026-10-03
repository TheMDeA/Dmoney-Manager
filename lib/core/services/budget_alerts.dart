import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
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
    for (final c in await db.select(db.categories).get()) c.id: c.name
  };

  for (final b in budgets) {
    final spent = txs
        .where((d) =>
            d.transaction.kind == 'expense' &&
            d.transaction.categoryId == b.categoryId)
        .fold<int>(0, (s, d) => s + d.transaction.amount);
    if (b.limit <= 0) continue;
    final percent = (spent / b.limit * 100).floor();
    for (final level in [80, 100]) {
      if (percent >= level &&
          !AppPrefs.budgetLevelNotified(b.id, mk, level)) {
        await NotificationService.showBudgetAlert(
          budgetId: b.id,
          categoryName: cats[b.categoryId] ?? 'Budget',
          percent: percent,
          over: level == 100,
        );
        await AppPrefs.markBudgetLevelNotified(b.id, mk, level);
      }
    }
  }
}
