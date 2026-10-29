import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/app_prefs.dart';
import '../../core/services/budget_alerts.dart';
import '../../core/services/category_suggester.dart';
import '../../core/theme/app_accents.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/paylater.dart';
import '../../core/utils/wallet_resolve.dart';
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
  final _descFocus = FocusNode();
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

  /// Tenor picker state for paylater wallets (1x/3x/6x/12x), plus the
  /// last parsed amount (so typing only rebuilds the quote when the
  /// amount itself actually changes).
  int _tenor = 1;
  int _lastQuoteAmount = -1;
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

  /// Description autocomplete: past descriptions matching the typed text,
  /// shown while the description field is focused.
  List<String> _descSuggestions = const [];

  bool get _editing => widget.existing != null;

  DateTime get _dateTime =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  /// True when the picked date is today — the Today button hides then.
  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

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
      } else {
        // Session sticky date: reopen on the last saved transaction's
        // date. The time stays "now" from the field initializer — only
        // the date sticks.
        final sticky = ref.read(lastTransactionDateProvider);
        if (sticky != null) _date = sticky;
      }
      if (widget.ocrFilled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _snack(AppLocalizations.of(context)!.txFilledFromReceipt);
        });
      }
    }
    _descCtrl.addListener(_onDescChanged);
    _amountCtrl.addListener(_onAmountChanged);
    // Rebuild when the description field gains/loses focus so the
    // autocomplete list shows and hides at the right time.
    _descFocus.addListener(() {
      if (mounted) setState(() {});
    });
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
    _descFocus.dispose();
    super.dispose();
  }

  /// Debounced smart suggestion: as the description is typed, recommend
  /// the category the user usually picks for these keywords.
  void _onDescChanged() {
    _suggestTimer?.cancel();
    if (_descError != null) setState(() => _descError = null);
    if (!AppPrefs.smartSuggestions || _descCtrl.text.trim().isEmpty) {
      if (_suggestedId != null || _descSuggestions.isNotEmpty) {
        setState(() {
          _suggestedId = null;
          _descSuggestions = const [];
        });
      }
      return;
    }
    _suggestTimer = Timer(const Duration(milliseconds: 400), _runSuggestion);
  }

  void _onAmountChanged() {
    final parsed = parseAmountInput(_amountCtrl.text);
    if (_amountError != null || parsed != _lastQuoteAmount) {
      _lastQuoteAmount = parsed;
      if (mounted) setState(() => _amountError = null);
    }
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

  /// Autocomplete dropdown under the description field: past descriptions
  /// matching the typed text. Tapping one refills the whole form.
  Widget _descAutocompleteList() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.bgRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _descSuggestions.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.4)),
            InkWell(
              onTap: () => _applyDescriptionSuggestion(_descSuggestions[i]),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.history,
                        size: 18, color: context.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _descSuggestions[i],
                        style: Theme.of(context).textTheme.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _runSuggestion() async {
    final seq = ++_suggestSeq;
    final note = _descCtrl.text.trim();
    if (note.isEmpty || !AppPrefs.smartSuggestions) return;
    final db = ref.read(databaseProvider);
    final suggester = CategorySuggester(db);
    await suggester.ensureBackfilled();
    final s = await suggester.suggest(note: note, kind: _kind);
    if (!mounted || seq != _suggestSeq) return;
    // Past descriptions starting with the typed text, for autocomplete.
    // Runs after the (slower) keyword backfill so a stale frame can't
    // overwrite a newer keystroke's results.
    final matches = await db.suggestDescriptions(note, kind: _kind);
    if (!mounted || seq != _suggestSeq) return;
    setState(() {
      _suggestedId = s?.categoryId;
      // High-confidence suggestions pre-select when nothing is chosen
      // yet. The user's own tap always wins afterwards.
      if (s != null && s.autoSelect && _categoryId == null) {
        _categoryId = s.categoryId;
      }
      // Echoing back the exact text already typed is noise.
      _descSuggestions = matches
          .where((m) => m.toLowerCase() != note.toLowerCase())
          .toList();
    });
  }

  /// Fill the description field from a tapped autocomplete suggestion.
  void _applyDescriptionSuggestion(String note) {
    Haptics.light();
    // Detach the listener so the programmatic fill doesn't restart the
    // debounce; the category suggester runs once below for the new text.
    _descCtrl.removeListener(_onDescChanged);
    _descCtrl.text = note;
    _descCtrl.selection = TextSelection.collapsed(offset: note.length);
    _descCtrl.addListener(_onDescChanged);
    setState(() {
      _descSuggestions = const [];
      _descError = null;
    });
    _descFocus.unfocus();
    _runSuggestion();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(databaseProvider);
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Stack(
        children: [
          FormSheet(
            title: _editing
                ? l10n.txEditRecord
                : (_kind == 'income' ? l10n.txAddIncome : l10n.txAddExpense),
            actionLabel: _editing ? l10n.commonSaveChanges : l10n.commonSave,
            onAction: _save,
            busy: _saving,
            children: [
              SlidingSegmented<String>(
                values: const ['expense', 'income'],
                labels: [l10n.txExpense, l10n.txIncome],
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
              _templateRow(context, db, l10n),
              const SizedBox(height: 16),
              Shaker(
                controller: _amountShake,
                child: FormAmountEntry(controller: _amountCtrl),
              ),
              _fieldError(_amountError),
              const SizedBox(height: 16),
              FormSectionLabel(l10n.txDescription),
              const SizedBox(height: 8),
              Shaker(
                controller: _descShake,
                child: TextField(
                  controller: _descCtrl,
                  focusNode: _descFocus,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: l10n.txDescriptionHint,
                    errorText: _descError,
                  ),
                ),
              ),
              if (_descFocus.hasFocus && _descSuggestions.isNotEmpty)
                _descAutocompleteList(),
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
              FormSectionLabel(l10n.txWallet),
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
                  _walletId = resolveWalletId(wallets, _walletId);
                  Wallet? selected;
                  for (final w in wallets) {
                    if (w.id == _walletId) selected = w;
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Shaker(
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
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                                onSelected: (_) => setState(() {
                                  _walletId = w.id;
                                  _walletError = null;
                                }),
                              ),
                          ],
                        ),
                      ),
                      // Tenor calculator: only for new expenses on a
                      // paylater wallet, where splitting across months is
                      // a real decision. The quote is display-only — it
                      // never creates an installment plan by itself.
                      if (selected != null &&
                          selected.kind == 'paylater' &&
                          _kind == 'expense' &&
                          !_editing)
                        _tenorSection(selected, l10n),
                    ],
                  );
                },
              ),
              _fieldError(_walletError),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: FormSectionLabel(l10n.txDateTime)),
                  if (!_isToday)
                    TextButton(
                      onPressed: () {
                        Haptics.select();
                        setState(() => _date = DateTime.now());
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(l10n.commonToday),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: FormDatePill(
                      date: _date,
                      placeholder: l10n.txPickDate,
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
              FormSectionLabel(l10n.txMemo),
              const SizedBox(height: 8),
              TextField(
                controller: _memoCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: l10n.txMemoHint),
              ),
              if (!_editing) ...[const SizedBox(height: 16), _receiptSection(l10n)],
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
  Widget _receiptSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormSectionLabel(l10n.txReceipt),
        if (_photoPath == null)
          OutlinedButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: Text(l10n.txAttachReceipt),
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
                    Text(
                      l10n.txReceiptAttached,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      l10n.txTapToPreview,
                      style: TextStyle(color: context.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.txRemovePhoto,
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
            l10n.txNotRightAmount,
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
    final l10n = AppLocalizations.of(context)!;
    Haptics.select();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.txTakePhoto),
              onTap: () {
                Haptics.select();
                Navigator.pop(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.txChooseFromGallery),
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
        _snack(l10n.txCouldNotPickPhoto('$e'));
      }
    }
  }

  void _previewPhoto() {
    final l10n = AppLocalizations.of(context)!;
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
                tooltip: l10n.commonClose,
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
  Widget _templateRow(BuildContext context, AppDatabase db, AppLocalizations l10n) {
    return StreamBuilder<List<TransactionTemplate>>(
      stream: db.watchTransactionTemplates(),
      builder: (context, snap) {
        final templates = snap.data ?? const <TransactionTemplate>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FormSectionLabel(l10n.txTemplates),
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
                    label: Text(l10n.txSaveCurrent),
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
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _kind = t.kind;
      _categoryId = t.categoryId;
      _walletId = t.walletId;
      _amountCtrl.text = formatAmountInput(t.amount);
      _descCtrl.text = t.note;
    });
    db.bumpTemplateUse(t.id);
    _snack(l10n.txFilledFromTemplate(t.name));
  }

  /// Tenor picker + quote for a paylater expense. Flat-monthly-fee math
  /// from the wallet's own rate; when no rate is set the monthly amount
  /// is shown without interest and the gap is stated, never filled with
  /// an invented rate.
  Widget _tenorSection(Wallet wallet, AppLocalizations l10n) {
    const tenors = [1, 3, 6, 12];
    final amount = parseAmountInput(_amountCtrl.text);
    final quote = amount > 0
        ? calcTenor(
            principal: amount,
            tenor: _tenor,
            monthlyRatePercent: wallet.interestRateMonthly,
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        FormSectionLabel(l10n.txPayInInstallments),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final t in tenors)
              ChoiceChip(
                label: Text('${t}x'),
                selected: _tenor == t,
                selectedColor: context.accent,
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: _tenor == t
                      ? onAccent(context.accent)
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _tenor = t),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          quote == null
              ? l10n.txEnterAmountBreakdown
              : quote.totalInterest == null
              ? l10n.txInstallmentNoRate(formatMoney(quote.monthlyAmount))
              // gen-l10n orders params alphabetically: interest, monthly, total.
              : l10n.txInstallmentQuote(
                  formatMoney(quote.totalInterest!),
                  formatMoney(quote.monthlyAmount),
                  formatMoney(quote.totalPayable),
                ),
          style: TextStyle(color: context.textMuted, fontSize: 13),
        ),
      ],
    );
  }

  Future<void> _saveTemplate(AppDatabase db) async {
    final l10n = AppLocalizations.of(context)!;
    final amount = parseAmountInput(_amountCtrl.text);
    if (amount <= 0 || _categoryId == null || _walletId == null) {
      _snack(l10n.txFillAmountCategoryWallet);
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
        title: Text(l10n.txSaveAsTemplate),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: l10n.txTemplateName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameCtrl.text.trim()),
            child: Text(l10n.commonSave),
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
      _snack(l10n.txTemplateSaved(name));
    }
  }

  Future<void> _confirmDeleteTemplate(
    AppDatabase db,
    TransactionTemplate t,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.txDeleteTemplateTitle),
        content: Text(l10n.txTemplateRemoved(t.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await db.deleteTransactionTemplate(t.id);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final amount = parseAmountInput(_amountCtrl.text);
    final desc = _descCtrl.text.trim();
    final memo = _memoCtrl.text.trim();
    // Inline per-field errors, like the description field's red text —
    // no snackbar needed.
    final descError = desc.isEmpty ? l10n.txDescribeTransaction : null;
    final amountError = amount <= 0 ? l10n.txEnterAmount : null;
    final categoryError = _categoryId == null
        ? l10n.txSelectCategory
        : null;
    final walletError = _walletId == null ? l10n.txSelectWallet : null;
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
    final db = ref.read(databaseProvider);
    // Paylater income gate: a paylater wallet can never receive income.
    // Income would push its balance positive, which the dashboard reads
    // as "nothing owed" while the card shows money in the account.
    // Bills are paid via transfers, never top-ups (merchant refunds
    // belong in a transfer too).
    if (_walletId != null) {
      final wallet = await db.getWalletById(_walletId!);
      if (wallet != null &&
          isIncomeToPaylaterBlocked(walletKind: wallet.kind, kind: _kind)) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.txIncomeNotAllowed),
            content: Text(l10n.txIncomeNotAllowedBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonOk),
              ),
            ],
          ),
        );
        return;
      }
    }
    // Paylater freeze: a new expense on a paylater wallet is blocked
    // while frozen. The dialog offers to unfreeze and continue saving —
    // never a silent allow, and edits of existing records are exempt.
    if (!_editing && _kind == 'expense' && _walletId != null) {
      final wallet = await db.getWalletById(_walletId!);
      if (wallet != null &&
          isPaylaterSpendBlocked(
            frozen: AppPrefs.paylaterFrozen,
            walletKind: wallet.kind,
            isNewExpense: true,
          )) {
        if (!mounted) return;
        final unfreeze = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.txPaylaterFrozen),
            content: Text(l10n.txPaylaterFrozenBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.txUnfreezeAndSave),
              ),
            ],
          ),
        );
        if (unfreeze != true) return;
        await AppPrefs.setPaylaterFrozen(false);
      }
    }
    Haptics.medium();
    setState(() => _saving = true);
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
        // Tenor auto-plan: every NEW paylater expense becomes a plan —
        // including the default 1x, a 1-of-1 "pay next month" plan.
        // Edits never reach this branch, and the helper refuses
        // transfers, income, and non-paylater wallets outright.
        ({String name, int totalAmount, int installmentAmount, int totalCount})?
            plan;
        if (_kind == 'expense') {
          final wallet = await db.getWalletById(_walletId!);
          if (wallet != null && wallet.kind == 'paylater') {
            Category? category;
            for (final c in await db.select(db.categories).get()) {
              if (c.id == _categoryId!) category = c;
            }
            plan = autoPlanParams(
              isNew: true,
              transactionKind: _kind,
              walletKind: wallet.kind,
              amount: amount,
              tenor: _tenor,
              monthlyRatePercent: wallet.interestRateMonthly,
              note: desc,
              categoryName: category?.name,
            );
          }
        }
        Future<int> insertExpense() async {
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
          return id;
        }

        try {
          final p = plan;
          if (p != null) {
            // One transaction: the expense and its plan commit together
            // or not at all — addTransaction's own transaction joins
            // this outer one — so a failed plan insert can never leave
            // an orphan expense behind. The expense is linked to the
            // plan so the plan's history and delete cascade find it.
            await db.transaction(() async {
              final expenseId = await insertExpense();
              final planId = await db.addInstallmentPlan(
                walletId: _walletId!,
                name: p.name,
                totalAmount: p.totalAmount,
                installmentAmount: p.installmentAmount,
                totalCount: p.totalCount,
              );
              await db.setTransactionPlan(expenseId, planId);
            });
          } else {
            await insertExpense();
          }
        } catch (_) {
          // A failed save must be visible: without this, a rolled-back
          // save would leave the sheet open with no explanation.
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.txCouldntSave),
              content: Text(l10n.txCouldntSaveBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonOk),
                ),
              ],
            ),
          );
          return;
        }
      }
      // Remember the date for the next add, within this session only:
      // the sheet reopens on the last saved transaction's date. Edits
      // don't count — only new transactions set it. This runs only on
      // success: a failed insert returns early above, and a throw skips
      // past this point entirely.
      if (!_editing) {
        ref.read(lastTransactionDateProvider.notifier).set(_date);
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
              ? l10n.txRecordUpdated
              // gen-l10n orders params alphabetically: amount, kind.
              : l10n.txSavedAmount(
                  formatMoney(amount),
                  _kind == 'income' ? l10n.txIncome : l10n.txExpense,
                ),
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
    final l10n = AppLocalizations.of(context)!;
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
                l10n.txWhatIRead,
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
