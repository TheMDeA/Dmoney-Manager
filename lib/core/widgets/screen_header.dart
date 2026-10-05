import 'package:flutter/material.dart';

import '../theme/app_accents.dart';
import '../utils/haptics.dart';

/// Shared screen header for the main tabs: a bold title with a lime
/// full stop, plus an optional trailing action (pill button, icon
/// buttons, …). Replaces the plain AppBar titles.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text.rich(
              TextSpan(
                text: title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                children: [
                  TextSpan(
                    text: '.',
                    style: TextStyle(color: context.accent),
                  ),
                ],
              ),
            ),
            action ?? const SizedBox.shrink(),
          ],
        ),
      ),
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
