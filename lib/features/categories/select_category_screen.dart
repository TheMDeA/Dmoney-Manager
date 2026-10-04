import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/app_page_route.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'categories_screen.dart';

/// Full-screen category picker modeled on the classic "Select Category"
/// screen: INCOME/EXPENSE tabs, search, a manage shortcut, and rows with
/// colored icons and radio selection. Returns the picked [Category].
class SelectCategoryScreen extends ConsumerStatefulWidget {
  const SelectCategoryScreen({
    super.key,
    this.initialKind = 'expense',
    this.selectedId,
    this.lockKind = false,
  });

  final String initialKind;
  final int? selectedId;
  final bool lockKind;

  @override
  ConsumerState<SelectCategoryScreen> createState() =>
      _SelectCategoryScreenState();
}

class _SelectCategoryScreenState extends ConsumerState<SelectCategoryScreen> {
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kinds = widget.lockKind ? [widget.initialKind] : const ['income', 'expense'];
    final body = kinds.length == 1
        ? _categoryList(context, kinds.first)
        : DefaultTabController(
            length: 2,
            initialIndex: widget.initialKind == 'income' ? 0 : 1,
            child: Column(
              children: [
                TabBar(
                  tabs: const [Tab(text: 'INCOME'), Tab(text: 'EXPENSE')],
                  labelColor: Theme.of(context).colorScheme.onSurface,
                  unselectedLabelColor: context.textMuted,
                  indicatorColor: context.textPrimary,
                  indicatorSize: TabBarIndicatorSize.tab,
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _categoryList(context, 'income'),
                      _categoryList(context, 'expense'),
                    ],
                  ),
                ),
              ],
            ),
          );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search categories',
                  border: InputBorder.none,
                ),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              )
            : const Text('Select Category'),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _searchCtrl.clear();
                _query = '';
              }
            }),
          ),
          IconButton(
            tooltip: 'Manage categories',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              AppPageRoute(builder: (_) => const CategoriesScreen()),
            ),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _categoryList(BuildContext context, String kind) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<Category>>(
      stream: db.watchCategories(kind: kind, topLevelOnly: true),
      builder: (context, snap) {
        var cats = snap.data ?? const <Category>[];
        if (_query.isNotEmpty) {
          cats = cats
              .where((c) => c.name.toLowerCase().contains(_query))
              .toList();
        }
        if (cats.isEmpty) {
          return Center(
            child: Text('No categories found.',
                style: TextStyle(color: context.textMuted)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: cats.length,
          itemBuilder: (context, i) =>
              _categoryRow(context, cats[i]),
        );
      },
    );
  }

  Widget _categoryRow(BuildContext context, Category c) {
    final selected = c.id == widget.selectedId;
    final color = colorFromHex(c.colorHex);
    return InkWell(
      onTap: () {
        Haptics.light();
        Navigator.pop(context, c);
      },
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
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
            const SizedBox(width: 16),
            Expanded(
              child: Text(c.name, style: const TextStyle(fontSize: 16)),
            ),
            RadioCircle(selected: selected),
          ],
        ),
      ),
    );
  }
}

/// The trailing radio indicator: accent-filled with a check when selected,
/// a muted outline otherwise.
class RadioCircle extends StatelessWidget {
  const RadioCircle({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? accent : Colors.transparent,
        border: Border.all(
          color: selected
              ? accent
              : context.textMuted.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: 14, color: onAccent(accent))
          : null,
    );
  }
}
