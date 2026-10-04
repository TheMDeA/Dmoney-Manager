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

/// Compact category section for the form sheets: a two-column quick-pick
/// grid with the first few top-level categories plus an "All" shortcut
/// that opens the full-screen [SelectCategoryScreen]. Selecting there also
/// reports the category's kind, so sheets like the transaction form can
/// follow it.
class CategoryPickerSection extends ConsumerWidget {
  const CategoryPickerSection({
    super.key,
    required this.kind,
    required this.selectedId,
    required this.onSelected,
    this.label = 'Category',
    this.quickPickCount = 3,
    this.lockKind = false,
  });

  final String kind;
  final int? selectedId;
  final ValueChanged<Category> onSelected;
  final String label;

  /// How many categories appear as quick-pick tiles. The grid always has
  /// two columns; the last cell is the "All" shortcut.
  final int quickPickCount;
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
            final picks = cats.take(quickPickCount).toList();
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3.4,
              children: [
                for (final c in picks) _categoryTile(context, c),
                _allTile(context),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _categoryTile(BuildContext context, Category c) {
    final selected = c.id == selectedId;
    final color = colorFromHex(c.colorHex);
    final accent = context.accent;
    return InkWell(
      onTap: () {
        Haptics.light();
        onSelected(c);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.14)
              : context.raised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : context.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(iconForKey(c.iconKey),
                  color: onAccent(color), size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : null,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle,
                  size: 18, color: accent),
          ],
        ),
      ),
    );
  }

  Widget _allTile(BuildContext context) {
    final accent = context.accent;
    return InkWell(
      onTap: () {
        Haptics.light();
        _openFullList(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.grid_view_rounded,
                  color: accent, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18, color: accent),
          ],
        ),
      ),
    );
  }
}
