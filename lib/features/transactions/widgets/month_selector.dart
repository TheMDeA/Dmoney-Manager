import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_accents.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptics.dart';

/// Opens the bottom-sheet month/year picker; returns the picked month or null.
Future<DateTime?> showMonthYearPicker(
    BuildContext context, DateTime initial) {
  return showModalBottomSheet<DateTime>(
    context: context,
    builder: (_) => MonthPicker(initial: initial),
  );
}

/// "< Oct 2026 >" — chevrons shift the month, tapping the label opens the
/// month/year picker. Shared by the transaction history and wallet screens.
class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.month,
    required this.onShift,
    required this.onPick,
  });

  final DateTime month;
  final ValueChanged<int> onShift;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {
            Haptics.select();
            onShift(-1);
          },
          icon: const Icon(Icons.chevron_left),
        ),
        GestureDetector(
          onTap: () {
            Haptics.select();
            onPick();
          },
          child: Text(
            DateFormat('MMM yyyy').format(month),
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        IconButton(
          onPressed: () {
            Haptics.select();
            onShift(1);
          },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// Bottom-sheet month/year picker. Future months are disabled.
class MonthPicker extends StatefulWidget {
  const MonthPicker({super.key, required this.initial});

  final DateTime initial;

  @override
  State<MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<MonthPicker> {
  static const _names = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    Haptics.select();
                    setState(() => _year--);
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '$_year',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18),
                ),
                IconButton(
                  onPressed: _year < now.year
                      ? () {
                          Haptics.select();
                          setState(() => _year++);
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () {
                Haptics.select();
                Navigator.of(context).pop(DateTime(now.year, now.month));
              },
              icon: const Icon(Icons.today_outlined, size: 16),
              label: const Text('Current month'),
              style: TextButton.styleFrom(
                foregroundColor: context.accent,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(height: 4),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.8,
              ),
              itemCount: 12,
              itemBuilder: (_, m) {
                final selected = _year == widget.initial.year &&
                    m + 1 == widget.initial.month;
                final future =
                    _year > now.year || (_year == now.year && m + 1 > now.month);
                return Material(
                  color: selected
                      ? context.accent
                      : context.raised,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: future
                        ? null
                        : () {
                            Haptics.select();
                            Navigator.of(context)
                                .pop(DateTime(_year, m + 1));
                          },
                    child: Center(
                      child: Text(
                        _names[m],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : future
                                  ? context.textMuted.withValues(alpha: 0.4)
                                  : context.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
