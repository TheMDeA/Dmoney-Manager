import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// Flexible categories: create, edit, delete, with subcategories.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _editing = !_editing),
            child: Text(_editing ? 'Done' : 'Edit'),
          ),
        ],
      ),
      body: StreamBuilder<List<Category>>(
        stream: db.watchCategories(topLevelOnly: true),
        builder: (context, snap) {
          final cats = snap.data ?? const <Category>[];
          final expense = cats.where((c) => c.kind == 'expense').toList();
          final income = cats.where((c) => c.kind == 'income').toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _sectionLabel(context, 'Expense'),
              for (final c in expense) _categoryTile(context, ref, c),
              _addButton(context, ref, 'expense'),
              const SizedBox(height: 16),
              _sectionLabel(context, 'Income'),
              for (final c in income) _categoryTile(context, ref, c),
              _addButton(context, ref, 'income'),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: AppColors.textMuted)),
    );
  }

  Widget _categoryTile(BuildContext context, WidgetRef ref, Category c) {
    final color = colorFromHex(c.colorHex);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(iconForKey(c.iconKey), color: color, size: 20),
        ),
        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: _editing
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.expense),
                onPressed: () => _confirmDelete(context, ref, c),
              )
            : const Icon(Icons.expand_more),
        children: [
          _subcategoryList(context, ref, c),
        ],
      ),
    );
  }

  Widget _subcategoryList(BuildContext context, WidgetRef ref, Category parent) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<Category>>(
      stream: db.watchSubcategories(parent.id),
      builder: (context, snap) {
        final subs = snap.data ?? const <Category>[];
        return Column(
          children: [
            for (final s in subs)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 72, right: 8),
                title: Text(s.name),
                trailing: _editing
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.expense, size: 20),
                        onPressed: () => _confirmDelete(context, ref, s),
                      )
                    : null,
              ),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 72),
              leading: const Icon(Icons.add, size: 18),
              title: const Text('Add subcategory'),
              onTap: () => _categoryDialog(context, ref, parent.kind, parentId: parent.id),
            ),
          ],
        );
      },
    );
  }

  Widget _addButton(BuildContext context, WidgetRef ref, String kind) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: OutlinedButton.icon(
        onPressed: () => _categoryDialog(context, ref, kind),
        icon: const Icon(Icons.add),
        label: const Text('Add category'),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${c.name}"?'),
        content: const Text('Transactions using it keep their history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(databaseProvider).deleteCategory(c.id);
    }
  }

  Future<void> _categoryDialog(BuildContext context, WidgetRef ref, String kind,
      {int? parentId}) async {
    final nameCtrl = TextEditingController();
    String iconKey = 'other';
    String colorHex = availableColors.first;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(parentId == null ? 'New category' : 'New subcategory'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 16),
                const Text('Icon'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: [
                    for (final k in availableIconKeys)
                      IconButton(
                        onPressed: () => setState(() => iconKey = k),
                        icon: Icon(iconForKey(k),
                            color: iconKey == k ? AppColors.lime : null),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Color'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final hex in availableColors)
                      InkWell(
                        onTap: () => setState(() => colorHex = hex),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colorFromHex(hex),
                            shape: BoxShape.circle,
                            border: colorHex == hex
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved == true && nameCtrl.text.trim().isNotEmpty) {
      await ref.read(databaseProvider).addCategory(CategoriesCompanion.insert(
            name: nameCtrl.text.trim(),
            iconKey: Value(iconKey),
            colorHex: Value(colorHex),
            kind: kind,
            parentId: Value(parentId),
          ));
    }
  }
}
