import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

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
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _AccountSwitcherSheet(),
  );
}

class _AccountSwitcherSheet extends ConsumerStatefulWidget {
  const _AccountSwitcherSheet();

  @override
  ConsumerState<_AccountSwitcherSheet> createState() =>
      _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState
    extends ConsumerState<_AccountSwitcherSheet> {
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
              child: Text('Accounts',
                  style: Theme.of(context).textTheme.titleLarge),
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
                    Future.microtask(() => ref
                        .read(selectedAccountProvider.notifier)
                        .select(null));
                  }
                  return StreamBuilder<List<Wallet>>(
                    stream: db.watchWallets(),
                    builder: (context, walSnap) {
                      final wallets = walSnap.data ?? const <Wallet>[];
                      final byAccount = <int, List<Wallet>>{};
                      for (final w in wallets) {
                        byAccount.putIfAbsent(w.accountId, () => []).add(w);
                      }
                      final totalBalance =
                          wallets.fold<int>(0, (s, w) => s + w.balance);
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
                                      0, (s, w) => s + w.balance)),
                              selected: selectedId == a.id,
                              onTap: () => _select(a.id),
                              onLongPress: () => _manage(
                                  a,
                                  byAccount[a.id] ?? const <Wallet>[],
                                  accounts),
                            ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.add_circle_outline),
                            title: const Text('New account'),
                            subtitle: Text('Group wallets, e.g. Work',
                                style: TextStyle(
                                    color: context.textMuted, fontSize: 12)),
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
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _dot(BuildContext context, Color color) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(Icons.account_balance_wallet_outlined,
            size: 20, color: onAccent(color)),
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
      title: Text(title,
          style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      subtitle: Text(subtitle,
          style: TextStyle(color: context.textMuted, fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(trailing,
              style: const TextStyle(fontWeight: FontWeight.w600)),
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
    final result = await showDialog<_NewAccountResult>(
      context: context,
      builder: (_) => const _NewAccountDialog(),
    );
    if (result == null) return;
    await ref.read(databaseProvider).addAccount(
          AccountsCompanion.insert(
            name: result.name,
            kind: 'personal',
            colorHex: Value(result.colorHex),
          ),
        );
    Haptics.medium();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account "${result.name}" created')),
      );
    }
    // Stay on the current scope; the new account starts empty.
  }

  Future<void> _manage(
      Account account, List<Wallet> wallets, List<Account> accounts) {
    Haptics.light();
    return showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
                child: Text(account.name,
                    style: Theme.of(context).textTheme.titleMedium)),
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
                  style:
                      TextStyle(color: context.textMuted, fontSize: 12)),
              onTap: () {
                Navigator.of(context).pop();
                _moveWallets(account, wallets, accounts);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.expense),
              title: Text('Delete account',
                  style: TextStyle(color: AppColors.expense)),
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
      builder: (_) => _NameDialog(title: 'Rename account', initial: account.name),
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
      Account account, List<Wallet> wallets, List<Account> accounts) async {
    if (wallets.isEmpty) {
      // Pop the sheet first so the message isn't hidden behind it —
      // it would otherwise only surface on the home screen after the
      // sheet is dismissed.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('No wallets in this account yet')),
      );
      return;
    }
    final destinations = accounts.where((a) => a.id != account.id).toList();
    if (destinations.isEmpty) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Create another account first to move wallets')),
      );
      return;
    }
    final result = await showDialog<_MoveWalletsResult>(
      context: context,
      builder: (_) => _MoveWalletsDialog(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Moved ${result.walletIds.length} wallet${result.walletIds.length == 1 ? '' : 's'}')),
      );
    }
  }

  Future<void> _delete(
      Account account, List<Wallet> wallets, List<Account> accounts) async {
    if (accounts.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Can't delete the last account")),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "${account.name}"')),
      );
    }
  }
}

class _NewAccountResult {
  _NewAccountResult(this.name, this.colorHex);
  final String name;
  final String colorHex;
}

class _NewAccountDialog extends StatefulWidget {
  const _NewAccountDialog();

  @override
  State<_NewAccountDialog> createState() => _NewAccountDialogState();
}

class _NewAccountDialogState extends State<_NewAccountDialog> {
  final _ctrl = TextEditingController();
  var _colorHex = accountPalette.first;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Work',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          const Text('Color'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              for (final hex in accountPalette)
                GestureDetector(
                  onTap: () => setState(() => _colorHex = hex),
                  child: Container(
                    width: 36,
                    height: 36,
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
                            size: 18, color: onAccent(colorFromHex(hex)))
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _ctrl.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  _NewAccountResult(_ctrl.text.trim(), _colorHex)),
          child: const Text('Create'),
        ),
      ],
    );
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
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

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
          onPressed: _ctrl.text.trim().isEmpty ||
                  _ctrl.text.trim() == widget.initial
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
                    color: _hex == hex ? context.textPrimary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: _hex == hex
                    ? Icon(Icons.check,
                        size: 20, color: onAccent(colorFromHex(hex)))
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

class _MoveWalletsResult {
  _MoveWalletsResult(this.walletIds, this.destinationId);
  final List<int> walletIds;
  final int destinationId;
}

class _MoveWalletsDialog extends StatefulWidget {
  const _MoveWalletsDialog({
    required this.source,
    required this.wallets,
    required this.destinations,
  });

  final Account source;
  final List<Wallet> wallets;
  final List<Account> destinations;

  @override
  State<_MoveWalletsDialog> createState() => _MoveWalletsDialogState();
}

class _MoveWalletsDialogState extends State<_MoveWalletsDialog> {
  final _picked = <int>{};
  late int _destinationId = widget.destinations.first.id;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Move wallets from ${widget.source.name}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final w in widget.wallets)
                    CheckboxListTile(
                      value: _picked.contains(w.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _picked.add(w.id);
                        } else {
                          _picked.remove(w.id);
                        }
                      }),
                      title: Text(w.name),
                      subtitle: Text(formatMoney(w.balance),
                          style: TextStyle(
                              color: context.textMuted, fontSize: 12)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('Move to'),
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _picked.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  _MoveWalletsResult(_picked.toList(), _destinationId)),
          child: const Text('Move'),
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
