import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_accents.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/form_sheet.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../categories/category_picker_section.dart';

/// Shows the standardized Add budget bottom sheet. Returns true when the
/// budget was saved.
Future<bool> showBudgetFormSheet(
  BuildContext context,
  WidgetRef ref, {
  required String monthKey,
}) async {
  final saved = await showFormSheet<bool>(
    context,
    (context) => _BudgetFormSheet(monthKey: monthKey),
  );
  return saved == true;
}

/// Shows the standardized Edit budget limit bottom sheet. Returns the new
/// limit, or null when cancelled.
Future<int?> showEditBudgetLimitSheet(
  BuildContext context,
  WidgetRef ref, {
  required int budgetId,
}) async {
  return showFormSheet<int>(
    context,
    (context) => _EditBudgetLimitSheet(budgetId: budgetId),
  );
}

class _BudgetFormSheet extends ConsumerStatefulWidget {
  const _BudgetFormSheet({required this.monthKey});

  final String monthKey;

  @override
  ConsumerState<_BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<_BudgetFormSheet> {
  final _limitCtrl = TextEditingController();
  int? _categoryId;
  bool _saving = false;
  // Own messenger: the bottom-sheet route has none, so snackbars would
  // otherwise render behind the modal barrier.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  void _snack(String message) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final limit = parseAmountInput(_limitCtrl.text);
    final catId = _categoryId;
    if (catId == null || limit <= 0) {
      _snack('Pick a category and enter a monthly limit');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(databaseProvider).addBudget(
            BudgetsCompanion.insert(
                categoryId: catId, month: widget.monthKey, limit: limit),
          );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messengerKey,
      child: FormSheet(
        title: 'Add budget',
      subtitle: 'Set a monthly spending limit per category.',
      actionLabel: 'Add budget',
      onAction: _save,
      busy: _saving,
      children: [
        CategoryPickerSection(
          kind: 'expense',
          lockKind: true,
          selectedId: _categoryId,
          onSelected: (c) => setState(() => _categoryId = c.id),
        ),
        const SizedBox(height: 16),
        const FormSectionLabel('Monthly limit'),
        FormAmountEntry(controller: _limitCtrl, autofocus: true),
        const SizedBox(height: 8),
      ],
      ),
    );
  }
}

class _EditBudgetLimitSheet extends ConsumerStatefulWidget {
  const _EditBudgetLimitSheet({required this.budgetId});

  final int budgetId;

  @override
  ConsumerState<_EditBudgetLimitSheet> createState() =>
      _EditBudgetLimitSheetState();
}

class _EditBudgetLimitSheetState
    extends ConsumerState<_EditBudgetLimitSheet> {
  final _ctrl = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return FutureBuilder<Budget?>(
      future: db.getBudgetById(widget.budgetId),
      builder: (context, bSnap) {
        final budget = bSnap.data;
        if (budget != null && !_loaded) {
          _ctrl.text = formatAmountInput(budget.limit);
          _loaded = true;
        }
        return StreamBuilder<List<Category>>(
          stream: db.watchCategories(),
          builder: (context, catsSnap) {
            Category? c;
            final cats = catsSnap.data ?? const <Category>[];
            for (final x in cats) {
              if (budget != null && x.id == budget.categoryId) c = x;
            }
            return FormSheet(
              title: 'Edit budget limit',
              actionLabel: 'Save changes',
              onAction: () => Navigator.of(context)
                  .pop(parseAmountInput(_ctrl.text)),
              children: [
                if (c != null) _categoryTile(context, c),
                if (c != null) const SizedBox(height: 16),
                const FormSectionLabel('Monthly limit'),
                FormAmountEntry(controller: _ctrl, autofocus: true),
                const SizedBox(height: 8),
              ],
            );
          },
        );
      },
    );
  }

  Widget _categoryTile(BuildContext context, Category c) {
    final color = colorFromHex(c.colorHex);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(iconForKey(c.iconKey),
              color: onAccent(color), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(c.name,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
