import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_prefs.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/shaker.dart';
import '../../core/widgets/sliding_segmented.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// "Add debt" as a bottom sheet, matching the other form sheets:
/// direction switcher, name, amount, date + time, color, description,
/// optional due date, wallet (with a "don't use wallet" toggle), and the
/// transaction-history toggle. Validation errors appear inline under
/// each field, like the add-transaction sheet.
class AddDebtSheet extends ConsumerStatefulWidget {
  const AddDebtSheet({super.key, this.initialDirection = 'payable'});

  /// payable (I borrowed) | receivable (I lent)
  final String initialDirection;

  @override
  ConsumerState<AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends ConsumerState<AddDebtSheet> {
  static const _colors = [
    '#38BDF8',
    '#A78BFA',
    '#F472B6',
    '#C6FF4A',
    '#FB923C',
    '#F87171',
    '#34D399',
    '#9CA3AF',
  ];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;
  late String _direction;
  late DateTime _date;
  late TimeOfDay _time;
  String _colorHex = '#38BDF8';
  DateTime? _dueDate;
  int? _walletId;
  bool _noWallet = false;
  bool _recordTx = true;
  bool _saving = false;

  String? _nameError;
  String? _amountError;
  String? _walletError;
  final _nameShake = ShakeController();
  final _amountShake = ShakeController();
  final _walletShake = ShakeController();

  bool get _isBorrowing => _direction == 'payable';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _amountCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _direction = widget.initialDirection;
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _time = TimeOfDay.fromDateTime(now);
    _nameCtrl.addListener(_clearNameError);
    _amountCtrl.addListener(_clearAmountError);
  }

  void _clearNameError() {
    if (_nameError != null) setState(() => _nameError = null);
  }

  void _clearAmountError() {
    if (_amountError != null) setState(() => _amountError = null);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_clearNameError);
    _amountCtrl.removeListener(_clearAmountError);
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  DateTime get _dateTime =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  /// Inline field error, styled like the add-transaction sheet's.
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

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return FormSheet(
      title: 'Add debt',
      actionLabel: 'Save',
      onAction: _save,
      busy: _saving,
      children: [
        SlidingSegmented<String>(
          values: const ['payable', 'receivable'],
          labels: const ['I borrowed', 'I lent'],
          selected: _direction,
          onChanged: (v) => setState(() => _direction = v),
        ),
        const SizedBox(height: 16),
        const FormSectionLabel('Name'),
        const SizedBox(height: 8),
        Shaker(
          controller: _nameShake,
          child: TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText:
                  _isBorrowing ? 'Who do you borrow from?' : 'Who owes you?',
              errorText: _nameError,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Shaker(
          controller: _amountShake,
          child: FormAmountEntry(controller: _amountCtrl),
        ),
        _fieldError(_amountError),
        const SizedBox(height: 16),
        const FormSectionLabel('Date & time'),
        const SizedBox(height: 8),
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
                    firstDate: DateTime(2000),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365 * 5)),
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
        const FormSectionLabel('Color'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final hex in _colors)
              GestureDetector(
                onTap: () => setState(() => _colorHex = hex),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorFromHex(hex),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _colorHex == hex
                          ? context.textPrimary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: _colorHex == hex
                      ? Icon(Icons.check,
                          size: 20, color: onAccent(colorFromHex(hex)))
                      : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const FormSectionLabel('Description'),
        const SizedBox(height: 8),
        TextField(
          controller: _descCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'What was it for?',
          ),
        ),
        const SizedBox(height: 16),
        const FormSectionLabel('Due date (optional)'),
        const SizedBox(height: 8),
        FormDatePill(
          date: _dueDate,
          placeholder: 'No due date',
          onClear:
              _dueDate == null ? null : () => setState(() => _dueDate = null),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate:
                  _dueDate ?? DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            );
            if (picked != null) setState(() => _dueDate = picked);
          },
        ),
        const SizedBox(height: 16),
        const FormSectionLabel('Wallet'),
        const SizedBox(height: 8),
        StreamBuilder<List<Wallet>>(
          stream: db.watchWallets(),
          builder: (context, snap) {
            final wallets = snap.data ?? const <Wallet>[];
            if (_walletId != null &&
                wallets.every((w) => w.id != _walletId)) {
              _walletId = null;
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Don't use wallet"),
          value: _noWallet,
          onChanged: (v) => setState(() {
            _noWallet = v;
            if (v) {
              _walletId = null;
              _walletError = null;
            }
          }),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show in transaction history'),
          subtitle: const Text('Record this debt as a transaction'),
          value: _recordTx,
          onChanged: (v) => setState(() => _recordTx = v),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amount = parseAmountInput(_amountCtrl.text);
    final nameError = name.isEmpty ? 'Please enter a name' : null;
    final amountError = amount <= 0 ? 'Please enter an amount' : null;
    final walletError = (!_noWallet && _walletId == null)
        ? 'Please select a wallet'
        : null;
    setState(() {
      _nameError = nameError;
      _amountError = amountError;
      _walletError = walletError;
    });
    if (nameError != null || amountError != null || walletError != null) {
      if (nameError != null) _nameShake.shake();
      if (amountError != null) _amountShake.shake();
      if (walletError != null) _walletShake.shake();
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    try {
      final id = await db.createDebt(
        person: name,
        note: _descCtrl.text.trim(),
        amount: amount,
        direction: _direction,
        dueDate: _dueDate,
        walletId: _noWallet ? null : _walletId,
        colorHex: _colorHex,
        recordAsTransaction: _recordTx,
        createdAt: _dateTime,
      );
      if (_dueDate != null && AppPrefs.debtReminders) {
        await NotificationService.scheduleDebtReminder(
          debtId: id,
          person: name,
          amount: amount,
          payable: _direction == 'payable',
          dueDate: _dueDate!,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) Navigator.pop(context);
  }
}
