import 'dart:convert';

import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/sync_conflicts_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// "Sync conflicts" (Settings): rows another device overwrote
/// with a newer change, kept here so the overwritten version can
/// be restored. Restore applies the kept copy as a new local edit
/// — it then pushes as the newest change. Dismiss drops the kept
/// copy without restoring it.
class SyncConflictsScreen extends ConsumerWidget {
  const SyncConflictsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncConflictsTitle)),
      body: StreamBuilder<List<SyncConflict>>(
        stream: db.watchSyncConflicts(),
        builder: (context, snapshot) {
          final conflicts = snapshot.data ?? const [];
          if (conflicts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.syncConflictsEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textMuted),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
            itemCount: conflicts.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _ConflictTile(conflict: conflicts[index]),
          );
        },
      ),
    );
  }
}

class _ConflictTile extends ConsumerStatefulWidget {
  const _ConflictTile({required this.conflict});

  final SyncConflict conflict;

  @override
  ConsumerState<_ConflictTile> createState() => _ConflictTileState();
}

class _ConflictTileState extends ConsumerState<_ConflictTile> {
  bool _busy = false;

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    bool ok = false;
    try {
      ok = await SyncConflictService(
        ref.read(databaseProvider),
      ).restoreConflict(widget.conflict);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? l10n.syncConflictsRestored
              : l10n.syncConflictsRestoreFailed,
        ),
      ),
    );
  }

  Future<void> _dismiss() async {
    await SyncConflictService(
      ref.read(databaseProvider),
    ).dismissConflict(widget.conflict.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final payload =
        jsonDecode(widget.conflict.losingJson) as Map<String, dynamic>;
    return ListTile(
      title: Text(_summaryText(payload)),
      subtitle: Text(
        '${_tableLabel(widget.conflict.targetTable)} • '
        '${l10n.syncConflictsOverwritten(formatDate(widget.conflict.overwrittenAt))}',
        style: TextStyle(color: context.textMuted, fontSize: 12),
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: _restore,
                  child: Text(l10n.syncConflictsRestore),
                ),
                IconButton(
                  onPressed: _dismiss,
                  icon: const Icon(Icons.close),
                  tooltip: l10n.syncConflictsDismiss,
                ),
              ],
            ),
    );
  }
}

/// One-line summary of the kept row: its most identifying text
/// (name, person, note, keyword, month) plus its amount when the
/// row carries one.
String _summaryText(Map<String, dynamic> payload) {
  final parts = <String>[];
  final title = _firstNonEmpty([
    payload['name'],
    payload['person'],
    payload['note'],
    payload['keyword'],
    payload['month'],
  ]);
  if (title != null) parts.add(title);
  final amount =
      payload['amount'] as num? ??
      payload['limit'] as num? ??
      payload['total_amount'] as num?;
  if (amount != null) parts.add(formatMoney(amount.toInt()));
  if (parts.isEmpty) return payload['sync_id'] as String? ?? '';
  return parts.join(' • ');
}

String? _firstNonEmpty(List<Object?> values) {
  for (final v in values) {
    if (v is String && v.isNotEmpty) return v;
  }
  return null;
}

/// Human label for a sync table name. The names are technical
/// identifiers, so they stay English — the surrounding chrome is
/// localised.
String _tableLabel(String table) => switch (table) {
  'accounts' => 'Account',
  'wallets' => 'Wallet',
  'categories' => 'Category',
  'transactions' => 'Transaction',
  'transaction_photos' => 'Receipt photo',
  'budgets' => 'Budget',
  'goals' => 'Goal',
  'debts' => 'Debt',
  'debt_payments' => 'Debt payment',
  'goal_deposits' => 'Goal deposit',
  'recurring_transactions' => 'Recurring rule',
  'transaction_templates' => 'Template',
  'category_keywords' => 'Keyword',
  'installment_plans' => 'Installment plan',
  _ => table,
};
