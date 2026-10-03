import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/amount_field.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

const _frequencies = ['daily', 'weekly', 'monthly', 'yearly'];

String _freqLabel(String f) => '${f[0].toUpperCase()}${f.substring(1)}';

/// Add/edit a recurring transaction rule (subscription, salary, rent…).
/// Due occurrences are materialized as real transactions on app start.
class RecurringFormScreen extends ConsumerStatefulWidget {
  const RecurringFormScreen({super.key, this.existing});

  final RecurringTransaction? existing;

  @override
  ConsumerState<RecurringFormScreen> createState() =>
      _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late String _kind;
  int? _categoryId;
  int? _walletId;
  late String _frequency;
  late DateTime _firstDue;
  DateTime? _endDate;
  late bool _active;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _kind = e.kind;
      _amountCtrl.text = formatAmountInput(e.amount);
      _noteCtrl.text = e.note;
      _categoryId = e.categoryId;
      _walletId = e.walletId;
      _frequency = e.frequency;
      _firstDue = e.nextDue;
      _endDate = e.endDate;
      _active = e.active;
    } else {
      _kind = 'expense';
      _frequency = 'monthly';
      final now = DateTime.now();
      _firstDue = DateTime(now.year, now.month, now.day, now.hour, now.minute);
      _active = true;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit recurring' : 'New recurring'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(db),
            child: const Text('SAVE'),
          ),
        ],
      ),
      body: StreamBuilder<List<Wallet>>(
        stream: db.watchWallets(),
        builder: (context, snap) {
          final wallets = snap.data ?? const <Wallet>[];
          if (_walletId != null && wallets.every((w) => w.id != _walletId)) {
            _walletId = null;
          }
          _walletId ??= wallets.isNotEmpty ? wallets.first.id : null;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'expense', label: Text('Expense')),
                    ButtonSegment(value: 'income', label: Text('Income')),
                  ],
                  selected: {_kind},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() {
                    _kind = s.first;
                    _categoryId = null;
                  }),
                ),
                const SizedBox(height: 16),
                AmountField(
                  controller: _amountCtrl,
                  style:
                      AppTextStyles.displayBalance.copyWith(fontSize: 36),
                ),
                const SizedBox(height: 8),
                Text('Note',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Netflix subscription',
                  ),
                ),
                const SizedBox(height: 16),
                Text('Category',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                StreamBuilder<List<Category>>(
                  stream: db.watchCategories(kind: _kind, topLevelOnly: true),
                  builder: (context, snap) {
                    final cats = snap.data ?? const <Category>[];
                    if (_categoryId != null &&
                        cats.every((c) => c.id != _categoryId)) {
                      _categoryId = null;
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (final c in cats) _categoryChip(c)],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text('Wallet',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final w in wallets) _walletChip(w)],
                ),
                const SizedBox(height: 16),
                Text('Repeats',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in _frequencies)
                      ChoiceChip(
                        label: Text(_freqLabel(f)),
                        selected: _frequency == f,
                        selectedColor: context.accent,
                        labelStyle: TextStyle(
                          color: _frequency == f
                              ? onAccent(context.accent)
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) =>
                            setState(() => _frequency = f),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _dateField(
                        label: 'First due',
                        date: _firstDue,
                        onPick: (d) => setState(() => _firstDue = d),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dateField(
                        label: 'Ends',
                        date: _endDate,
                        emptyText: 'Never',
                        onPick: (d) => setState(() => _endDate = d),
                        onClear: _endDate == null
                            ? null
                            : () => setState(() => _endDate = null),
                      ),
                    ),
                  ],
                ),
                if (_editing) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    subtitle: Text(
                      'Paused rules stop generating transactions',
                      style: TextStyle(
                          color: context.textMuted, fontSize: 12),
                    ),
                    value: _active,
                    activeThumbColor: context.accent,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Due occurrences are added automatically when you open the app.',
                  style: TextStyle(
                      color: context.textMuted, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _categoryChip(Category c) {
    final selected = _categoryId == c.id;
    final color = colorFromHex(c.colorHex);
    return ChoiceChip(
      avatar: Icon(iconForKey(c.iconKey),
          size: 18, color: selected ? onAccent(color) : color),
      label: Text(c.name),
      selected: selected,
      selectedColor: color,
      labelStyle: TextStyle(
        color: selected
            ? onAccent(color)
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => setState(() => _categoryId = c.id),
    );
  }

  Widget _walletChip(Wallet w) {
    final selected = _walletId == w.id;
    return ChoiceChip(
      label: Text(w.name),
      selected: selected,
      selectedColor: context.accent,
      labelStyle: TextStyle(
        color: selected
            ? onAccent(context.accent)
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => setState(() => _walletId = w.id),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? date,
    required ValueChanged<DateTime> onPick,
    String emptyText = '',
    VoidCallback? onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? now,
              firstDate: DateTime(2020),
              lastDate: now.add(const Duration(days: 365 * 5)),
            );
            if (picked != null) onPick(picked);
          },
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text(date == null ? emptyText : formatDate(date)),
        ),
        if (onClear != null)
          TextButton(
            onPressed: onClear,
            child: const Text('Clear end date'),
          ),
      ],
    );
  }

  Future<void> _save(AppDatabase db) async {
    final amount = parseAmountInput(_amountCtrl.text);
    if (amount <= 0 || _categoryId == null || _walletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter an amount, category and wallet')),
      );
      return;
    }
    if (_endDate != null && _endDate!.isBefore(_firstDue)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date is before the first due date')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (_editing) {
        await db.updateRecurringTransaction(
          widget.existing!.id,
          RecurringTransactionsCompanion(
            walletId: Value(_walletId!),
            categoryId: Value(_categoryId!),
            kind: Value(_kind),
            amount: Value(amount),
            note: Value(_noteCtrl.text.trim()),
            frequency: Value(_frequency),
            nextDue: Value(_firstDue),
            endDate: Value(_endDate),
            active: Value(_active),
          ),
        );
      } else {
        await db.addRecurringTransaction(
          RecurringTransactionsCompanion.insert(
            walletId: _walletId!,
            categoryId: _categoryId!,
            kind: _kind,
            amount: amount,
            note: Value(_noteCtrl.text.trim()),
            frequency: _frequency,
            nextDue: _firstDue,
          ),
        );
        // A rule starting in the past generates its missed occurrences now.
        await db.processDueRecurringTransactions();
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
