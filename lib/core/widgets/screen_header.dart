import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_accents.dart';
import '../utils/haptics.dart';
import '../../state/providers.dart';

/// Shared screen header for the main tabs: a bold title with a lime
/// full stop, plus an optional trailing action (pill button, icon
/// buttons, …). Replaces the plain AppBar titles.
///
/// On becoming the active tab the title plays a letter-cascade entrance:
/// letters fade + rise in with a ~30ms stagger, the lime dot pops with a
/// spring, and the trailing action follows.
class ScreenHeader extends ConsumerStatefulWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    required this.tabIndex,
    this.action,
  });

  final String title;
  final int tabIndex;
  final Widget? action;

  @override
  ConsumerState<ScreenHeader> createState() => _ScreenHeaderState();
}

class _ScreenHeaderState extends ConsumerState<ScreenHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Stagger between letters, as a fraction of the controller duration.
  static const _stagger = 0.055;

  /// Per-letter animation length, as a fraction of the controller duration.
  static const _letterLen = 0.32;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (ref.read(tabIndexProvider) == widget.tabIndex) {
      _play();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _play() {
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  /// Eased 0→1 progress for the i-th item (letters first, then the dot).
  double _itemT(int i, {bool spring = false}) {
    final start = i * _stagger;
    final t = ((_controller.value - start) / _letterLen).clamp(0.0, 1.0);
    return (spring ? Curves.easeOutBack : Curves.easeOut).transform(t);
  }

  @override
  Widget build(BuildContext context) {
    // Replay the entrance every time this tab becomes active.
    ref.listen<int>(tabIndexProvider, (prev, next) {
      if (next == widget.tabIndex) _play();
    });

    final titleStyle = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: Theme.of(context).colorScheme.onSurface,
    );
    final n = widget.title.length;

    return SafeArea(
      top: true,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              label: widget.title,
              child: ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < n; i++)
                          _letter(widget.title[i], _itemT(i), titleStyle),
                        _dot(_itemT(n, spring: true), titleStyle),
                      ],
                    );
                  },
                ),
              ),
            ),
            _entranceAction(n),
          ],
        ),
      ),
    );
  }

  Widget _letter(String ch, double t, TextStyle style) {
    final c = t.clamp(0.0, 1.0);
    return Opacity(
      opacity: c,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - c)),
        child: Text(ch, style: style),
      ),
    );
  }

  Widget _dot(double t, TextStyle style) {
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: (0.3 + 0.7 * t).clamp(0.0, 1.2),
        child: Text('.', style: style.copyWith(color: context.accent)),
      ),
    );
  }

  Widget _entranceAction(int letters) {
    final action = widget.action;
    if (action == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _itemT(letters + 1).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: action,
          ),
        );
      },
    );
  }
}

/// Tinted pill button used as a header action (e.g. "Today").
class HeaderPillButton extends StatelessWidget {
  const HeaderPillButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        Haptics.select();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: context.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: context.accent,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
