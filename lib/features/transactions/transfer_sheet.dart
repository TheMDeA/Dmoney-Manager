import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_prefs.dart';
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
  // A Scaffold inside the sheet route registers with the root
  // ScaffoldMessenger, so snackbars render on the front layer, above
  // the sheet. (A bare nested ScaffoldMessenger has no Scaffold to
  // present through and silently swallows them.)

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  int? _fromId;
  int? _toId;
  int _swaps = 0; // drives the swap button's rotation animation
  bool _saving = false;
  bool _success = false;
  Offset? _successFrom;
  Offset? _successTo;
  final _stackKey = GlobalKey();
  final _fromKey = GlobalKey();
  final _toKey = GlobalKey();

  /// Center of the widget behind [key], in the sheet Stack's coordinates.
  /// Null when the layout isn't available (the overlay falls back).
  Offset? _centerOf(GlobalKey key) {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || box == null) return null;
    return stackBox.globalToLocal(
      box.localToGlobal(box.size.center(Offset.zero)),
    );
  }

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
    return Stack(
      key: _stackKey,
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
                      key: _fromKey,
                      duration: AppMotion.normal,
                      switchInCurve: AppMotion.enter,
                      switchOutCurve: AppMotion.exit,
                      transitionBuilder: (child, animation) => SlideTransition(
                        position: animation.drive(
                          Tween(
                            begin: const Offset(0, -0.35),
                            end: Offset.zero,
                          ).chain(CurveTween(curve: AppMotion.enter)),
                        ),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('from-$_fromId'),
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
                      key: _toKey,
                      duration: AppMotion.normal,
                      switchInCurve: AppMotion.enter,
                      switchOutCurve: AppMotion.exit,
                      transitionBuilder: (child, animation) => SlideTransition(
                        position: animation.drive(
                          Tween(
                            begin: const Offset(0, 0.35),
                            end: Offset.zero,
                          ).chain(CurveTween(curve: AppMotion.enter)),
                        ),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('to-$_toId'),
                        initialValue: _toId,
                        decoration: const InputDecoration(labelText: 'To'),
                        items: [
                          for (final w in wallets.where((w) => w.id != _fromId))
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
        if (_success)
          _TransferSuccessOverlay(from: _successFrom, to: _successTo),
      ],
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
    setState(() {
      _successFrom = _centerOf(_fromKey);
      _successTo = _centerOf(_toKey);
      _success = true;
    });
    await Future.delayed(const Duration(milliseconds: 1050));
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Transferred ${formatMoney(amount)}')),
    );
  }
}

/// Success state: a coin flies from the From wallet to the To wallet along
/// an arc, then a lime checkmark pops with a springy scale-in.
class _TransferSuccessOverlay extends StatefulWidget {
  const _TransferSuccessOverlay({required this.from, required this.to});

  /// Flight endpoints in the sheet Stack's coordinates. Null falls back
  /// to sensible defaults inside the overlay.
  final Offset? from;
  final Offset? to;

  @override
  State<_TransferSuccessOverlay> createState() =>
      _TransferSuccessOverlayState();
}

class _TransferSuccessOverlayState extends State<_TransferSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  )..forward();
  late final Animation<double> _flight = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.55, curve: Curves.easeInOut),
  );
  late final Animation<double> _coinFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.48, 0.62, curve: Curves.easeOut),
  );
  late final Animation<double> _checkPop = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.55, 1.0, curve: Curves.elasticOut),
  );

  @override
  void initState() {
    super.initState();
    Haptics.light();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Theme.of(
          context,
        ).scaffoldBackgroundColor.withValues(alpha: 0.85),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final from =
                widget.from ?? Offset(size.width / 2, size.height * 0.25);
            final to = widget.to ?? Offset(size.width / 2, size.height * 0.5);
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _flight.value;
                // Quadratic bezier arcing above the straight line.
                final cx = (from.dx + to.dx) / 2;
                final cy = (from.dy + to.dy) / 2 - 110;
                final x =
                    (1 - t) * (1 - t) * from.dx +
                    2 * (1 - t) * t * cx +
                    t * t * to.dx;
                final y =
                    (1 - t) * (1 - t) * from.dy +
                    2 * (1 - t) * t * cy +
                    t * t * to.dy;
                return Stack(
                  children: [
                    Positioned(
                      left: x - 20,
                      top: y - 20,
                      child: Opacity(
                        opacity: 1 - _coinFade.value,
                        child: Transform.rotate(
                          angle: t * 6.2832, // one full spin along the flight
                          child: _flightCoin(context),
                        ),
                      ),
                    ),
                    if (_checkPop.value > 0)
                      Center(
                        child: Transform.scale(
                          scale: 0.4 + 0.6 * _checkPop.value,
                          child: _checkBadge(context),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// The flying coin: accent disc with the selected currency's symbol,
  /// matching the pull-to-refresh coin.
  Widget _flightCoin(BuildContext context) {
    final accent = context.accent;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent,
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 3),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 12),
        ],
      ),
      child: Text(
        currencyByCode(AppPrefs.currencyCode).symbol.trim(),
        style: TextStyle(
          color: onAccent(accent),
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _checkBadge(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(color: context.accent, shape: BoxShape.circle),
      child: Icon(Icons.check, color: onAccent(context.accent), size: 44),
    );
  }
}
