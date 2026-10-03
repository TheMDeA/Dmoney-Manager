import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_page_route.dart';
import '../../core/widgets/entrance.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'recurring_form_screen.dart';

String _freqLabel(String f) => '${f[0].toUpperCase()}${f.substring(1)}';

/// All recurring transaction rules, with pause/resume and delete.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring transactions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          AppPageRoute(builder: (_) => const RecurringFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<RecurringTransaction>>(
        stream: db.watchRecurringTransactions(),
        builder: (context, snap) {
          final rules = snap.data ?? const <RecurringTransaction>[];
          if (rules.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat_outlined,
                        size: 56, color: context.textMuted),
                    const SizedBox(height: 16),
                    const Text(
                      'No recurring transactions yet',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Subscriptions, salary, rent — due amounts are added automatically when you open the app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: context.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }
          return StreamBuilder<List<Category>>(
            stream: db.watchCategories(),
            builder: (context, catSnap) {
              final cats = {
                for (final c in (catSnap.data ?? const <Category>[])) c.id: c
              };
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: rules.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = rules[i];
                  return Entrance(
                    key: ValueKey(r.id),
                    delay: Duration(milliseconds: (i * 50).clamp(0, 250)),
                    child: _ruleTile(context, db, r, cats[r.categoryId]?.name),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _ruleTile(BuildContext context, AppDatabase db,
      RecurringTransaction r, String? categoryName) {
    return Opacity(
      opacity: r.active ? 1 : 0.55,
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: context.accent.withValues(alpha: 0.16),
            child: Icon(Icons.repeat, color: context.accent, size: 20),
          ),
          title: Text(
            r.note.isEmpty ? (categoryName ?? 'Recurring') : r.note,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${_freqLabel(r.frequency)} · next ${formatDate(r.nextDue)}'
            '${r.endDate == null ? '' : ' · ends ${formatDate(r.endDate!)}'}',
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatSignedMoney(r.amount, isIncome: r.kind == 'income'),
                style: AppTextStyles.amount(size: 15).copyWith(
                  color: r.kind == 'income'
                      ? AppColors.income
                      : AppColors.expense,
                ),
              ),
              Switch(
                value: r.active,
                activeThumbColor: context.accent,
                onChanged: (v) => db.setRecurringActive(r.id, v),
              ),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            AppPageRoute(builder: (_) => RecurringFormScreen(existing: r)),
          ),
          onLongPress: () => _confirmDelete(context, db, r),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, AppDatabase db, RecurringTransaction r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recurring rule?'),
        content: const Text(
            'Future occurrences stop. Transactions already created are kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expense,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await db.deleteRecurringTransaction(r.id);
    }
  }
}
