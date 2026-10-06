import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/form_sheet.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// "Adjust balance" sheet: reconcile a wallet's balance against reality.
///
/// Enter the true balance and pick a mode:
/// - [Adjust by transaction] records an income/expense transaction for the
///   difference (dated now, under the hidden "Adjustment" category).
/// - [Change initial amount] shifts the wallet's initial amount instead,
///   leaving the transaction history untouched.
class AdjustBalanceSheet extends ConsumerStatefulWidget {
  const AdjustBalanceSheet({super.key, required this.wallet});

  final Wallet wallet;

  static Future<void> show(BuildContext context, Wallet wallet) {
    return showFormSheet<void>(
      context,
      (_) => AdjustBalanceSheet(wallet: wallet),
    );
  }

  @override
  ConsumerState<AdjustBalanceSheet> createState() =>
      _AdjustBalanceSheetState();
}

enum _AdjustMode { byTransaction, initialAmount }

class _AdjustBalanceSheetState extends ConsumerState<AdjustBalanceSheet> {
  late final TextEditingController _ctrl = TextEditingController(
    text: formatAmountInput(widget.wallet.balance),
  );
  var _mode = _AdjustMode.byTransaction;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }

  int get _newBalance => parseAmountInput(_ctrl.text);
  int get _diff => _newBalance - widget.wallet.balance;

  Future<void> _save() async {
    final diff = _diff;
    if (diff == 0 || _saving) return;
    Haptics.medium();
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    try {
      if (_mode == _AdjustMode.byTransaction) {
        await db.adjustBalanceByTransaction(widget.wallet.id, _newBalance);
      } else {
        await db.changeWalletInitialAmount(widget.wallet.id, _newBalance);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    Haptics.medium();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _mode == _AdjustMode.byTransaction
              ? 'Adjustment of ${formatSignedMoney(diff.abs(), isIncome: diff > 0)} recorded'
              : 'Initial amount updated',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diff = _diff;
    final diffColor = diff == 0
        ? context.textMuted
        : (diff > 0 ? AppColors.income : AppColors.expense);
    return FormSheet(
      title: 'Adjust balance',
      actionLabel: 'Done',
      onAction: _save,
      busy: _saving,
      actionEnabled: diff != 0 && !_saving,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Current balance',
                style: TextStyle(color: context.textMuted, fontSize: 13)),
            Text(
              formatMoney(widget.wallet.balance),
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const FormSectionLabel('New balance'),
        const SizedBox(height: 8),
        FormAmountEntry(controller: _ctrl, autofocus: true),
        const SizedBox(height: 8),
        Text(
          diff == 0
              ? 'No change'
              : 'Difference: ${formatSignedMoney(diff.abs(), isIncome: diff > 0)}',
          style: TextStyle(color: diffColor, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        RadioGroup<_AdjustMode>(
          groupValue: _mode,
          onChanged: (v) {
            Haptics.select();
            setState(() => _mode = v!);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<_AdjustMode>(
                value: _AdjustMode.byTransaction,
                title: const Text('Adjust by transaction'),
                subtitle: const Text(
                    'Creates an income/expense record for the difference.'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              RadioListTile<_AdjustMode>(
                value: _AdjustMode.initialAmount,
                title: const Text('Change initial amount'),
                subtitle: const Text(
                    'Shifts the starting amount; history untouched.'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
