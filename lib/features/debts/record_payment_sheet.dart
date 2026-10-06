import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_accents.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/form_sheet.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// Result of the record-payment sheet, applied by the caller via
/// `AppDatabase.recordDebtPayment`.
class DebtPaymentInput {
  DebtPaymentInput({
    required this.amount,
    required this.date,
    required this.note,
    required this.walletId,
  });

  final int amount;
  final DateTime date;
  final String note;
  final int? walletId;
}

/// "Record payment" as a bottom sheet, matching the other form sheets:
/// large amount entry, note, wallet chips, and a date pill.
class RecordPaymentSheet extends ConsumerStatefulWidget {
  const RecordPaymentSheet({super.key, required this.debt});

  final Debt debt;

  @override
  ConsumerState<RecordPaymentSheet> createState() =>
      _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<RecordPaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  int? _walletId;
  bool _noWallet = false;
  bool _walletDefaulted = false;
  bool _saving = false;

  String? _amountError;

  bool get _receivable => widget.debt.direction == 'receivable';

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return FormSheet(
      title: _receivable ? 'Record received' : 'Record payment',
      actionLabel: 'Save',
      onAction: _save,
      busy: _saving,
      children: [
        FormAmountEntry(controller: _amountCtrl, autofocus: true),
        if (_amountError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _amountError!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 16),
        const FormSectionLabel('Note (optional)'),
        const SizedBox(height: 8),
        TextField(
          controller: _noteCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'What was this payment for?',
          ),
        ),
        const SizedBox(height: 16),
        const FormSectionLabel('Wallet'),
        const SizedBox(height: 8),
        StreamBuilder<List<Wallet>>(
          stream: db.watchWallets(),
          builder: (context, snap) {
            final wallets = snap.data ?? const <Wallet>[];
            if (!_walletDefaulted && wallets.isNotEmpty) {
              _walletDefaulted = true;
              _walletId = widget.debt.walletId;
              if (_walletId != null &&
                  wallets.every((w) => w.id != _walletId)) {
                _walletId = null;
              }
              _walletId ??= wallets.first.id;
              _noWallet = false;
            } else if (_walletDefaulted &&
                _walletId != null &&
                wallets.isNotEmpty &&
                wallets.every((w) => w.id != _walletId)) {
              _walletId = null;
              _noWallet = true;
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final w in wallets)
                  ChoiceChip(
                    label: Text(w.name),
                    selected: _walletId == w.id,
                    selectedColor: context.accent,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: _walletId == w.id
                          ? onAccent(context.accent)
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() {
                      _walletId = w.id;
                      _noWallet = false;
                    }),
                  ),
              ],
            );
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Don't use wallet"),
          value: _noWallet,
          onChanged: (v) => setState(() {
            _noWallet = v;
            if (v) {
              _walletId = null;
            }
          }),
        ),
        const SizedBox(height: 8),
        const FormSectionLabel('Date'),
        const SizedBox(height: 8),
        FormDatePill(
          date: _date,
          placeholder: 'Pick a date',
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() => _date = DateTime(
                  picked.year, picked.month, picked.day, _date.hour, _date.minute));
            }
          },
        ),
      ],
    );
  }

  Future<void> _save() async {
    final amount = parseAmountInput(_amountCtrl.text);
    if (amount <= 0) {
      setState(() => _amountError = 'Please enter an amount');
      return;
    }
    setState(() => _saving = true);
    if (mounted) {
      Navigator.pop(
        context,
        DebtPaymentInput(
          amount: amount,
          date: _date,
          note: _noteCtrl.text.trim(),
          walletId: _noWallet ? null : _walletId,
        ),
      );
    }
  }
}
