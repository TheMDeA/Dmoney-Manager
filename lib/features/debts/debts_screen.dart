import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_prefs.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// Debt tracking: Payable / Receivable tabs, outstanding vs paid sections.
class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  String _direction = 'payable';

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debts'),
        actions: [
          IconButton(
            tooltip: 'Add debt',
            onPressed: () => _addDebtDialog(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<List<Debt>>(
        stream: db.watchDebts(direction: _direction),
        builder: (context, snap) {
          final debts = snap.data ?? const <Debt>[];
          final outstanding = debts.where((d) => !d.isPaid).toList();
          final paid = debts.where((d) => d.isPaid).toList();
          final outstandingTotal =
              outstanding.fold<int>(0, (s, d) => s + d.amount);
          final paidTotal = paid.fold<int>(0, (s, d) => s + d.amount);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Center(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'payable', label: Text('PAYABLE')),
                    ButtonSegment(value: 'receivable', label: Text('RECEIVABLE')),
                  ],
                  selected: {_direction},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _direction = s.first),
                ),
              ),
              const SizedBox(height: 12),
              _band(context, _direction == 'payable' ? 'Not yet pay' : 'Not yet received',
                  outstandingTotal),
              if (outstanding.isEmpty)
                const EmptyState(
                    icon: Icons.handshake_outlined, message: 'Nothing outstanding.')
              else
                for (final d in outstanding) _debtTile(context, ref, d, false),
              const SizedBox(height: 8),
              _band(context, _direction == 'payable' ? 'Paid' : 'Received', paidTotal),
              for (final d in paid) _debtTile(context, ref, d, true),
            ],
          );
        },
      ),
    );
  }

  Widget _band(BuildContext context, String label, int total) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              TextSpan(text: '$label  '),
              TextSpan(
                text: formatIDR(total),
                style: const TextStyle(
                    color: AppColors.expense, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _debtTile(BuildContext context, WidgetRef ref, Debt d, bool paid) {
    final color = colorFromHex(d.colorHex);
    return Dismissible(
      key: ValueKey(d.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.check, color: AppColors.income),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.undo, color: AppColors.warning),
      ),
      confirmDismiss: (direction) async {
        final nowPaid = !d.isPaid;
        await ref.read(databaseProvider).setDebtPaid(d.id, nowPaid);
        if (nowPaid) {
          await NotificationService.cancelDebtReminder(d.id);
        } else if (d.dueDate != null && AppPrefs.debtReminders) {
          await NotificationService.scheduleDebtReminder(
            debtId: d.id,
            person: d.person,
            amount: d.amount,
            payable: d.direction == 'payable',
            dueDate: d.dueDate!,
          );
        }
        return false;
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        leading: CircleAvatar(
          backgroundColor: color,
          child: Text(
            d.person.characters.first.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(d.person, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (d.note.isNotEmpty)
              Text(d.note,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            if (!paid && d.dueDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Due ${formatDate(d.dueDate!)}',
                      style: const TextStyle(
                          color: AppColors.warning, fontSize: 11)),
                ),
              ),
          ],
        ),
        trailing: Text(
          formatIDR(d.amount),
          style: AppTextStyles.amount(size: 15).copyWith(
            color: AppColors.expense,
            decoration: paid ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }

  Future<void> _addDebtDialog(BuildContext context, WidgetRef ref) async {
    final personCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String direction = _direction;
    DateTime? dueDate;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add debt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: personCtrl, decoration: const InputDecoration(labelText: 'Person')),
                const SizedBox(height: 12),
                TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)')),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (Rp)'),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'payable', label: Text('I owe')),
                    ButtonSegment(value: 'receivable', label: Text('Owes me')),
                  ],
                  selected: {direction},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => direction = s.first),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) setState(() => dueDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(dueDate == null ? 'Due date (optional)' : formatDate(dueDate!)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    final amount = int.tryParse(amountCtrl.text) ?? 0;
    if (saved == true && personCtrl.text.trim().isNotEmpty && amount > 0) {
      final id = await ref.read(databaseProvider).addDebt(DebtsCompanion.insert(
            person: personCtrl.text.trim(),
            note: Value(noteCtrl.text.trim()),
            amount: amount,
            direction: direction,
            dueDate: Value(dueDate),
          ));
      if (dueDate != null && AppPrefs.debtReminders) {
        final dd = dueDate!;
        await NotificationService.scheduleDebtReminder(
          debtId: id,
          person: personCtrl.text.trim(),
          amount: amount,
          payable: direction == 'payable',
          dueDate: dd,
        );
      }
    }
  }
}
