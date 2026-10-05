import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
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
  final saved = await showFormSheet<bool>(
    context,
    (context) => _GoalFormSheet(existing: existing),
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
  // Own messenger: the bottom-sheet route has none, so snackbars would
  // otherwise render behind the modal barrier.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  void _snack(String message) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _targetCtrl = TextEditingController(
        text: e == null ? '' : formatAmountInput(e.target));
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
      initialDate:
          _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final target = parseAmountInput(_targetCtrl.text);
    if (name.isEmpty || target <= 0) {
      _snack('Enter a name and a target amount');
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
    return ScaffoldMessenger(
      key: _messengerKey,
      child: FormSheet(
        title: _editing ? 'Edit savings goal' : 'Add savings goal',
      subtitle: _editing
          ? null
          : 'Set aside money for something that matters.',
      actionLabel: _editing ? 'Save changes' : 'Add goal',
      onAction: _save,
      busy: _saving,
      children: [
        TextField(
          controller: _nameCtrl,
          autofocus: !_editing,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const SizedBox(height: 16),
        const FormSectionLabel('Target amount'),
        FormAmountEntry(controller: _targetCtrl),
        const SizedBox(height: 16),
        const FormSectionLabel('Goal date (optional)'),
        FormDatePill(
          date: _deadline,
          placeholder: 'Pick a goal date',
          onTap: _pickDeadline,
          onClear: () => setState(() => _deadline = null),
        ),
        const SizedBox(height: 16),
        const FormSectionLabel('Color'),
        ColorDots(
          selected: _colorHex,
          onSelected: (hex) => setState(() => _colorHex = hex),
        ),
        const SizedBox(height: 8),
      ],
      ),
    );
  }
}
