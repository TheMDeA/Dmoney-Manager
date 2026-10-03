import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// Bottom sheet for fast expense/income recording — the app's core loop.
class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _kind = 'expense';
  int? _categoryId;
  int? _walletId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Padding(
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                  children: [
                    for (final c in cats) _categoryChip(c),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Wallet>>(
              stream: db.watchWallets(),
              builder: (context, snap) {
                final wallets = snap.data ?? const <Wallet>[];
                _walletId ??= wallets.isNotEmpty ? wallets.first.id : null;
                return DropdownButtonFormField<int>(
                  initialValue: _walletId,
                  decoration: const InputDecoration(labelText: 'Wallet'),
                  items: [
                    for (final w in wallets)
                      DropdownMenuItem(value: w.id, child: Text(w.name)),
                  ],
                  onChanged: (v) => setState(() => _walletId = v),
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
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(formatDate(_date)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(labelText: 'Note (optional)'),
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
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(Category c) {
    final selected = _categoryId == c.id;
    final color = colorFromHex(c.colorHex);
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconForKey(c.iconKey), size: 16, color: selected ? Colors.black : color),
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
    await ref.read(databaseProvider).addTransaction(
          TransactionsCompanion.insert(
            walletId: _walletId!,
            categoryId: _categoryId!,
            kind: _kind,
            amount: amount,
            note: Value(_noteCtrl.text.trim()),
            date: _date,
          ),
        );
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_kind == 'income' ? 'Income' : 'Expense'} of ${formatIDR(amount)} saved',
          ),
        ),
      );
    }
  }
}
