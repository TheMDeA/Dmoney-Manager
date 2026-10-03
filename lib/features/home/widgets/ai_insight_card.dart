import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Collapsible AI insight zone — kept visually quiet so it never
/// competes with the balance or transactions for priority.
class AiInsightCard extends StatefulWidget {
  const AiInsightCard({super.key});

  @override
  State<AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends State<AiInsightCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined, size: 18, color: AppColors.violet),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Food spending is 20% higher than usual this week.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                const Text(
                  'Most of it came from dining out. Cooking twice more this week would bring you back under your Rp 2.000.000 Food budget.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
