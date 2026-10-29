import 'package:flutter/material.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_page_route.dart';
import '../../core/widgets/date_scrubber.dart';
import '../../core/widgets/coin_refresh_indicator.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/sliding_segmented.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/utils/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../categories/select_category_screen.dart';
import 'add_transaction_sheet.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'widgets/grouped_transaction_list.dart';
import 'widgets/month_overview.dart';
import 'widgets/month_selector.dart';

/// Transaction history: a Month / All view toggle, income/expense overview,
/// and transactions grouped by date with daily totals.
///
/// The fast date scrubber only appears in the All view — in the Month view
/// the month pager already handles navigation.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key, this.initialMonth});

  /// Month the pager opens on. Defaults to the current month.
  final DateTime? initialMonth;

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late DateTime _month = widget.initialMonth ??
      DateTime(DateTime.now().year, DateTime.now().month);
  var _view = 'month'; // 'month' | 'all'
  final _scrollController = ScrollController();

  /// Bulk selection: ids of selected transactions. Non-empty = selection
  /// mode (checkbox rows, tap toggles, swipes off). Entered via long-press.
  final Set<int> _selected = {};

  /// Latest items from the stream, so bulk actions can resolve ids.
  List<TransactionWithDetails> _latestItems = const [];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _shift(int delta) => setState(() {
        _month = DateTime(_month.year, _month.month + delta);
      });

  Future<void> _pickMonth() async {
    final picked = await showMonthYearPicker(context, _month);
    if (picked != null) setState(() => _month = picked);
  }

  void _setView(String view) {
    if (view == _view) return;
    Haptics.select();
    setState(() {
      _view = view;
      _selected.clear();
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _toggleSelect(int id) {
    Haptics.select();
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _clearSelection() => setState(() => _selected.clear());

  void _selectAll() {
    Haptics.select();
    setState(() =>
        _selected.addAll(_latestItems.map((d) => d.transaction.id)));
  }

  List<TransactionWithDetails> get _targets => _latestItems
      .where((d) => _selected.contains(d.transaction.id))
      .toList();

  /// Bulk delete with a single undo that restores everything.
  /// Debt-linked entries can't be deleted here — they're skipped.
  Future<void> _bulkDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);
    final targets = _targets;
    final deletable =
        targets.where((d) => d.transaction.debtId == null).toList();
    final skipped = targets.length - deletable.length;
    if (deletable.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.txDebtDeleteHere)),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.txDeleteRecordsTitle(deletable.length)),
        content: Text(l10n.txUndoDeleteHint),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              Haptics.medium();
              Navigator.pop(context, true);
            },
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.expense),
            child: Text(l10n.commonDelete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    // Snapshot everything first so undo can restore it all.
    final backup = <({Transaction t, List<TransactionPhoto> photos})>[];
    for (final d in deletable) {
      backup.add((
        t: d.transaction,
        photos: await db.watchPhotos(d.transaction.id).first,
      ));
      // Transfers take their fee rows with them on delete; snapshot
      // those too (right after the transfer, so undo restores the
      // transfer before the rows that reference it).
      if (d.transaction.kind == 'transfer') {
        for (final f in await db.transferFeeRows(d.transaction.id)) {
          backup.add((
            t: f,
            photos: await db.watchPhotos(f.id).first,
          ));
        }
      }
    }
    for (final b in backup) {
      await db.deleteTransaction(b.t.id);
    }
    _clearSelection();
    // Don't let rapid deletes queue up a seemingly endless snackbar.
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(skipped > 0
            ? l10n.txDeletedWithSkipped(deletable.length, skipped)
            : l10n.txRecordsDeleted(deletable.length)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: l10n.txUndo,
          onPressed: () async {
            Haptics.light();
            for (final b in backup) {
              await db.restoreTransaction(b.t, b.photos);
            }
            messenger.clearSnackBars();
            messenger.showSnackBar(
              SnackBar(
                content: Text(l10n.txRecordsRestored),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Moves every selected record to one picked category. Only offered for
  /// a uniform selection (all income or all expense, no transfers/debt).
  Future<void> _bulkRecategorize() async {
    final l10n = AppLocalizations.of(context)!;
    final targets = _targets;
    final kinds = {for (final d in targets) d.transaction.kind};
    final uniform = targets.isNotEmpty &&
        kinds.length == 1 &&
        (kinds.first == 'income' || kinds.first == 'expense') &&
        targets.every((d) => d.transaction.debtId == null);
    if (!uniform) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.txSelectOneType)),
      );
      return;
    }
    final picked = await Navigator.of(context).push<Category>(
      AppPageRoute(
        builder: (_) => SelectCategoryScreen(
          initialKind: kinds.first,
          lockKind: true,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final db = ref.read(databaseProvider);
    Haptics.medium();
    for (final d in targets) {
      final t = d.transaction;
      await db.updateTransaction(
        id: t.id,
        walletId: t.walletId,
        categoryId: picked.id,
        kind: t.kind,
        amount: t.amount,
        note: t.note,
        memo: t.memo,
        date: t.date,
      );
    }
    final count = targets.length;
    _clearSelection();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      // gen-l10n orders params alphabetically: category, count.
      SnackBar(content: Text(l10n.txRecordsMoved(picked.name, count))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(databaseProvider);
    final accountId = ref.watch(selectedAccountProvider);
    final all = _view == 'all';
    final start = DateTime(_month.year, _month.month);
    final end = DateTime(_month.year, _month.month + 1)
        .subtract(const Duration(seconds: 1));
    final selecting = _selected.isNotEmpty;
    // Back exits selection mode first; the route only pops when idle.
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selected.isNotEmpty) _clearSelection();
      },
      child: Scaffold(
      appBar: selecting
          ? AppBar(
              leading: IconButton(
                tooltip: l10n.txClearSelection,
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              ),
              title: Text(l10n.txSelected(_selected.length)),              actions: [
                IconButton(
                  tooltip: l10n.txSelectAll,
                  icon: const Icon(Icons.select_all),
                  onPressed: _selectAll,
                ),
                IconButton(
                  tooltip: l10n.commonDelete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _bulkDelete,
                ),
                IconButton(
                  tooltip: l10n.txChangeCategory,
                  icon: const Icon(Icons.category_outlined),
                  onPressed: _bulkRecategorize,
                ),
              ],
            )
          : AppBar(
        title: Text(l10n.txTransactions),
        actions: [
          if (!all)
            IconButton(
              tooltip: l10n.txPickMonth,
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: _pickMonth,
            ),
        ],
      ),
      body: StreamBuilder<List<TransactionWithDetails>>(
        stream: all
            ? db.watchTransactions(accountId: accountId)
            : db.watchTransactionsInRange(start, end,
                accountId: accountId),
        builder: (context, snap) {
          final items = snap.data ?? const <TransactionWithDetails>[];
          _latestItems = items;
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
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Center(
                  child: SlidingSegmented<String>(
                    values: const ['month', 'all'],
                    labels: [l10n.txMonth, l10n.commonAll],
                    selected: _view,
                    onChanged: _setView,
                  ),
                ),
              ),
              if (!all)
                MonthSelector(
                  month: _month,
                  onShift: _shift,
                  onPick: _pickMonth,
                ),
              MonthOverview(income: income, expense: expense),
              Expanded(
                child: !snap.hasData
                    ? const SkeletonTransactionList()
                    : items.isEmpty
                        ? EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: l10n.txNoTransactions,
                            message: all
                                ? l10n.txNothingYet
                                : l10n.txNothingThisMonth,
                            actionLabel: l10n.txAddTransaction,
                            onAction: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) =>
                                  const AddTransactionSheet(),
                            ),
                          )
                        : CoinRefreshIndicator(
                            onRefresh: () async {
                              Haptics.light();
                              // Local-first data: the streams are already live.
                              // The gesture still gets its satisfying snap.
                              await Future.delayed(
                                  const Duration(milliseconds: 450));
                            },
                            child: all
                                ? DateScrubber(
                                    controller: _scrollController,
                                    itemDates: [
                                      for (final d in items)
                                        d.transaction.date,
                                    ],
                                    child: GroupedTransactionList(
                                      items: items,
                                      controller: _scrollController,
                                      selectedIds: _selected,
                                      onToggleSelected: _toggleSelect,
                                    ),
                                  )
                                : GroupedTransactionList(
                                    items: items,
                                    selectedIds: _selected,
                                    onToggleSelected: _toggleSelect,
                                  ),
                          ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}
