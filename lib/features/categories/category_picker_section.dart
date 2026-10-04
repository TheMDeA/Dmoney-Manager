import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/app_page_route.dart';
import '../../core/widgets/form_sheet.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'select_category_screen.dart';

/// Compact category section for the form sheets: a short radio list of
/// top-level categories plus a "View all categories" tile that opens the
/// full-screen [SelectCategoryScreen]. Selecting there also reports the
/// category's kind, so sheets like the transaction form can follow it.
class CategoryPickerSection extends ConsumerWidget {
  const CategoryPickerSection({
    super.key,
    required this.kind,
    required this.selectedId,
    required this.onSelected,
    this.label = 'Category',
    this.compactCount = 5,
    this.lockKind = false,
  });

  final String kind;
  final int? selectedId;
  final ValueChanged<Category> onSelected;
  final String label;
  final int compactCount;
  final bool lockKind;

  Future<void> _openFullList(BuildContext context) async {
    final picked = await Navigator.of(context).push<Category>(
      AppPageRoute(
        builder: (_) => SelectCategoryScreen(
          initialKind: kind,
          selectedId: selectedId,
          lockKind: lockKind,
        ),
      ),
    );
    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormSectionLabel(label),
        StreamBuilder<List<Category>>(
          stream: db.watchCategories(kind: kind, topLevelOnly: true),
          builder: (context, snap) {
            final cats = snap.data ?? const <Category>[];
            final shown = cats.take(compactCount).toList();
            return Column(
              children: [
                for (final c in shown) _row(context, c),
                InkWell(
                  onTap: () {
                    Haptics.light();
                    _openFullList(context);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: context.accent.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.grid_view_rounded,
                              color: context.accent, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'View all categories',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: context.accent,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            color: context.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _row(BuildContext context, Category c) {
    final selected = c.id == selectedId;
    final color = colorFromHex(c.colorHex);
    return InkWell(
      onTap: () {
        Haptics.light();
        onSelected(c);
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(iconForKey(c.iconKey),
                  color: onAccent(color), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(c.name, style: const TextStyle(fontSize: 15)),
            ),
            RadioCircle(selected: selected),
          ],
        ),
      ),
    );
  }
}
