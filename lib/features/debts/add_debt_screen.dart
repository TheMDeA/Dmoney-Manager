import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_prefs.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/amount_field.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// Full-screen "add debt" form, modeled on the classic debt-tracker UX:
/// direction switcher in the app bar, name, amount, date + time,
/// color, description, wallet (with a "don't use wallet" toggle),
/// optional due date, and the transaction-history toggle.
class AddDebtScreen extends ConsumerStatefulWidget {
  const AddDebtScreen({super.key, this.initialDirection = 'payable'});

  final String initialDirection; // payable (I borrowed) | receivable (I lent)

  @override
  ConsumerState<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends ConsumerState<AddDebtScreen> {
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
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  DateTime get _dateTime =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _direction,
            icon: const Icon(Icons.arrow_drop_down),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
            dropdownColor: context.raised,
            items: const [
              DropdownMenuItem(
                  value: 'payable', child: Text('I borrowed')),
              DropdownMenuItem(
                  value: 'receivable', child: Text('I lent')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _direction = v);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _save(context, db),
            child: const Text('SAVE'),
          ),
        ],
      ),
      body: StreamBuilder<List<Wallet>>(
        stream: db.watchWallets(),
        builder: (context, snap) {
          final wallets = snap.data ?? const <Wallet>[];
          if (_walletId != null &&
              wallets.every((w) => w.id != _walletId)) {
            _walletId = null;
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Name/Organization'),
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: _isBorrowing
                        ? 'Who do you borrow from?'
                        : 'Who owes you?',
                  ),
                ),
                const SizedBox(height: 20),
                _label('Amount'),
                AmountField(controller: _amountCtrl),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Date'),
                          _pickerButton(
                            label: formatDate(_date),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _date,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365 * 5)),
                              );
                              if (picked != null) {
                                setState(() => _date = picked);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Time'),
                          _pickerButton(
                            label:
                                '${_time.hour.toString().padLeft(2, '0')}.${_time.minute.toString().padLeft(2, '0')}',
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _time,
                              );
                              if (picked != null) {
                                setState(() => _time = picked);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _label('Color'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
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
                const SizedBox(height: 20),
                _label('Description'),
                TextField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    hintText: 'What was it for?',
                  ),
                ),
                const SizedBox(height: 20),
                _label('Due date (optional)'),
                const SizedBox(height: 8),
                _pickerButton(
                  label: _dueDate == null
                      ? 'No due date'
                      : formatDate(_dueDate!),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ??
                          DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) setState(() => _dueDate = picked);
                  },
                ),
                const SizedBox(height: 20),
                _label('Wallet'),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: _walletId,
                  decoration: const InputDecoration(
                      hintText: 'Select wallet'),
                  items: [
                    for (final w in wallets)
                      DropdownMenuItem<int?>(
                          value: w.id, child: Text(w.name)),
                  ],
                  onChanged: _noWallet
                      ? null
                      : (v) => setState(() => _walletId = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Don't use wallet"),
                  value: _noWallet,
                  onChanged: (v) => setState(() {
                    _noWallet = v;
                    if (v) _walletId = null;
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show in transaction history'),
                  subtitle: const Text(
                      'Record this debt as a transaction'),
                  value: _recordTx,
                  onChanged: (v) => setState(() => _recordTx = v),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      );

  Widget _pickerButton(
      {required String label, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.raised,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 15)),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, AppDatabase db) async {
    final name = _nameCtrl.text.trim();
    final amount = parseAmountInput(_amountCtrl.text);
    if (name.isEmpty) {
      _complain('Please enter a name');
      return;
    }
    if (amount <= 0) {
      _complain('Please enter an amount');
      return;
    }
    if (!_noWallet && _walletId == null) {
      _complain('Please select a wallet or enable "Don\'t use wallet"');
      return;
    }
    final walletId = _noWallet ? null : _walletId;
    final id = await db.createDebt(
      person: name,
      note: _descCtrl.text.trim(),
      amount: amount,
      direction: _direction,
      dueDate: _dueDate,
      walletId: walletId,
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
    if (context.mounted) Navigator.pop(context);
  }

  void _complain(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
