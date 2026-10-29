import 'package:flutter/material.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/shaker.dart';
import '../../data/database/app_database.dart';

/// Result of the goal deposit/withdraw sheet.
class GoalDepositInput {
  GoalDepositInput({required this.amount, required this.note});

  final int amount;
  final String note;
}

/// "Deposit / withdraw" as a bottom sheet, matching the other form
/// sheets: large amount entry, optional note, inline validation.
class GoalDepositSheet extends ConsumerStatefulWidget {
  const GoalDepositSheet({
    super.key,
    required this.goal,
    required this.isDeposit,
  });

  final Goal goal;
  final bool isDeposit;

  @override
  ConsumerState<GoalDepositSheet> createState() => _GoalDepositSheetState();
}

class _GoalDepositSheetState extends ConsumerState<GoalDepositSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  String? _amountError;
  final _amountShake = ShakeController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FormSheet(
      title: widget.isDeposit
          ? l10n.goalDepositTo(widget.goal.name)
          : l10n.goalWithdrawFrom(widget.goal.name),
      actionLabel: widget.isDeposit ? l10n.goalDeposit : l10n.goalWithdraw,
      onAction: _save,
      busy: _saving,
      children: [
        Shaker(
          controller: _amountShake,
          child: FormAmountEntry(controller: _amountCtrl, autofocus: true),
        ),
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
        FormSectionLabel(l10n.commonNoteOptional),
        const SizedBox(height: 8),
        TextField(
          controller: _noteCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: l10n.commonNoteHint,
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final amount = parseAmountInput(_amountCtrl.text);
    if (amount <= 0) {
      setState(() => _amountError = l10n.commonEnterAmount);
      _amountShake.shake();
      return;
    }
    setState(() => _saving = true);
    if (mounted) {
      Navigator.pop(
        context,
        GoalDepositInput(amount: amount, note: _noteCtrl.text.trim()),
      );
    }
  }
}
