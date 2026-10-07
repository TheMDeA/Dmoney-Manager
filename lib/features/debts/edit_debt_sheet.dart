import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_accents.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/shaker.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// Result of the edit-debt sheet, applied by the caller via
/// `AppDatabase.updateDebt`.
class DebtEditInput {
  DebtEditInput({
    required this.person,
    required this.note,
    required this.amount,
    required this.dueDate,
    required this.walletId,
    required this.recordAsTransaction,
  });

  final String person;
  final String note;
  final int amount;
  final DateTime? dueDate;
  final int? walletId;
  final bool recordAsTransaction;
}

/// "Edit debt" as a bottom sheet, matching the other form sheets
/// (and the add-debt sheet): section labels, large amount entry,
/// date pill, wallet chips, and inline validation. Direction, color,
/// and creation date are not editable after creation.
class EditDebtSheet extends ConsumerStatefulWidget {
  const EditDebtSheet({super.key, required this.debt});

  final Debt debt;

  @override
  ConsumerState<EditDebtSheet> createState() => _EditDebtSheetState();
}

class _EditDebtSheetState extends ConsumerState<EditDebtSheet> {
  late final TextEditingController _personCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _amountCtrl;
  DateTime? _dueDate;
  int? _walletId;
  late bool _noWallet;
  late bool _recordTx;
  bool _saving = false;

  String? _personError;
  String? _amountError;
  final _personShake = ShakeController();
  final _amountShake = ShakeController();

  @override
  void initState() {
    super.initState();
    final debt = widget.debt;
    _personCtrl = TextEditingController(text: debt.person);
    _noteCtrl = TextEditingController(text: debt.note);
    _amountCtrl =
        TextEditingController(text: formatAmountInput(debt.amount));
    _dueDate = debt.dueDate;
    _walletId = debt.walletId;
    _noWallet = debt.walletId == null;
    _recordTx = debt.recordAsTransaction;
    _personCtrl.addListener(_clearPersonError);
    _amountCtrl.addListener(_clearAmountError);
  }

  void _clearPersonError() {
    if (_personError != null) setState(() => _personError = null);
  }

  void _clearAmountError() {
    if (_amountError != null) setState(() => _amountError = null);
  }

  @override
  void dispose() {
    _personCtrl.removeListener(_clearPersonError);
    _amountCtrl.removeListener(_clearAmountError);
    _personCtrl.dispose();
    _noteCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  /// Inline field error, styled like the other form sheets.
  Widget _fieldError(String? message) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return FormSheet(
      title: 'Edit debt',
      actionLabel: 'Save',
      onAction: _save,
      busy: _saving,
      children: [
        const FormSectionLabel('Person'),
        const SizedBox(height: 8),
        Shaker(
          controller: _personShake,
          child: TextField(
            controller: _personCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Who is this debt with?',
              errorText: _personError,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Shaker(
          controller: _amountShake,
          child: FormAmountEntry(controller: _amountCtrl),
        ),
        _fieldError(_amountError),
        const SizedBox(height: 16),
        const FormSectionLabel('Note (optional)'),
        const SizedBox(height: 8),
        TextField(
          controller: _noteCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'What was it for?',
          ),
        ),
        const SizedBox(height: 16),
        const FormSectionLabel('Due date (optional)'),
        const SizedBox(height: 8),
        FormDatePill(
          date: _dueDate,
          placeholder: 'No due date',
          onClear:
              _dueDate == null ? null : () => setState(() => _dueDate = null),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate:
                  _dueDate ?? DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            );
            if (picked != null) setState(() => _dueDate = picked);
          },
        ),
        const SizedBox(height: 16),
        const FormSectionLabel('Wallet'),
        const SizedBox(height: 8),
        StreamBuilder<List<Wallet>>(
          stream: db.watchWallets(),
          builder: (context, snap) {
            final wallets = snap.data ?? const <Wallet>[];
            if (_walletId != null &&
                wallets.every((w) => w.id != _walletId)) {
              _walletId = null;
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
            if (v) _walletId = null;
          }),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show in transaction history'),
          subtitle: const Text('Record this debt as a transaction'),
          value: _recordTx,
          onChanged: (v) => setState(() => _recordTx = v),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final person = _personCtrl.text.trim();
    final amount = parseAmountInput(_amountCtrl.text);
    final personError = person.isEmpty ? 'Please enter a name' : null;
    final amountError = amount <= 0 ? 'Please enter an amount' : null;
    setState(() {
      _personError = personError;
      _amountError = amountError;
    });
    if (personError != null || amountError != null) {
      if (personError != null) _personShake.shake();
      if (amountError != null) _amountShake.shake();
      return;
    }
    setState(() => _saving = true);
    if (mounted) {
      Navigator.pop(
        context,
        DebtEditInput(
          person: person,
          note: _noteCtrl.text.trim(),
          amount: amount,
          dueDate: _dueDate,
          walletId: _noWallet ? null : _walletId,
          recordAsTransaction: _recordTx,
        ),
      );
    }
  }
}
