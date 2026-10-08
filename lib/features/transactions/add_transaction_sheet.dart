import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/app_prefs.dart';
import '../../core/services/budget_alerts.dart';
import '../../core/services/category_suggester.dart';
import '../../core/theme/app_accents.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/shaker.dart';
import '../../core/widgets/sliding_segmented.dart';
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
    this.initialAmount,
    this.initialNote,
    this.initialDate,
    this.ocrFilled = false,
    this.ocrCandidates = const [],
    this.ocrRawText,
  });

  final String initialKind;
  final TransactionWithDetails? existing;
  final String? attachedPhotoPath;
  final int? initialWalletId;

  /// Whole-IDR amount prefill, e.g. from receipt OCR.
  final int? initialAmount;

  /// Description prefill, e.g. the merchant name from receipt OCR.
  final String? initialNote;

  /// Date prefill, e.g. the receipt date from OCR.
  final DateTime? initialDate;

  /// True when fields were pre-filled by receipt OCR: shows a
  /// "please verify" hint since OCR is best-effort.
  final bool ocrFilled;

  /// Other plausible totals from the receipt, best first. Shown as
  /// alternatives when the OCR-picked amount looks wrong.
  final List<int> ocrCandidates;

  /// Raw text read off the receipt, for the "what I read" expander.
  final String? ocrRawText;

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  // The bottom-sheet route has no ScaffoldMessenger of its own, so without
  // this every snackbar would render behind the modal barrier and only
  // become visible after the sheet closes.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Shows a snackbar *inside* the sheet.
  void _snack(String message) {
    _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
  }

  late String _kind;
  int? _categoryId;
  int? _walletId;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String? _photoPath;
  bool _saving = false;
  bool _success = false;
  String? _descError;
  String? _amountError;
  String? _categoryError;
  String? _walletError;
  final _descShake = ShakeController();
  final _amountShake = ShakeController();
  final _categoryShake = ShakeController();
  final _walletShake = ShakeController();

  /// Smart suggestion state: the recommended category (badged in the grid)
  /// plus debounce/sequencing for the note listener.
  int? _suggestedId;
  Timer? _suggestTimer;
  int _suggestSeq = 0;

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
      _descCtrl.text = e.transaction.note;
      _memoCtrl.text = e.transaction.memo;
      _categoryId = e.transaction.categoryId;
      _walletId = e.transaction.walletId;
      _date = e.transaction.date;
      _time = TimeOfDay.fromDateTime(e.transaction.date);
    } else {
      _kind = widget.initialKind;
      _walletId = widget.initialWalletId;
      // Receipt OCR prefill (best-effort — the user reviews everything).
      if (widget.initialAmount != null) {
        _amountCtrl.text = formatAmountInput(widget.initialAmount!);
      }
      if (widget.initialNote != null) {
        _descCtrl.text = widget.initialNote!;
      }
      if (widget.initialDate != null) {
        _date = widget.initialDate!;
        _time = TimeOfDay.fromDateTime(widget.initialDate!);
      }
      if (widget.ocrFilled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _snack('Filled from receipt — please verify the details.');
        });
      }
    }
    _descCtrl.addListener(_onDescChanged);
    _amountCtrl.addListener(_onAmountChanged);
    // Suggest for a prefilled description (edit mode) once the sheet settles.
    if (_descCtrl.text.trim().isNotEmpty && AppPrefs.smartSuggestions) {
      Future.microtask(_runSuggestion);
    }
  }

  @override
  void dispose() {
    _suggestTimer?.cancel();
    _descCtrl.removeListener(_onDescChanged);
    _amountCtrl.removeListener(_onAmountChanged);
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  /// Debounced smart suggestion: as the description is typed, recommend
  /// the category the user usually picks for these keywords.
  void _onDescChanged() {
    _suggestTimer?.cancel();
    if (_descError != null) setState(() => _descError = null);
    if (!AppPrefs.smartSuggestions || _descCtrl.text.trim().isEmpty) {
      if (_suggestedId != null) setState(() => _suggestedId = null);
      return;
    }
    _suggestTimer = Timer(const Duration(milliseconds: 400), _runSuggestion);
  }

  void _onAmountChanged() {
    if (_amountError != null) setState(() => _amountError = null);
  }

  /// Inline field error, styled like the description field's error text.
  Widget _fieldError(String? message) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }

  Future<void> _runSuggestion() async {
    final seq = ++_suggestSeq;
    final note = _descCtrl.text.trim();
    if (note.isEmpty || !AppPrefs.smartSuggestions) return;
    final suggester = CategorySuggester(ref.read(databaseProvider));
    await suggester.ensureBackfilled();
    final s = await suggester.suggest(note: note, kind: _kind);
    if (!mounted || seq != _suggestSeq) return;
    setState(() {
      _suggestedId = s?.categoryId;
      // High-confidence suggestions pre-select when nothing is chosen
      // yet. The user's own tap always wins afterwards.
      if (s != null && s.autoSelect && _categoryId == null) {
        _categoryId = s.categoryId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Stack(
        children: [
          FormSheet(
            title: _editing
                ? 'Edit record'
                : (_kind == 'income' ? 'Add income' : 'Add expense'),
            actionLabel: _editing ? 'Save changes' : 'Save',
            onAction: _save,
            busy: _saving,
            children: [
              SlidingSegmented<String>(
                values: const ['expense', 'income'],
                labels: const ['Expense', 'Income'],
                selected: _kind,
                onChanged: (v) {
                  setState(() {
                    _kind = v;
                    _categoryId = null;
                    _suggestedId = null;
                  });
                  // The description didn't change, but the kind did: re-suggest.
                  _runSuggestion();
                },
              ),
              const SizedBox(height: 16),
              _templateRow(context, db),
              const SizedBox(height: 16),
              Shaker(
                controller: _amountShake,
                child: FormAmountEntry(controller: _amountCtrl),
              ),
              _fieldError(_amountError),
              const SizedBox(height: 16),
              const FormSectionLabel('Description *'),
              const SizedBox(height: 8),
              Shaker(
                controller: _descShake,
                child: TextField(
                  controller: _descCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'What was this for?',
                    errorText: _descError,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Shaker(
                controller: _categoryShake,
                child: CategoryPickerSection(
                  kind: _kind,
                  selectedId: _categoryId,
                  suggestedId: _suggestedId,
                  onSelected: (c) => setState(() {
                    _kind = c.kind;
                    _categoryId = c.id;
                    _categoryError = null;
                  }),
                ),
              ),
              _fieldError(_categoryError),
              const SizedBox(height: 16),
              const FormSectionLabel('Wallet'),
              StreamBuilder<List<Wallet>>(
                // In edit mode the transaction's own wallet must stay
                // selectable even when it sits outside the active scope.
                stream: db.watchWallets(
                  accountId: _editing
                      ? null
                      : ref.watch(selectedAccountProvider),
                ),
                builder: (context, snap) {
                  final wallets = snap.data ?? const <Wallet>[];
                  if (_walletId == null ||
                      wallets.every((w) => w.id != _walletId)) {
                    _walletId = wallets.isNotEmpty ? wallets.first.id : null;
                  }
                  return Shaker(
                    controller: _walletShake,
                    child: Wrap(
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
                            onSelected: (_) => setState(() {
                              _walletId = w.id;
                              _walletError = null;
                            }),
                          ),
                      ],
                    ),
                  );
                },
              ),
              _fieldError(_walletError),
              const SizedBox(height: 16),
              const FormSectionLabel('Date & time'),
              Row(
                children: [
                  Expanded(
                    child: FormDatePill(
                      date: _date,
                      placeholder: 'Pick a date',
                      onTap: () async {
                        Haptics.select();
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
                        Haptics.select();
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
              const FormSectionLabel('Memo (optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _memoCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Extra details…'),
              ),
              if (!_editing) ...[const SizedBox(height: 16), _receiptSection()],
              const SizedBox(height: 8),
            ],
          ),
          if (_success) const _SuccessOverlay(),
        ],
      ),
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
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: context.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Receipt attached',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Tap to preview',
                      style: TextStyle(color: context.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove photo',
                icon: const Icon(Icons.close),
                onPressed: () {
                  Haptics.light();
                  setState(() => _photoPath = null);
                },
              ),
            ],
          ),
        if (widget.ocrFilled && widget.ocrCandidates.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Not the right amount?',
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in widget.ocrCandidates.take(4))
                ActionChip(
                  label: Text(formatMoney(c)),
                  onPressed: () {
                    Haptics.select();
                    setState(() {
                      _amountCtrl.text = formatAmountInput(c);
                    });
                  },
                ),
            ],
          ),
        ],
        if (widget.ocrFilled && widget.ocrRawText != null) ...[
          const SizedBox(height: 8),
          _OcrRawTextExpander(rawText: widget.ocrRawText!),
        ],
      ],
    );
  }

  Future<void> _pickPhoto() async {
    Haptics.select();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () {
                Haptics.select();
                Navigator.pop(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Haptics.select();
                Navigator.pop(context, ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      // Downscale at capture: a 12MP camera photo at full resolution is
      // several MB; 1600px on the long edge keeps receipts readable at a
      // fraction of the size. The copy saved to receipts/ inherits this.
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _photoPath = picked.path);
      }
    } catch (e) {
      if (mounted) {
        _snack('Could not pick photo: $e');
      }
    }
  }

  void _previewPhoto() {
    final path = _photoPath;
    if (path == null) return;
    Haptics.select();
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
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
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
                        onLongPress: () => _confirmDeleteTemplate(db, t),
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
      _descCtrl.text = t.note;
    });
    db.bumpTemplateUse(t.id);
    _snack('Filled from "${t.name}"');
  }

  Future<void> _saveTemplate(AppDatabase db) async {
    final amount = parseAmountInput(_amountCtrl.text);
    if (amount <= 0 || _categoryId == null || _walletId == null) {
      _snack('Fill in amount, category and wallet first');
      return;
    }
    Haptics.medium();
    final nameCtrl = TextEditingController(
      text: _descCtrl.text.trim().isEmpty
          ? formatMoney(amount)
          : _descCtrl.text.trim(),
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as template'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Template name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameCtrl.text.trim()),
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
        note: Value(_descCtrl.text.trim()),
      ),
    );
    if (mounted) {
      _snack('Template "$name" saved');
    }
  }

  Future<void> _confirmDeleteTemplate(
    AppDatabase db,
    TransactionTemplate t,
  ) async {
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
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
    final desc = _descCtrl.text.trim();
    final memo = _memoCtrl.text.trim();
    // Inline per-field errors, like the description field's red text —
    // no snackbar needed.
    final descError = desc.isEmpty ? 'Please describe this transaction' : null;
    final amountError = amount <= 0 ? 'Please enter an amount' : null;
    final categoryError = _categoryId == null
        ? 'Please select a category'
        : null;
    final walletError = _walletId == null ? 'Please select a wallet' : null;
    setState(() {
      _descError = descError;
      _amountError = amountError;
      _categoryError = categoryError;
      _walletError = walletError;
    });
    if (descError != null ||
        amountError != null ||
        categoryError != null ||
        walletError != null) {
      if (descError != null) _descShake.shake();
      if (amountError != null) _amountShake.shake();
      if (categoryError != null) _categoryShake.shake();
      if (walletError != null) _walletShake.shake();
      return;
    }
    Haptics.medium();
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
          note: desc,
          memo: memo,
          date: _dateTime,
        );
      } else {
        final id = await db.addTransaction(
          TransactionsCompanion.insert(
            walletId: _walletId!,
            categoryId: _categoryId!,
            kind: _kind,
            amount: amount,
            note: Value(desc),
            memo: Value(memo),
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
    // Feed the smart suggester: corrections self-correct future picks.
    if (AppPrefs.smartSuggestions && _categoryId != null) {
      final suggester = CategorySuggester(db);
      final newNote = desc;
      if (_editing) {
        final e = widget.existing!.transaction;
        if (e.note != newNote || e.categoryId != _categoryId) {
          unawaited(suggester.unlearn(note: e.note, categoryId: e.categoryId));
          unawaited(suggester.learn(note: newNote, categoryId: _categoryId!));
        }
      } else {
        unawaited(suggester.learn(note: newNote, categoryId: _categoryId!));
      }
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
              duration: AppMotion.slow,
              curve: Curves.easeOut,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: Opacity(opacity: (1.6 - scale) / 1.1, child: child),
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
                child: Icon(
                  Icons.check,
                  color: onAccent(context.accent),
                  size: 44,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Expandable "what the OCR read" viewer: helps the user (and bug reports)
/// see exactly what text the recognizer pulled off the receipt.
class _OcrRawTextExpander extends StatefulWidget {
  const _OcrRawTextExpander({required this.rawText});

  final String rawText;

  @override
  State<_OcrRawTextExpander> createState() => _OcrRawTextExpanderState();
}

class _OcrRawTextExpanderState extends State<_OcrRawTextExpander> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            Haptics.light();
            setState(() => _open = !_open);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'What I read',
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
              Icon(
                _open ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: context.textMuted,
              ),
            ],
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.textMuted.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              widget.rawText,
              style: TextStyle(
                fontSize: 12,
                color: context.textMuted,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
