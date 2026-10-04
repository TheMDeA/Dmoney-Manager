import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/form_sheet.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// Shows the standardized Add/Edit wallet bottom sheet. Returns true when
/// the wallet was saved.
Future<bool> showWalletFormSheet(
  BuildContext context,
  WidgetRef ref, {
  Wallet? existing,
}) async {
  final saved = await showFormSheet<bool>(
    context,
    (context) => _WalletFormSheet(existing: existing),
  );
  return saved == true;
}

const _walletKinds = ['cash', 'bank', 'ewallet', 'credit'];

String _kindLabel(String kind) => switch (kind) {
      'cash' => 'Cash',
      'bank' => 'Bank account',
      'ewallet' => 'E-wallet',
      'credit' => 'Credit card',
      _ => kind,
    };

class _WalletFormSheet extends ConsumerStatefulWidget {
  const _WalletFormSheet({this.existing});

  final Wallet? existing;

  @override
  ConsumerState<_WalletFormSheet> createState() => _WalletFormSheetState();
}

class _WalletFormSheetState extends ConsumerState<_WalletFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _initialCtrl;
  late String _kind;
  late String _colorHex;
  int? _accountId;
  List<Account> _accounts = const [];
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _initialCtrl = TextEditingController();
    _kind = e?.kind ?? 'cash';
    _colorHex = e?.colorHex ?? '#C6FF4A';
    if (e != null) _accountId = e.accountId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _initialCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a wallet name')),
      );
      return;
    }
    final accountId = _accountId;
    if (!_editing && accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an account for this wallet')),
      );
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    try {
      if (_editing) {
        await db.updateWallet(
          id: widget.existing!.id,
          name: name,
          kind: _kind,
          colorHex: _colorHex,
        );
      } else {
        await db.createWallet(
          accountId: accountId!,
          name: name,
          kind: _kind,
          initialAmount: parseAmountInput(_initialCtrl.text),
          colorHex: _colorHex,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<Account>>(
      stream: db.watchAccounts(),
      builder: (context, snap) {
        _accounts = snap.data ?? const <Account>[];
        if (!_editing &&
            (_accountId == null ||
                _accounts.every((a) => a.id != _accountId))) {
          // New wallets default to the active account scope when it
          // still exists.
          final scoped = ref.watch(selectedAccountProvider);
          _accountId = scoped != null &&
                  _accounts.any((a) => a.id == scoped)
              ? scoped
              : (_accounts.isNotEmpty ? _accounts.first.id : null);
        }
        return FormSheet(
          title: _editing ? 'Edit wallet' : 'Add wallet',
          actionLabel: _editing ? 'Save changes' : 'Add wallet',
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
            const FormSectionLabel('Type'),
            FormChoiceChips<String>(
              options: _walletKinds,
              selected: _kind,
              labelFor: _kindLabel,
              onSelected: (v) => setState(() => _kind = v),
            ),
            if (!_editing) ...[
              const SizedBox(height: 16),
              const FormSectionLabel('Account'),
              if (_accounts.isEmpty)
                Text('No accounts yet.',
                    style:
                        TextStyle(color: context.textMuted, fontSize: 13))
              else
                FormChoiceChips<Account>(
                  options: _accounts,
                  selected: _accounts.firstWhere(
                    (a) => a.id == _accountId,
                    orElse: () => _accounts.first,
                  ),
                  labelFor: (a) => a.name,
                  onSelected: (a) =>
                      setState(() => _accountId = a.id),
                ),
              const SizedBox(height: 16),
              const FormSectionLabel('Initial amount (optional)'),
              FormAmountEntry(controller: _initialCtrl),
            ],
            const SizedBox(height: 16),
            const FormSectionLabel('Color'),
            ColorDots(
              selected: _colorHex,
              onSelected: (hex) => setState(() => _colorHex = hex),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}
