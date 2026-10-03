import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'pick_icon_screen.dart';

/// Full-screen add/edit category form: name, color + icon pickers,
/// and (for top-level categories) subcategory management.
class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({
    super.key,
    required this.kind,
    this.existing,
    this.parentId,
  });

  /// 'income' | 'expense' — the tab this category belongs to.
  final String kind;
  final Category? existing;
  final int? parentId;

  @override
  ConsumerState<CategoryFormScreen> createState() =>
      _CategoryFormScreenState();
}

class _CategoryFormScreenState
    extends ConsumerState<CategoryFormScreen> {
  late final TextEditingController _nameCtrl;
  late String _iconKey;
  late String _colorHex;

  bool get _isSub => widget.parentId != null;
  bool get _isEdit => widget.existing != null;

  String get _title {
    if (_isEdit && _isSub) return 'Edit Subcategory';
    if (_isEdit) return 'Edit Category';
    if (_isSub) return 'New Subcategory';
    return '${widget.kind == 'income' ? 'Income' : 'Expense'} Category';
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.existing?.name ?? '');
    _iconKey = widget.existing?.iconKey ?? 'other';
    _colorHex = widget.existing?.colorHex ?? availableColors.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          TextButton(
            onPressed: () => _save(db),
            child: const Text('SAVE'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Name'),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: "Category's name",
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Color'),
                      _colorButton(),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Icon'),
                      _iconButton(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Tips: Pick different colour for each category to easily identify the category by the colour.',
              style:
                  TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (_isEdit && !_isSub) ...[
              const SizedBox(height: 28),
              _label('Subcategories'),
              const SizedBox(height: 8),
              _subcategorySection(db),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      );

  Widget _colorButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _pickColor,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgRaised,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: colorFromHex(_colorHex),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _iconButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => PickIconScreen(initialKey: _iconKey),
          ),
        );
        if (picked != null) setState(() => _iconKey = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgRaised,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(iconForKey(_iconKey), size: 32),
      ),
    );
  }

  Future<void> _pickColor() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pick a colour',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final hex in availableColors)
                  GestureDetector(
                    onTap: () => Navigator.pop(context, hex),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorFromHex(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _colorHex == hex
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: _colorHex == hex
                          ? const Icon(Icons.check,
                              size: 22, color: Colors.black)
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _colorHex = picked);
  }

  Widget _subcategorySection(AppDatabase db) {
    final parentId = widget.existing!.id;
    return StreamBuilder<List<Category>>(
      stream: db.watchSubcategories(parentId),
      builder: (context, snap) {
        final subs = snap.data ?? const <Category>[];
        return Column(
          children: [
            for (final s in subs)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorFromHex(s.colorHex)
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconForKey(s.iconKey),
                      color: colorFromHex(s.colorHex), size: 20),
                ),
                title: Text(s.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () =>
                          Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CategoryFormScreen(
                            kind: widget.kind,
                            existing: s,
                            parentId: parentId,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: AppColors.expense),
                      onPressed: () => _confirmDeleteSub(db, s),
                    ),
                  ],
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add),
              title: const Text('Add subcategory'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CategoryFormScreen(
                    kind: widget.kind,
                    parentId: parentId,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteSub(AppDatabase db, Category s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${s.name}"?'),
        content:
            const Text('Transactions using it keep their history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await db.deleteCategory(s.id);
  }

  Future<void> _save(AppDatabase db) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }
    if (_isEdit) {
      await db.updateCategory(
        id: widget.existing!.id,
        name: name,
        iconKey: _iconKey,
        colorHex: _colorHex,
      );
    } else {
      await db.addCategory(CategoriesCompanion.insert(
        name: name,
        iconKey: Value(_iconKey),
        colorHex: Value(_colorHex),
        kind: widget.kind,
        parentId: Value(widget.parentId),
      ));
    }
    if (mounted) Navigator.pop(context, true);
  }
}
