import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/budget_alerts.dart';
import '../../core/theme/app_accents.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/form_sheet.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../categories/category_picker_section.dart';

/// Bottom sheet for fast expense/income recording — the app's core loop.
/// Also used for editing: pass [existing] to prefill and update instead of
/// inserting. [attachedPhotoPath] pre-attaches a receipt photo (e.g. from
/// the scan flow); the sheet also lets the user attach one manually.
class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({
    super.key,
    this.initialKind = 'expense',
    this.existing,
    this.attachedPhotoPath,
    this.initialWalletId,
  });

  final String initialKind;
  final TransactionWithDetails? existing;
  final String? attachedPhotoPath;
  final int? initialWalletId;

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late String _kind;
  int? _categoryId;
  int? _walletId;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String? _photoPath;
  bool _saving = false;
  bool _success = false;

  bool get _editing => widget.existing != null;

  DateTime get _dateTime =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  @override
  void initState() {
    super.initState();
    _photoPath = widget.attachedPhotoPath;
    final e = widget.existing;
    if (e != null) {
      _kind = e.transaction.kind;
      _amountCtrl.text = formatAmountInput(e.transaction.amount);
      _noteCtrl.text = e.transaction.note;
      _categoryId = e.transaction.categoryId;
      _walletId = e.transaction.walletId;
      _date = e.transaction.date;
      _time = TimeOfDay.fromDateTime(e.transaction.date);
    } else {
      _kind = widget.initialKind;
      _walletId = widget.initialWalletId;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Stack(
      children: [
        FormSheet(
          title: _editing
              ? 'Edit record'
              : (_kind == 'income' ? 'Add income' : 'Add expense'),
          actionLabel: _editing ? 'Save changes' : 'Save',
          onAction: _save,
          busy: _saving,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                _kind = s.first;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 16),
            _templateRow(context, db),
            const SizedBox(height: 16),
            FormAmountEntry(controller: _amountCtrl),
            const SizedBox(height: 16),
            CategoryPickerSection(
              kind: _kind,
              selectedId: _categoryId,
              onSelected: (c) => setState(() {
                _kind = c.kind;
                _categoryId = c.id;
              }),
            ),
            const SizedBox(height: 16),
            const FormSectionLabel('Wallet'),
            StreamBuilder<List<Wallet>>(
              // In edit mode the transaction's own wallet must stay
              // selectable even when it sits outside the active scope.
              stream: db.watchWallets(
                  accountId:
                      _editing ? null : ref.watch(selectedAccountProvider)),
              builder: (context, snap) {
                final wallets = snap.data ?? const <Wallet>[];
                if (_walletId == null ||
                    wallets.every((w) => w.id != _walletId)) {
                  _walletId = wallets.isNotEmpty ? wallets.first.id : null;
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final w in wallets)
                      ChoiceChip(
                        label: Text(w.name),
                        selected: _walletId == w.id,
                        selectedColor: context.accent,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          color: _walletId == w.id
                              ? onAccent(context.accent)
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) =>
                            setState(() => _walletId = w.id),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const FormSectionLabel('Date & time'),
            Row(
              children: [
                Expanded(
                  child: FormDatePill(
                    date: _date,
                    placeholder: 'Pick a date',
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FormDatePill(
                    date: _date,
                    placeholder: '',
                    icon: Icons.schedule_outlined,
                    text:
                        '${_time.hour.toString().padLeft(2, '0')}.${_time.minute.toString().padLeft(2, '0')}',
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _time,
                      );
                      if (picked != null) setState(() => _time = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
              ),
            ),
            if (!_editing) ...[
              const SizedBox(height: 16),
              _receiptSection(),
            ],
            const SizedBox(height: 8),
          ],
        ),
        if (_success) const _SuccessOverlay(),
      ],
    );
  }

  /// Receipt photo attachment: camera/gallery picker, thumbnail preview
  /// (tap for full-screen), and remove. The file is copied into the
  /// receipts folder on save via [AppDatabase.addPhoto].
  Widget _receiptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FormSectionLabel('Receipt'),
        if (_photoPath == null)
          OutlinedButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Attach receipt photo'),
          )
        else
          Row(
            children: [
              GestureDetector(
                onTap: _previewPhoto,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_photoPath!),
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 96,
                      height: 96,
                      color: context.raised,
                      alignment: Alignment.center,
                      child: Icon(Icons.broken_image_outlined,
                          color: context.textMuted),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Receipt attached',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('Tap to preview',
                        style: TextStyle(
                            color: context.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove photo',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _photoPath = null),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, imageQuality: 85);
      if (picked != null && mounted) {
        setState(() => _photoPath = picked.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick photo: $e')),
        );
      }
    }
  }

  void _previewPhoto() {
    final path = _photoPath;
    if (path == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                color: Colors.white,
                style: IconButton.styleFrom(
                    backgroundColor: Colors.black54),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One-tap templates: tap fills the form, long-press deletes,
  /// trailing chip saves the current form as a template.
  Widget _templateRow(BuildContext context, AppDatabase db) {
    return StreamBuilder<List<TransactionTemplate>>(
      stream: db.watchTransactionTemplates(),
      builder: (context, snap) {
        final templates = snap.data ?? const <TransactionTemplate>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FormSectionLabel('Templates'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final t in templates)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onLongPress: () =>
                            _confirmDeleteTemplate(db, t),
                        child: ChoiceChip(
                          label: Text(t.name),
                          selected: false,
                          onSelected: (_) => _applyTemplate(db, t),
                        ),
                      ),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Save current'),
                    onPressed: () => _saveTemplate(db),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _applyTemplate(AppDatabase db, TransactionTemplate t) {
    setState(() {
      _kind = t.kind;
      _categoryId = t.categoryId;
      _walletId = t.walletId;
      _amountCtrl.text = formatAmountInput(t.amount);
      _noteCtrl.text = t.note;
    });
    db.bumpTemplateUse(t.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Filled from "${t.name}"')),
    );
  }

  Future<void> _saveTemplate(AppDatabase db) async {
    final amount = parseAmountInput(_amountCtrl.text);
    if (amount <= 0 || _categoryId == null || _walletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Fill in amount, category and wallet first')),
      );
      return;
    }
    final nameCtrl = TextEditingController(
        text: _noteCtrl.text.trim().isEmpty
            ? formatMoney(amount)
            : _noteCtrl.text.trim());
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as template'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration:
              const InputDecoration(labelText: 'Template name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, nameCtrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await db.addTransactionTemplate(
      TransactionTemplatesCompanion.insert(
        name: name,
        walletId: _walletId!,
        categoryId: _categoryId!,
        kind: _kind,
        amount: amount,
        note: Value(_noteCtrl.text.trim()),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template "$name" saved')),
      );
    }
  }

  Future<void> _confirmDeleteTemplate(
      AppDatabase db, TransactionTemplate t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('"${t.name}" will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expense,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await db.deleteTransactionTemplate(t.id);
    }
  }

  Future<void> _save() async {
    final amount = parseAmountInput(_amountCtrl.text);
    if (amount <= 0 || _categoryId == null || _walletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount, category and wallet')),
      );
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    try {
      if (_editing) {
        final e = widget.existing!.transaction;
        await db.updateTransaction(
          id: e.id,
          walletId: _walletId!,
          categoryId: _categoryId!,
          kind: _kind,
          amount: amount,
          note: _noteCtrl.text.trim(),
          date: _dateTime,
        );
      } else {
        final id = await db.addTransaction(
          TransactionsCompanion.insert(
            walletId: _walletId!,
            categoryId: _categoryId!,
            kind: _kind,
            amount: amount,
            note: Value(_noteCtrl.text.trim()),
            date: _dateTime,
          ),
        );
        if (_photoPath != null) {
          await db.addPhoto(id, _photoPath!);
        }
      }
      await checkBudgetAlerts(ref);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    // Brief success state (checkmark + scale animation), then close.
    Haptics.medium();
    setState(() => _success = true);
    await Future.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _editing
              ? 'Record updated'
              : '${_kind == 'income' ? 'Income' : 'Expense'} of ${formatMoney(amount)} saved',
        ),
      ),
    );
  }
}

/// Brief success state: lime checkmark with a springy scale-in plus an
/// expanding ripple ring, shown inside the sheet before it closes.
class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Theme.of(
          context,
        ).scaffoldBackgroundColor.withValues(alpha: 0.85),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ripple ring: expands and fades once.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1.6),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: (1.6 - scale) / 1.1,
                  child: child,
                ),
              ),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.accent.withValues(alpha: 0.6),
                    width: 3,
                  ),
                ),
              ),
            ),
            // Checkmark: pops in with an overshoot bounce.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.3, end: 1.0),
              duration: AppMotion.normal,
              curve: Curves.elasticOut,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: context.accent,
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.check, color: onAccent(context.accent), size: 44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
