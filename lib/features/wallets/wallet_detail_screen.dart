import 'package:flutter/material.dart';
import '../../core/widgets/app_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/month_scrubber.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'adjust_balance_sheet.dart';
import '../transactions/add_transaction_sheet.dart';
import '../transactions/widgets/grouped_transaction_list.dart';
import '../transactions/widgets/month_overview.dart';
import '../transactions/widgets/month_selector.dart';
import 'wallet_category_screen.dart';
import 'wallet_form_sheet.dart';

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
            onPressed: () {
              Haptics.select();
              _editWallet(context, db);
            },
          ),
          IconButton(
            tooltip: 'Delete wallet',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              Haptics.select();
              _confirmDelete(context, db);
            },
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
          if (!wSnap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 180, height: 22),
                  SizedBox(height: 12),
                  SkeletonBox(height: 90, radius: 20),
                  SizedBox(height: 12),
                  SkeletonBox(width: 120, height: 16),
                ],
              ),
            );
          }
          final wallets = wSnap.data ?? const <Wallet>[];
          Wallet? wallet;
          for (final w in wallets) {
            if (w.id == _walletId) wallet = w;
          }
          if (wallet == null) {
            return Center(
              child: Text('Wallet not found',
                  style: TextStyle(color: context.textMuted)),
            );
          }
          final w = wallet;
          return StreamBuilder<List<TransactionWithDetails>>(
            stream: db.watchTransactionsForWallet(w.id),
            builder: (context, txSnap) {
              final txs = txSnap.data ?? const <TransactionWithDetails>[];
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
          Hero(
            tag: 'wallet-${wallet.id}',
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(iconForKey(_walletIconKey(wallet.kind)),
                  color: onAccent(color), size: 36),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Haptics.select();
              _switchWallet(context, allWallets);
            },
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
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down,
                      color: context.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(wallet.balance),
            style: AppTextStyles.displayBalance.copyWith(
              fontSize: 28,
              color: negative ? AppColors.expense : context.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Haptics.select();
                AdjustBalanceSheet.show(context, wallet);
              },
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
                  color: context.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  Haptics.select();
                  _openTransactions(context, wallet, null);
                },
                child: Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (grouped.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No transactions yet',
                  style:
                      TextStyle(color: context.textMuted, fontSize: 15)),
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
                  TextStyle(color: context.textMuted, fontSize: 15)),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? context.textPrimary,
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
      onTap: () {
        Haptics.select();
        Navigator.push(
          context,
          AppPageRoute(
            builder: (_) => WalletCategoryScreen(
            walletId: d.transaction.walletId,
            categoryId: d.transaction.categoryId,
            categoryName: d.category.name,
            iconKey: d.category.iconKey,
            colorHex: d.category.colorHex,
          ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Hero(
              tag:
                  'walletcat-${d.transaction.walletId}-${d.transaction.categoryId}',
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(23),
                ),
                child: Icon(iconForKey(d.category.iconKey),
                    color: catColor, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.category.name,
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${ds.length} transaction${ds.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        color: context.textMuted, fontSize: 12),
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
      AppPageRoute(
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
                onTap: () {
                  Haptics.select();
                  Navigator.pop(context, w.id);
                },
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

  Future<void> _editWallet(BuildContext context, AppDatabase db) async {
    final wallet = await db.getWalletById(_walletId);
    if (wallet == null || !context.mounted) return;
    await showWalletFormSheet(context, ref, existing: wallet);
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
            onPressed: () {
              Haptics.medium();
              Navigator.pop(context, true);
            },
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
  late DateTime _month =
      DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
  }

  void _shift(int delta) => setState(() {
        _month = DateTime(_month.year, _month.month + delta);
      });

  Future<void> _pickMonth() async {
    final picked = await showMonthYearPicker(context, _month);
    if (picked != null) setState(() => _month = picked);
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final start = DateTime(_month.year, _month.month);
    final end = DateTime(_month.year, _month.month + 1)
        .subtract(const Duration(seconds: 1));
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.walletName.isEmpty
              ? 'Transactions'
              : '${widget.walletName} transactions')),
      body: StreamBuilder<List<TransactionWithDetails>>(
        stream: db.watchTransactionsForWalletInRange(
            widget.walletId, start, end),
        builder: (context, snap) {
          final items = snap.data ?? const <TransactionWithDetails>[];
          var income = 0;
          var expense = 0;
          for (final d in items) {
            final t = d.transaction;
            if (t.kind == 'income') {
              income += t.amount;
            } else if (t.kind == 'expense') {
              expense += t.amount;
            }
          }
          var list = items;
          if (_kind != null) {
            list = list.where((d) => d.transaction.kind == _kind).toList();
          }
          if (widget.categoryId != null) {
            list = list
                .where((d) => d.transaction.categoryId == widget.categoryId)
                .toList();
          }
          return Column(
            children: [
              MonthSelector(
                month: _month,
                onShift: _shift,
                onPick: _pickMonth,
              ),
              MonthOverview(income: income, expense: expense),
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
                child: !snap.hasData
                    ? const SkeletonTransactionList()
                    : list.isEmpty
                        ? const EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'No transactions',
                            message:
                                'Nothing recorded in this wallet this month.',
                          )
                        : MonthScrubber(
                            month: _month,
                            onShift: _shift,
                            child: GroupedTransactionList(items: list),
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
