import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// Bottom sheet for moving money between two wallets.
class TransferSheet extends ConsumerStatefulWidget {
  const TransferSheet({super.key});

  @override
  ConsumerState<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<TransferSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  int? _fromId;
  int? _toId;
  bool _saving = false;
  bool _success = false;

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
                Text(
                  'Transfer',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  style: AppTextStyles.displayBalance.copyWith(fontSize: 36),
                  decoration: InputDecoration(
                    prefixText: currencyFieldPrefix,
                    hintText: '0',
                    border: InputBorder.none,
                    filled: false,
                  ),
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<Wallet>>(
                  stream: db.watchWallets(),
                  builder: (context, snap) {
                    final wallets = snap.data ?? const <Wallet>[];
                    _fromId ??= wallets.isNotEmpty ? wallets.first.id : null;
                    _toId ??= wallets.length > 1 ? wallets[1].id : null;
                    if (_toId == _fromId && wallets.length > 1) {
                      _toId = wallets.firstWhere((w) => w.id != _fromId).id;
                    }
                    return Column(
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: _fromId,
                          decoration: const InputDecoration(labelText: 'From'),
                          items: [
                            for (final w in wallets)
                              DropdownMenuItem(
                                value: w.id,
                                child: Text(
                                  '${w.name} (${formatMoney(w.balance)})',
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() {
                            _fromId = v;
                            if (_toId == _fromId && wallets.length > 1) {
                              _toId = wallets
                                  .firstWhere((w) => w.id != _fromId)
                                  .id;
                            }
                          }),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _toId,
                          decoration: const InputDecoration(labelText: 'To'),
                          items: [
                            for (final w in wallets.where(
                              (w) => w.id != _fromId,
                            ))
                              DropdownMenuItem(
                                value: w.id,
                                child: Text(
                                  '${w.name} (${formatMoney(w.balance)})',
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _toId = v),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
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
                      : const Text(
                          'Transfer',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
          ),
        ),
        if (_success) const _TransferSuccessOverlay(),
      ],
    );
  }

  Future<void> _save() async {
    final amount = parseAmountInput(_amountCtrl.text);
    if (amount <= 0 || _fromId == null || _toId == null || _fromId == _toId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an amount and two different wallets'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(databaseProvider)
          .addTransfer(
            fromWalletId: _fromId!,
            toWalletId: _toId!,
            amount: amount,
            note: _noteCtrl.text.trim(),
          );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _success = true);
    await Future.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Transferred ${formatMoney(amount)}')));
  }
}

/// Brief success state: lime checkmark with a springy scale-in.
class _TransferSuccessOverlay extends StatelessWidget {
  const _TransferSuccessOverlay();

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
