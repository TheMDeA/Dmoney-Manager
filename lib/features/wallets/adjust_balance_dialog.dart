import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/amount_field.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// "Adjust balance" dialog: reconcile a wallet's balance against reality.
///
/// Enter the true balance and pick a mode:
/// - [Adjust by transaction] records an income/expense transaction for the
///   difference (dated now, under the hidden "Adjustment" category).
/// - [Change initial amount] shifts the wallet's initial amount instead,
///   leaving the transaction history untouched.
class AdjustBalanceDialog extends ConsumerStatefulWidget {
  const AdjustBalanceDialog({super.key, required this.wallet});

  final Wallet wallet;

  static Future<void> show(BuildContext context, Wallet wallet) {
    return showDialog(
      context: context,
      builder: (_) => AdjustBalanceDialog(wallet: wallet),
    );
  }

  @override
  ConsumerState<AdjustBalanceDialog> createState() =>
      _AdjustBalanceDialogState();
}

enum _AdjustMode { byTransaction, initialAmount }

class _AdjustBalanceDialogState extends ConsumerState<AdjustBalanceDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: formatAmountInput(widget.wallet.balance),
  );
  var _mode = _AdjustMode.byTransaction;
  var _saving = false;

  @override
  void dispose() {
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
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
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
    return AlertDialog(
      title: const Text('Adjust balance'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Current balance',
                    style:
                        TextStyle(color: context.textMuted, fontSize: 13)),
                Text(
                  formatMoney(widget.wallet.balance),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('New balance',
                style: TextStyle(color: context.textMuted, fontSize: 13)),
            const SizedBox(height: 4),
            AmountField(controller: _ctrl, autofocus: true),
            const SizedBox(height: 8),
            // Live difference preview + DONE state follow the input.
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) {
                final diff = _diff;
                final color = diff == 0
                    ? context.textMuted
                    : (diff > 0 ? AppColors.income : AppColors.expense);
                return Text(
                  diff == 0
                      ? 'No change'
                      : 'Difference: ${formatSignedMoney(diff.abs(), isIncome: diff > 0)}',
                  style:
                      TextStyle(color: color, fontWeight: FontWeight.w600),
                );
              },
            ),
            const SizedBox(height: 4),
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) => TextButton(
            onPressed: _diff == 0 || _saving ? null : _save,
            child: const Text('DONE'),
          ),
        ),
      ],
    );
  }
}
