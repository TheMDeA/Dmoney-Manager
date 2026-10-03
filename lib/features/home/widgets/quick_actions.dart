import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Thumb-zone quick actions row.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.swap_horiz, 'Transfer'),
      (Icons.add_card, 'Top up'),
      (Icons.receipt_long_outlined, 'Scan'),
      (Icons.more_horiz, 'More'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (final a in actions) _Action(icon: a.$1, label: a.$2),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
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
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ],
    );
  }
}
