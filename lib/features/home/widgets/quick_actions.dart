import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Thumb-zone quick actions row. All actions are wired by the parent.
class QuickActions extends StatelessWidget {
  const QuickActions({
    super.key,
    required this.onTransfer,
    required this.onTopUp,
    required this.onScan,
    required this.onMore,
  });

  final VoidCallback onTransfer;
  final VoidCallback onTopUp;
  final VoidCallback onScan;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.swap_horiz, 'Transfer', onTransfer),
      (Icons.add_card, 'Top up', onTopUp),
      (Icons.receipt_long_outlined, 'Scan', onScan),
      (Icons.more_horiz, 'More', onMore),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (final a in actions) _Action(icon: a.$1, label: a.$2, onTap: a.$3),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.lime.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppColors.lime, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
