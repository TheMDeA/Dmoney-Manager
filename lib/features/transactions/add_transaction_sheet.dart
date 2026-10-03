import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/budget_alerts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// Bottom sheet for fast expense/income recording — the app's core loop.
/// Also used for editing: pass [existing] to prefill and update instead of
/// inserting. [attachedPhotoPath] attaches a receipt photo right after saving.
class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({
    super.key,
    this.initialKind = 'expense',
    this.existing,
    this.attachedPhotoPath,
  });

  final String initialKind;
  final TransactionWithDetails? existing;
  final String? attachedPhotoPath;

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late String _kind;
  int? _categoryId;
  int? _walletId;
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _success = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _kind = e.transaction.kind;
      _amountCtrl.text = e.transaction.amount.toString();
      _noteCtrl.text = e.transaction.note;
      _categoryId = e.transaction.categoryId;
      _walletId = e.transaction.walletId;
      _date = e.transaction.date;
    } else {
      _kind = widget.initialKind;
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
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_editing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Edit record',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
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
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppTextStyles.displayBalance.copyWith(fontSize: 36),
                  decoration: const InputDecoration(
                    prefixText: 'Rp ',
                    hintText: '0',
                    border: InputBorder.none,
                    filled: false,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Category', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                StreamBuilder<List<Category>>(
                  stream: db.watchCategories(kind: _kind, topLevelOnly: true),
                  builder: (context, snap) {
                    final cats = snap.data ?? const <Category>[];
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (final c in cats) _categoryChip(c)],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text('Wallet', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                StreamBuilder<List<Wallet>>(
                  stream: db.watchWallets(),
                  builder: (context, snap) {
                    final wallets = snap.data ?? const <Wallet>[];
                    _walletId ??= wallets.isNotEmpty ? wallets.first.id : null;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final w in wallets)
                          ChoiceChip(
                            label: Text(w.name),
                            selected: _walletId == w.id,
                            selectedColor: AppColors.lime,
                            labelStyle: TextStyle(
                              color: _walletId == w.id
                                  ? Colors.black
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) => setState(() => _walletId = w.id),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => _date = picked);
                        },
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                        label: Text(formatDate(_date)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _noteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Note (optional)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.lime,
                    foregroundColor: Colors.black,
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _editing ? 'Save changes' : 'Save',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
          ),
        ),
        if (_success) const _SuccessOverlay(),
      ],
    );
  }

  Widget _categoryChip(Category c) {
    final selected = _categoryId == c.id;
    final color = colorFromHex(c.colorHex);
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconForKey(c.iconKey),
            size: 16,
            color: selected ? Colors.black : color,
          ),
          const SizedBox(width: 6),
          Text(c.name),
        ],
      ),
      selected: selected,
      selectedColor: AppColors.lime,
      onSelected: (_) => setState(() => _categoryId = c.id),
    );
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0 || _categoryId == null || _walletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount, category and wallet')),
      );
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    try {
      if (_editing) {
        final e = widget.existing!.transaction;
        await db.updateTransaction(
          id: e.id,
          walletId: _walletId!,
          categoryId: _categoryId!,
          kind: _kind,
          amount: amount,
          note: _noteCtrl.text.trim(),
          date: _date,
        );
      } else {
        final id = await db.addTransaction(
          TransactionsCompanion.insert(
            walletId: _walletId!,
            categoryId: _categoryId!,
            kind: _kind,
            amount: amount,
            note: Value(_noteCtrl.text.trim()),
            date: _date,
          ),
        );
        if (widget.attachedPhotoPath != null) {
          await db.addPhoto(id, widget.attachedPhotoPath!);
        }
      }
      await checkBudgetAlerts(ref);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    // Brief success state (checkmark + scale animation), then close.
    HapticFeedback.mediumImpact();
    setState(() => _success = true);
    await Future.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _editing
              ? 'Record updated'
              : '${_kind == 'income' ? 'Income' : 'Expense'} of ${formatIDR(amount)} saved',
        ),
      ),
    );
  }
}

/// Brief success state: lime checkmark with a springy scale-in,
/// shown inside the sheet before it closes.
class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Theme.of(
          context,
        ).scaffoldBackgroundColor.withValues(alpha: 0.85),
        alignment: Alignment.center,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.4, end: 1.0),
          duration: const Duration(milliseconds: 350),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.lime,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.black, size: 44),
          ),
        ),
      ),
    );
  }
}
