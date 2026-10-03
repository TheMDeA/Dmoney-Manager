import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Phone-style keypad used on the initial-amount step.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
  });

  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      children: [
        for (var i = 1; i <= 9; i++) _key(context, '$i', () => onDigit('$i')),
        const SizedBox.shrink(),
        _key(context, '0', () => onDigit('0')),
        _key(
          context,
          '',
          onBackspace,
          icon: Icons.backspace_outlined,
        ),
      ],
    );
  }

  Widget _key(BuildContext context, String label, VoidCallback onTap,
      {IconData? icon}) {
    if (label.isEmpty && icon == null) return const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: icon != null
            ? Icon(icon, color: AppColors.textMuted, size: 26)
            : Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w400,
                ),
              ),
      ),
    );
  }
}
