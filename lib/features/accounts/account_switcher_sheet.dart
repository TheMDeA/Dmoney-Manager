import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/form_sheet.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'move_wallets_sheet.dart';
import 'new_account_sheet.dart';

/// Account palette shared by the switcher and the new-account dialog.
const accountPalette = [
  '#C6FF4A',
  '#38BDF8',
  '#A78BFA',
  '#F472B6',
  '#FB923C',
  '#F87171',
  '#34D399',
  '#9CA3AF',
];

/// Bottom sheet opened from the home avatar: switch the global account
/// scope, create accounts, and manage them (rename / recolor / move
/// wallets / delete). `null` selection means "All accounts".
Future<void> showAccountSwitcherSheet(BuildContext context) {
  return showSnackSheet(context, (_) => const _AccountSwitcherSheet());
}

class _AccountSwitcherSheet extends ConsumerStatefulWidget {
  const _AccountSwitcherSheet();

  @override
  ConsumerState<_AccountSwitcherSheet> createState() =>
      _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends ConsumerState<_AccountSwitcherSheet> {
  // A Scaffold inside the sheet route: it registers with the root
  // ScaffoldMessenger, so snackbars render on the front layer, above
  // the sheet — a bare nested ScaffoldMessenger has no Scaffold to
  // present through and would swallow them silently.
  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final selectedId = ref.watch(selectedAccountProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _grabber(context),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Accounts',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: StreamBuilder<List<Account>>(
                stream: db.watchAccounts(),
                builder: (context, accSnap) {
                  final accounts = accSnap.data ?? const <Account>[];
                  // Guard: the persisted selection may point at a deleted
                  // account (e.g. after a restore). Fall back to All.
                  if (selectedId != null &&
                      accounts.isNotEmpty &&
                      accounts.every((a) => a.id != selectedId)) {
                    Future.microtask(
                      () => ref
                          .read(selectedAccountProvider.notifier)
                          .select(null),
                    );
                  }
                  return StreamBuilder<List<Wallet>>(
                    stream: db.watchWallets(),
                    builder: (context, walSnap) {
                      final wallets = walSnap.data ?? const <Wallet>[];
                      final byAccount = <int, List<Wallet>>{};
                      for (final w in wallets) {
                        byAccount.putIfAbsent(w.accountId, () => []).add(w);
                      }
                      final totalBalance = wallets.fold<int>(
                        0,
                        (s, w) => s + w.balance,
                      );
                      return ListView(
                        shrinkWrap: true,
                        children: [
                          _row(
                            context,
                            leading: _dot(context, context.accent),
                            title: 'All accounts',
                            subtitle:
                                '${wallets.length} wallet${wallets.length == 1 ? '' : 's'}',
                            trailing: formatMoney(totalBalance),
                            selected: selectedId == null,
                            onTap: () => _select(null),
                          ),
                          const Divider(),
                          for (final a in accounts)
                            _row(
                              context,
                              leading: _dot(context, colorFromHex(a.colorHex)),
                              title: a.name,
                              subtitle:
                                  '${(byAccount[a.id] ?? const <Wallet>[]).length} wallet${(byAccount[a.id] ?? const <Wallet>[]).length == 1 ? '' : 's'}',
                              trailing: formatMoney(
                                (byAccount[a.id] ?? const <Wallet>[]).fold<int>(
                                  0,
                                  (s, w) => s + w.balance,
                                ),
                              ),
                              selected: selectedId == a.id,
                              onTap: () => _select(a.id),
                              onLongPress: () => _manage(
                                a,
                                byAccount[a.id] ?? const <Wallet>[],
                                accounts,
                              ),
                            ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.add_circle_outline),
                            title: const Text('New account'),
                            subtitle: Text(
                              'Group wallets, e.g. Work',
                              style: TextStyle(
                                color: context.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () => _newAccount(accounts),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grabber(BuildContext context) => Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _dot(BuildContext context, Color color) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Icon(
      Icons.account_balance_wallet_outlined,
      size: 20,
      color: onAccent(color),
    ),
  );

  Widget _row(
    BuildContext context, {
    required Widget leading,
    required String title,
    required String subtitle,
    required String trailing,
    required bool selected,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return ListTile(
      leading: leading,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: context.textMuted, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(trailing, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (selected) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle, color: context.accent, size: 20),
          ],
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Future<void> _select(int? id) async {
    Haptics.select();
    await ref.read(selectedAccountProvider.notifier).select(id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _newAccount(List<Account> accounts) async {
    final result = await showFormSheet<NewAccountResult>(
      context,
      (_) => NewAccountSheet(palette: accountPalette),
    );
    if (result == null) return;
    await ref
        .read(databaseProvider)
        .addAccount(
          AccountsCompanion.insert(
            name: result.name,
            kind: 'personal',
            colorHex: Value(result.colorHex),
          ),
        );
    Haptics.medium();
    if (mounted) {
      _snack('Account "${result.name}" created');
    }
    // Stay on the current scope; the new account starts empty.
  }

  Future<void> _manage(
    Account account,
    List<Wallet> wallets,
    List<Account> accounts,
  ) {
    Haptics.light();
    return showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Text(
                account.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.of(context).pop();
                _rename(account);
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Change color'),
              onTap: () {
                Navigator.of(context).pop();
                _changeColor(account);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined),
              title: const Text('Move wallets…'),
              subtitle: Text(
                '${wallets.length} wallet${wallets.length == 1 ? '' : 's'} in this account',
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _moveWallets(account, wallets, accounts);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.expense),
              title: Text(
                'Delete account',
                style: TextStyle(color: AppColors.expense),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _delete(account, wallets, accounts);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(Account account) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          _NameDialog(title: 'Rename account', initial: account.name),
    );
    if (name == null || name == account.name) return;
    await ref.read(databaseProvider).renameAccount(account.id, name);
    Haptics.light();
  }

  Future<void> _changeColor(Account account) async {
    final hex = await showDialog<String>(
      context: context,
      builder: (_) =>
          _ColorDialog(title: 'Account color', initial: account.colorHex),
    );
    if (hex == null || hex == account.colorHex) return;
    await ref.read(databaseProvider).setAccountColor(account.id, hex);
    Haptics.light();
  }

  Future<void> _moveWallets(
    Account account,
    List<Wallet> wallets,
    List<Account> accounts,
  ) async {
    if (wallets.isEmpty) {
      _snack('No wallets in this account yet');
      return;
    }
    final destinations = accounts.where((a) => a.id != account.id).toList();
    if (destinations.isEmpty) {
      _snack('Create another account first to move wallets');
      return;
    }
    final result = await showFormSheet<MoveWalletsResult>(
      context,
      (_) => MoveWalletsSheet(
        source: account,
        wallets: wallets,
        destinations: destinations,
      ),
    );
    if (result == null || result.walletIds.isEmpty) return;
    await ref
        .read(databaseProvider)
        .moveWalletsToAccount(result.walletIds, result.destinationId);
    Haptics.medium();
    if (mounted) {
      _snack(
        'Moved ${result.walletIds.length} wallet${result.walletIds.length == 1 ? '' : 's'}',
      );
    }
  }

  Future<void> _delete(
    Account account,
    List<Wallet> wallets,
    List<Account> accounts,
  ) async {
    if (accounts.length <= 1) {
      _snack("Can't delete the last account");
      return;
    }
    final destinations = accounts.where((a) => a.id != account.id).toList();
    final destinationId = await showDialog<int>(
      context: context,
      builder: (_) => _DeleteAccountDialog(
        account: account,
        walletCount: wallets.length,
        destinations: destinations,
      ),
    );
    if (destinationId == null) return;
    final db = ref.read(databaseProvider);
    await db.deleteAccount(account.id, destinationId);
    // Follow the wallets: if the deleted account was selected, scope to
    // where its wallets went.
    if (ref.read(selectedAccountProvider) == account.id) {
      await ref.read(selectedAccountProvider.notifier).select(destinationId);
    }
    Haptics.medium();
    if (mounted) {
      _snack('Deleted "${account.name}"');
    }
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Name'),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _ctrl.text.trim().isEmpty || _ctrl.text.trim() == widget.initial
              ? null
              : () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late var _hex = widget.initial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final hex in accountPalette)
            GestureDetector(
              onTap: () => setState(() => _hex = hex),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorFromHex(hex),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _hex == hex
                        ? context.textPrimary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: _hex == hex
                    ? Icon(
                        Icons.check,
                        size: 20,
                        color: onAccent(colorFromHex(hex)),
                      )
                    : null,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_hex),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({
    required this.account,
    required this.walletCount,
    required this.destinations,
  });

  final Account account;
  final int walletCount;
  final List<Account> destinations;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  late int _destinationId = widget.destinations.first.id;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Delete "${widget.account.name}"?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.walletCount == 0
                ? 'This account has no wallets.'
                : '${widget.walletCount} wallet${widget.walletCount == 1 ? '' : 's'} will be moved — never deleted.',
          ),
          if (widget.walletCount > 0) ...[
            const SizedBox(height: 12),
            const Text('Move wallets to'),
            DropdownButton<int>(
              value: _destinationId,
              isExpanded: true,
              items: [
                for (final a in widget.destinations)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) =>
                  setState(() => _destinationId = v ?? _destinationId),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
          onPressed: () => Navigator.of(context).pop(_destinationId),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
