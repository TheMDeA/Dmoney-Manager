import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../transactions/add_transaction_sheet.dart';
import '../transactions/transaction_detail_screen.dart';

/// Detail view for one wallet: balance, adjust-balance, per-kind stats,
/// and its transactions grouped by category.
class WalletDetailScreen extends ConsumerStatefulWidget {
  const WalletDetailScreen({super.key, required this.walletId});

  final int walletId;

  @override
  ConsumerState<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends ConsumerState<WalletDetailScreen> {
  late int _walletId;

  @override
  void initState() {
    super.initState();
    _walletId = widget.walletId;
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Edit wallet',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editWallet(context, db),
          ),
          IconButton(
            tooltip: 'Delete wallet',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, db),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) =>
              AddTransactionSheet(initialWalletId: _walletId),
        ),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Wallet>>(
        stream: db.watchWallets(),
        builder: (context, wSnap) {
          final wallets = wSnap.data ?? const <Wallet>[];
          Wallet? wallet;
          for (final w in wallets) {
            if (w.id == _walletId) wallet = w;
          }
          if (wallet == null) {
            return const Center(
              child: Text('Wallet not found',
                  style: TextStyle(color: AppColors.textMuted)),
            );
          }
          final w = wallet;
          return StreamBuilder<List<TransactionWithDetails>>(
            stream: db.watchTransactions(),
            builder: (context, txSnap) {
              final txs = (txSnap.data ?? const <TransactionWithDetails>[])
                  .where((d) =>
                      d.transaction.walletId == w.id ||
                      d.transaction.toWalletId == w.id)
                  .toList();
              return _content(context, db, w, wallets, txs);
            },
          );
        },
      ),
    );
  }

  Widget _content(
    BuildContext context,
    AppDatabase db,
    Wallet wallet,
    List<Wallet> allWallets,
    List<TransactionWithDetails> txs,
  ) {
    final color = colorFromHex(wallet.colorHex);
    final negative = wallet.balance < 0;
    final income = txs.where((d) => d.transaction.kind == 'income').toList();
    final expense = txs.where((d) => d.transaction.kind == 'expense').toList();
    final transfer =
        txs.where((d) => d.transaction.kind == 'transfer').toList();

    // Group expense/income by category like the reference.
    final groups = <int, List<TransactionWithDetails>>{};
    for (final d in txs) {
      if (d.transaction.kind == 'transfer') continue;
      groups.putIfAbsent(d.transaction.categoryId, () => []).add(d);
    }
    final grouped = groups.entries.toList()
      ..sort((a, b) => _groupTotal(b.value).compareTo(_groupTotal(a.value)));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(iconForKey(_walletIconKey(wallet.kind)),
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _switchWallet(context, allWallets),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    wallet.name,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down,
                      color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(wallet.balance),
            style: AppTextStyles.displayBalance.copyWith(
              fontSize: 28,
              color: negative ? AppColors.expense : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _adjustBalance(context, db, wallet),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
              ),
              child: const Text('ADJUST BALANCE',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(height: 20),
          _statRow('Initial Amount', formatMoney(wallet.initialAmount), null,
              null),
          _statRow(
              'Income',
              '${income.length} transaction${income.length == 1 ? '' : 's'}',
              AppColors.brandBlue,
              () => _openTransactions(context, wallet, 'income')),
          _statRow(
              'Expense',
              '${expense.length} transaction${expense.length == 1 ? '' : 's'}',
              AppColors.expense,
              () => _openTransactions(context, wallet, 'expense')),
          _statRow(
              'Transfer',
              '${transfer.length} transaction${transfer.length == 1 ? '' : 's'}',
              null,
              () => _openTransactions(context, wallet, 'transfer')),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaction list',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => _openTransactions(context, wallet, null),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (grouped.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No transactions yet',
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 15)),
            )
          else
            for (final e in grouped.take(8)) _groupRow(context, e.value),
        ],
      ),
    );
  }

  int _groupTotal(List<TransactionWithDetails> ds) =>
      ds.fold<int>(0, (s, d) => s + d.transaction.amount);

  Widget _statRow(
      String label, String value, Color? valueColor, VoidCallback? onTap) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 15)),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: row,
    );
  }

  Widget _groupRow(BuildContext context, List<TransactionWithDetails> ds) {
    final d = ds.first;
    final catColor = colorFromHex(d.category.colorHex);
    final total = _groupTotal(ds);
    final isIncome = d.transaction.kind == 'income';
    return InkWell(
      onTap: () => _openTransactions(context, null, d.transaction.kind,
          categoryId: d.transaction.categoryId, walletId: d.transaction.walletId),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(23),
              ),
              child: Icon(iconForKey(d.category.iconKey),
                  color: catColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.category.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${ds.length} transaction${ds.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              formatSignedMoney(total, isIncome: isIncome),
              style: AppTextStyles.amount(size: 15).copyWith(
                  color: isIncome ? AppColors.income : AppColors.expense),
            ),
          ],
        ),
      ),
    );
  }

  void _openTransactions(
      BuildContext context, Wallet? wallet, String? kind,
      {int? categoryId, int? walletId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WalletTransactionsScreen(
          walletId: walletId ?? wallet?.id ?? _walletId,
          walletName: wallet?.name ?? '',
          initialKind: kind,
          categoryId: categoryId,
        ),
      ),
    );
  }

  Future<void> _switchWallet(
      BuildContext context, List<Wallet> wallets) async {
    if (wallets.length < 2) return;
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Switch wallet',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            for (final w in wallets)
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorFromHex(w.colorHex).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                      iconForKey(_walletIconKey(w.kind)),
                      color: colorFromHex(w.colorHex),
                      size: 20),
                ),
                title: Text(w.name),
                trailing: Text(formatMoney(w.balance),
                    style: AppTextStyles.amount(size: 14)),
                selected: w.id == _walletId,
                onTap: () => Navigator.pop(context, w.id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && picked != _walletId) {
      setState(() => _walletId = picked);
    }
  }

  Future<void> _adjustBalance(
      BuildContext context, AppDatabase db, Wallet wallet) async {
    final ctrl =
        TextEditingController(text: formatAmountInput(wallet.balance.abs()));
    final negative = wallet.balance < 0;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current: ${formatMoney(wallet.balance)}',
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: InputDecoration(
                  labelText: 'New balance (${currentCurrency.code})',
                  prefixText: negative ? '- ' : ''),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sets the balance directly. No transaction is created.',
              style:
                  TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved == true && context.mounted) {
      var amount = parseAmountInput(ctrl.text);
      if (negative) amount = -amount;
      await db.setWalletBalance(wallet.id, amount);
    }
  }

  Future<void> _editWallet(BuildContext context, AppDatabase db) async {
    final wallet = await db.getWalletById(_walletId);
    if (wallet == null || !context.mounted) return;
    final nameCtrl = TextEditingController(text: wallet.name);
    String kind = wallet.kind;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit wallet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(
                      value: 'bank', child: Text('Bank account')),
                  DropdownMenuItem(
                      value: 'ewallet', child: Text('E-wallet')),
                  DropdownMenuItem(
                      value: 'credit', child: Text('Credit card')),
                ],
                onChanged: (v) => setState(() => kind = v ?? 'cash'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved == true && nameCtrl.text.trim().isNotEmpty) {
      await db.updateWallet(
          id: wallet.id, name: nameCtrl.text.trim(), kind: kind);
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppDatabase db) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete wallet?'),
        content: const Text(
            'Wallets with transactions cannot be deleted. An empty wallet will be removed permanently.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.expense),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await db.deleteWallet(_walletId);
    if (!context.mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'This wallet has transactions and cannot be deleted.')),
      );
    }
  }

  String _walletIconKey(String kind) => switch (kind) {
        'bank' => 'account_balance',
        'ewallet' => 'smartphone',
        'credit' => 'credit_card',
        _ => 'wallet',
      };
}

/// Full transaction list for a wallet, with kind filter chips.
class WalletTransactionsScreen extends ConsumerStatefulWidget {
  const WalletTransactionsScreen({
    super.key,
    required this.walletId,
    required this.walletName,
    this.initialKind,
    this.categoryId,
  });

  final int walletId;
  final String walletName;
  final String? initialKind;
  final int? categoryId;

  @override
  ConsumerState<WalletTransactionsScreen> createState() =>
      _WalletTransactionsScreenState();
}

class _WalletTransactionsScreenState
    extends ConsumerState<WalletTransactionsScreen> {
  String? _kind;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.walletName.isEmpty
              ? 'Transactions'
              : '${widget.walletName} transactions')),
      body: StreamBuilder<List<TransactionWithDetails>>(
        stream: db.watchTransactions(),
        builder: (context, snap) {
          var txs = (snap.data ?? const <TransactionWithDetails>[]).where(
              (d) =>
                  d.transaction.walletId == widget.walletId ||
                  d.transaction.toWalletId == widget.walletId);
          if (_kind != null) {
            txs = txs.where((d) => d.transaction.kind == _kind);
          }
          if (widget.categoryId != null) {
            txs = txs.where(
                (d) => d.transaction.categoryId == widget.categoryId);
          }
          final list = txs.toList()
            ..sort((a, b) => b.transaction.date.compareTo(a.transaction.date));
          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _chip('All', null),
                    _chip('Income', 'income'),
                    _chip('Expense', 'expense'),
                    _chip('Transfer', 'transfer'),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(
                        child: Text('No transactions',
                            style: TextStyle(
                                color: AppColors.textMuted)),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final d = list[i];
                          final t = d.transaction;
                          final catColor =
                              colorFromHex(d.category.colorHex);
                          final isIncome = t.kind == 'income';
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 4),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(iconForKey(d.category.iconKey),
                                  color: catColor, size: 20),
                            ),
                            title: Text(
                                t.note.isEmpty ? d.category.name : t.note),
                            subtitle: Text(
                              '${formatDate(t.date)}${t.toWalletId != null ? ' · transfer' : ''}',
                              style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12),
                            ),
                            trailing: Text(
                              formatSignedMoney(t.amount,
                                  isIncome: isIncome),
                              style: AppTextStyles.amount(size: 14)
                                  .copyWith(
                                      color: isIncome
                                          ? AppColors.income
                                          : AppColors.expense),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TransactionDetailScreen(
                                    transactionId: t.id),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, String? kind) {
    final selected = _kind == kind;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _kind = kind),
      ),
    );
  }
}
