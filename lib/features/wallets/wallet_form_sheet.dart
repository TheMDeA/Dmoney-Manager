import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/form_sheet.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'wallet_brands.dart';
import 'widgets/wallet_badge.dart';

/// Shows the standardized Add/Edit wallet bottom sheet. Returns true when
/// the wallet was saved.
Future<bool> showWalletFormSheet(
  BuildContext context,
  WidgetRef ref, {
  Wallet? existing,
}) async {
  final saved = await showSnackSheet<bool>(
    context,
    (context) => _WalletFormSheet(existing: existing),
    borderRadius: 28,
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
  String? _logoTemplate;
  int? _accountId;
  List<Account> _accounts = const [];
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
    _initialCtrl = TextEditingController();
    _kind = e?.kind ?? 'cash';
    _colorHex = e?.colorHex ?? '#C6FF4A';
    _logoTemplate = e?.logoTemplate;
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
      _snack('Enter a wallet name');
      return;
    }
    final accountId = _accountId;
    if (!_editing && accountId == null) {
      _snack('Pick an account for this wallet');
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
          logoTemplate: _logoTemplate,
        );
      } else {
        await db.createWallet(
          accountId: accountId!,
          name: name,
          kind: _kind,
          initialAmount: parseAmountInput(_initialCtrl.text),
          colorHex: _colorHex,
          logoTemplate: _logoTemplate,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  /// A selectable brand badge. Picking a template also applies the
  /// brand's color, which can still be fine-tuned with the color dots.
  Widget _brandOption(WalletBrand brand) {
    final selected = _logoTemplate == brand.id;
    return GestureDetector(
      onTap: () => setState(() {
        _logoTemplate = brand.id;
        _colorHex = brand.colorHex;
      }),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? context.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: WalletBadge(brand: brand, height: 30),
      ),
    );
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
          _accountId = scoped != null && _accounts.any((a) => a.id == scoped)
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
                Text(
                  'No accounts yet.',
                  style: TextStyle(color: context.textMuted, fontSize: 13),
                )
              else
                FormChoiceChips<Account>(
                  options: _accounts,
                  selected: _accounts.firstWhere(
                    (a) => a.id == _accountId,
                    orElse: () => _accounts.first,
                  ),
                  labelFor: (a) => a.name,
                  onSelected: (a) => setState(() => _accountId = a.id),
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const FormSectionLabel('Logo'),
                if (_logoTemplate != null)
                  GestureDetector(
                    onTap: () => setState(() => _logoTemplate = null),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final group in walletBrandGroups.entries) ...[
              Text(
                group.key,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final brand in group.value)
                      _brandOption(brand),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}
