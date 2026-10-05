import 'package:flutter/material.dart';
import '../../core/widgets/app_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../../core/utils/haptics.dart';
import 'category_form_screen.dart';

/// Manage Category: INCOME / EXPENSE tabs, drag-to-reorder rows with
/// subcategory counts, edit + delete actions, add via the + button.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          final tab = DefaultTabController.of(context);
          return Scaffold(
            appBar: AppBar(
              title: const Text('Manage Category'),
              actions: [
                IconButton(
                  tooltip: 'Add category',
                  icon: Icon(Icons.add),
                  onPressed: () {
                    final kind = tab.index == 0 ? 'income' : 'expense';
                    Navigator.of(context).push(
                      AppPageRoute(
                        builder: (_) =>
                            CategoryFormScreen(kind: kind),
                      ),
                    );
                  },
                ),
              ],
              bottom: TabBar(
                tabs: [
                  Tab(text: 'INCOME'),
                  Tab(text: 'EXPENSE'),
                ],
              ),
            ),
            body: StreamBuilder<List<Category>>(
              stream: db.watchCategories(),
              builder: (context, snap) {
                final all = snap.data ?? const <Category>[];
                final subCounts = <int, int>{};
                for (final c in all) {
                  if (c.parentId != null) {
                    subCounts[c.parentId!] =
                        (subCounts[c.parentId!] ?? 0) + 1;
                  }
                }
                return TabBarView(
                  children: [
                    _categoryList(
                      context,
                      db,
                      all
                          .where((c) =>
                              c.kind == 'income' && c.parentId == null)
                          .toList(),
                      subCounts,
                    ),
                    _categoryList(
                      context,
                      db,
                      all
                          .where((c) =>
                              c.kind == 'expense' && c.parentId == null)
                          .toList(),
                      subCounts,
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _categoryList(
    BuildContext context,
    AppDatabase db,
    List<Category> cats,
    Map<int, int> subCounts,
  ) {
    if (cats.isEmpty) {
      return Center(
        child: Text('No categories yet — tap + to add one',
            style: TextStyle(color: context.textMuted)),
      );
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
      itemCount: cats.length,
      onReorderItem: (oldIndex, newIndex) async {
        final reordered = cats.toList();
        final moved = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, moved);
        await db.reorderCategories(
            [for (final c in reordered) c.id]);
      },
      itemBuilder: (context, i) {
        final c = cats[i];
        final color = colorFromHex(c.colorHex);
        final n = subCounts[c.id] ?? 0;
        return ListTile(
          key: ValueKey(c.id),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReorderableDragStartListener(
                index: i,
                child: Icon(Icons.drag_indicator,
                    color: context.textMuted),
              ),
              SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(iconForKey(c.iconKey),
                    color: onAccent(color), size: 22),
              ),
            ],
          ),
          title: Text(c.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '$n subcategory',
            style: TextStyle(
                fontSize: 12, color: context.textMuted),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined, size: 22),
                onPressed: () => Navigator.of(context).push(
                  AppPageRoute(
                    builder: (_) => CategoryFormScreen(
                      kind: c.kind,
                      existing: c,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: Icon(Icons.delete_outline,
                    size: 22, color: context.textMuted),
                onPressed: () {
                  Haptics.select();
                  _confirmDelete(context, db, c);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, AppDatabase db, Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${c.name}"?'),
        content: const Text(
            'Its subcategories are removed too. Transactions using it keep their history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                Haptics.medium();
                Navigator.pop(context, true);
              },
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await db.deleteCategory(c.id);
  }
}
