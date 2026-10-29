import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/form_sheet.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// Shows the standardized Add/Edit savings goal bottom sheet. Returns true
/// when the goal was saved.
Future<bool> showGoalFormSheet(
  BuildContext context,
  WidgetRef ref, {
  Goal? existing,
}) async {
  final saved = await showSnackSheet<bool>(
    context,
    (context) => _GoalFormSheet(existing: existing),
    borderRadius: 28,
  );
  return saved == true;
}

class _GoalFormSheet extends ConsumerStatefulWidget {
  const _GoalFormSheet({this.existing});

  final Goal? existing;

  @override
  ConsumerState<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends ConsumerState<_GoalFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _targetCtrl;
  DateTime? _deadline;
  late String _colorHex;
  bool _saving = false;
  // A Scaffold inside the sheet route registers with the root
  // ScaffoldMessenger, so snackbars render on the front layer, above
  // the sheet. (A bare nested ScaffoldMessenger has no Scaffold to
  // present through and silently swallows them.)

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _targetCtrl = TextEditingController(
      text: e == null ? '' : formatAmountInput(e.target),
    );
    _deadline = e?.deadline;
    _colorHex = e?.colorHex ?? '#C6FF4A';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameCtrl.text.trim();
    final target = parseAmountInput(_targetCtrl.text);
    if (name.isEmpty || target <= 0) {
      _snack(l10n.goalEnterNameTarget);
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    try {
      if (_editing) {
        await db.updateGoal(
          id: widget.existing!.id,
          name: name,
          target: target,
          deadline: _deadline,
          colorHex: _colorHex,
        );
      } else {
        await db.addGoal(
          GoalsCompanion.insert(
            name: name,
            target: target,
            deadline: Value(_deadline),
            colorHex: Value(_colorHex),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    Haptics.medium();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FormSheet(
      title: _editing ? l10n.goalEditTitle : l10n.budgetsAddSavingsGoal,
      subtitle: _editing ? null : l10n.goalAddSubtitle,
      actionLabel: _editing ? l10n.commonSaveChanges : l10n.goalAddGoal,
      onAction: _save,
      busy: _saving,
      children: [
        TextField(
          controller: _nameCtrl,
          autofocus: !_editing,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: l10n.commonNameLabel),
        ),
        const SizedBox(height: 16),
        FormSectionLabel(l10n.goalTargetLabel),
        FormAmountEntry(controller: _targetCtrl),
        const SizedBox(height: 16),
        FormSectionLabel(l10n.goalDateOptional),
        FormDatePill(
          date: _deadline,
          placeholder: l10n.goalPickDate,
          onTap: _pickDeadline,
          onClear: () => setState(() => _deadline = null),
        ),
        const SizedBox(height: 16),
        FormSectionLabel(l10n.commonColorLabel),
        ColorDots(
          selected: _colorHex,
          onSelected: (hex) => setState(() => _colorHex = hex),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
