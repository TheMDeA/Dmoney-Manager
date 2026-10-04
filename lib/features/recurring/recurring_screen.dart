import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_prefs.dart';
import '../../core/services/subscription_detector.dart';
import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/app_page_route.dart';
import '../../core/widgets/entrance.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'recurring_form_screen.dart';

String _freqLabel(String f) => '${f[0].toUpperCase()}${f.substring(1)}';

/// All recurring transaction rules, with pause/resume and delete — plus a
/// subscription detector that mines the history for repeating charges and
/// offers to turn them into rules.
class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  bool _scanning = false;

  /// Mines the history for repeating charges and shows the candidates.
  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      final db = ref.read(databaseProvider);
      final txs = await db.learnableTransactions();
      var found = detectSubscriptions(txs);
      if (!mounted) return;
      // Drop dismissed detections and charges that already have a rule.
      final dismissed = AppPrefs.dismissedDetections.toSet();
      final rules = await db.watchRecurringTransactions().first;
      final ruledNotes = {
        for (final r in rules) r.note.trim().toLowerCase(),
      };
      found = found
          .where((d) =>
              !dismissed.contains(d.fingerprint) &&
              !ruledNotes.contains(d.note.trim().toLowerCase()))
          .toList();
      if (!mounted) return;
      if (found.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No repeating charges found in your history')),
        );
        return;
      }
      Haptics.medium();
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _DetectionSheet(initial: found),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring transactions'),
        actions: [
          if (_scanning)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Detect subscriptions',
              icon: const Icon(Icons.manage_search_outlined),
              onPressed: _scan,
            ),
        ],
      ),
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
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _scan,
                      icon: const Icon(Icons.manage_search_outlined,
                          size: 18),
                      label: const Text('Detect subscriptions'),
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

/// Bottom sheet listing detected subscriptions. Each can be turned into a
/// recurring rule or dismissed (dismissals never resurface).
class _DetectionSheet extends ConsumerStatefulWidget {
  const _DetectionSheet({required this.initial});

  final List<DetectedSubscription> initial;

  @override
  ConsumerState<_DetectionSheet> createState() => _DetectionSheetState();
}

class _DetectionSheetState extends ConsumerState<_DetectionSheet> {
  late final List<DetectedSubscription> _candidates = [...widget.initial];

  Future<void> _dismiss(DetectedSubscription d) async {
    await AppPrefs.dismissDetection(d.fingerprint);
    if (mounted) {
      setState(() => _candidates.remove(d));
      if (_candidates.isEmpty) Navigator.of(context).pop();
    }
  }

  Future<void> _createRule(DetectedSubscription d) async {
    final db = ref.read(databaseProvider);
    await db.addRecurringTransaction(
      RecurringTransactionsCompanion.insert(
        walletId: d.walletId,
        categoryId: d.categoryId,
        kind: 'expense',
        amount: d.amount,
        note: Value(d.note),
        frequency: d.frequency,
        nextDue: d.nextExpected,
      ),
    );
    await AppPrefs.dismissDetection(d.fingerprint);
    Haptics.medium();
    if (mounted) {
      setState(() => _candidates.remove(d));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rule created for "${d.note}"')),
      );
      if (_candidates.isEmpty) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Possible subscriptions',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Repeating charges found in your history. Add the ones you recognize as subscriptions.',
                    style: TextStyle(
                        color: context.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: _candidates.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final d = _candidates[i];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            context.accent.withValues(alpha: 0.16),
                        child: Icon(Icons.subscriptions_outlined,
                            color: context.accent, size: 20),
                      ),
                      title: Text(
                        d.note,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${_freqLabel(d.frequency)} · ${formatMoney(d.amount)} · '
                        '${d.occurrences} found · next ~${formatDate(d.nextExpected)}',
                        style: TextStyle(
                            color: context.textMuted, fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Not a subscription',
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => _dismiss(d),
                          ),
                          FilledButton(
                            onPressed: () => _createRule(d),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
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
}
