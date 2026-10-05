import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/form_sheet.dart';
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
  // Own messenger: the bottom-sheet route has none, so snackbars would
  // otherwise render behind the modal barrier.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  void _snack(String message) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  int? _fromId;
  int? _toId;
  int _swaps = 0; // drives the swap button's rotation animation
  bool _saving = false;
  bool _success = false;

  void _swapWallets() {
    if (_fromId == null || _toId == null) return;
    Haptics.select();
    setState(() {
      final t = _fromId;
      _fromId = _toId;
      _toId = t;
      _swaps++;
    });
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
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Stack(
        children: [
          FormSheet(
            title: 'Transfer',
          subtitle: 'Move money between two wallets.',
          actionLabel: 'Transfer',
          onAction: _save,
          busy: _saving,
          children: [
            const FormSectionLabel('Amount'),
            FormAmountEntry(controller: _amountCtrl),
            const SizedBox(height: 16),
            const FormSectionLabel('Wallets'),
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
                        // The fields cross-fade with a directional slide when
                        // the wallets swap (From's new value drops in from
                        // above, To's rises from below), instead of the text
                        // just blinking to the new value.
                        AnimatedSwitcher(
                          duration: AppMotion.normal,
                          switchInCurve: AppMotion.enter,
                          switchOutCurve: AppMotion.exit,
                          transitionBuilder: (child, animation) =>
                              SlideTransition(
                            position: animation.drive(
                              Tween(
                                begin: const Offset(0, -0.35),
                                end: Offset.zero,
                              ).chain(CurveTween(curve: AppMotion.enter)),
                            ),
                            child: FadeTransition(
                                opacity: animation, child: child),
                          ),
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('from-$_fromId'),
                            initialValue: _fromId,
                            decoration:
                                const InputDecoration(labelText: 'From'),
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
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Material(
                            shape: const CircleBorder(),
                            color: context.raised,
                            // A full 360° spin per press: the half-turn was
                            // invisible because Icons.swap_vert is vertically
                            // symmetric.
                            child: AnimatedRotation(
                              turns: _swaps.toDouble(),
                              duration: AppMotion.normal,
                              curve: AppMotion.enter,
                              child: IconButton(
                                tooltip: 'Swap wallets',
                                icon: const Icon(Icons.swap_vert),
                                color: context.accent,
                                onPressed: (_fromId == null || _toId == null)
                                    ? null
                                    : _swapWallets,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedSwitcher(
                          duration: AppMotion.normal,
                          switchInCurve: AppMotion.enter,
                          switchOutCurve: AppMotion.exit,
                          transitionBuilder: (child, animation) =>
                              SlideTransition(
                            position: animation.drive(
                              Tween(
                                begin: const Offset(0, 0.35),
                                end: Offset.zero,
                              ).chain(CurveTween(curve: AppMotion.enter)),
                            ),
                            child: FadeTransition(
                                opacity: animation, child: child),
                          ),
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('to-$_toId'),
                            initialValue: _toId,
                            decoration:
                                const InputDecoration(labelText: 'To'),
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
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
        if (_success) const _TransferSuccessOverlay(),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final amount = parseAmountInput(_amountCtrl.text);
    if (amount <= 0 || _fromId == null || _toId == null || _fromId == _toId) {
      _snack('Enter an amount and two different wallets');
      return;
    }
    Haptics.medium();
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
          duration: AppMotion.normal,
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: context.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, color: onAccent(context.accent), size: 44),
          ),
        ),
      ),
    );
  }
}
