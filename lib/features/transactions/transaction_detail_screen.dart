import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'add_transaction_sheet.dart';

/// Record detail screen with duplicate / edit / delete actions
/// and attachable receipt photos ("Save Photos").
class TransactionDetailScreen extends ConsumerStatefulWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final int transactionId;

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  late Future<TransactionWithDetails?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load(ref.read(databaseProvider));
  }

  void _refresh() =>
      setState(() => _future = _load(ref.read(databaseProvider)));

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record'),
        actions: [
          IconButton(
            tooltip: 'Duplicate',
            onPressed: () => _duplicate(context, ref),
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: () async {
              final d = await _future;
              if (!context.mounted || d == null) return;
              if (d.transaction.kind == 'transfer') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Transfers can\'t be edited — delete and create a new one')),
                );
                return;
              }
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => AddTransactionSheet(existing: d),
              );
              _refresh();
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _delete(context, ref),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: FutureBuilder<TransactionWithDetails?>(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          if (d == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final t = d.transaction;
          final c = d.category;
          final isIncome = t.kind == 'income';
          final isTransfer = t.kind == 'transfer';
          final color = colorFromHex(c.colorHex);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(iconForKey(c.iconKey), color: color, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        t.note.isEmpty ? c.name : t.note,
                        style: AppTextStyles.displaySection,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _row(context, 'Category', c.name),
                _row(
                  context,
                  'Amount',
                  isTransfer
                      ? formatMoney(t.amount)
                      : formatSignedMoney(t.amount, isIncome: isIncome),
                  valueColor: isTransfer
                      ? null
                      : (isIncome ? AppColors.income : AppColors.expense),
                ),
                _row(context, 'Date', formatDateTime(t.date)),
                if (isTransfer)
                  _transferWalletRow(context, db, t)
                else
                  _row(context, 'Wallet', d.wallet.name),
                _row(context, 'Type',
                    isTransfer ? 'Transfer' : (isIncome ? 'Income' : 'Expense')),
                if (t.note.isNotEmpty) _row(context, 'Note', t.note),
                const SizedBox(height: 24),
                Text('Receipt photos',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _photoStrip(context, ref, db),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<TransactionWithDetails?> _load(AppDatabase db) async {
    final all = await db.getTransactionsInRange(
      DateTime(2000),
      DateTime(2100),
    );
    try {
      return all.firstWhere((d) => d.transaction.id == widget.transactionId);
    } catch (_) {
      return null;
    }
  }

  Widget _transferWalletRow(
      BuildContext context, AppDatabase db, Transaction t) {
    if (t.toWalletId == null) return _row(context, 'Wallet', '');
    return FutureBuilder<Wallet?>(
      future: db.getWalletById(t.toWalletId!),
      builder: (context, snap) {
        final to = snap.data?.name ?? '…';
        return FutureBuilder<Wallet?>(
          future: db.getWalletById(t.walletId),
          builder: (context, fromSnap) {
            final from = fromSnap.data?.name ?? '…';
            return _row(context, 'Wallet', '$from → $to');
          },
        );
      },
    );
  }

  Widget _row(BuildContext context, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55))),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.amount(size: 16).copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoStrip(BuildContext context, WidgetRef ref, AppDatabase db) {
    return SizedBox(
      height: 120,
      child: StreamBuilder<List<TransactionPhoto>>(
        stream: db.watchPhotos(widget.transactionId),
        builder: (context, snap) {
          final photos = snap.data ?? const <TransactionPhoto>[];
          return ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final p in photos)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(File(p.path),
                        width: 120, height: 120, fit: BoxFit.cover),
                  ),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _addPhoto(ref),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(Icons.add_a_photo_outlined),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addPhoto(WidgetRef ref) async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      await ref.read(databaseProvider).addPhoto(widget.transactionId, picked.path);
    }
  }

  Future<void> _duplicate(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final all = await db.getTransactionsInRange(DateTime(2000), DateTime(2100));
    final d = all.firstWhere((e) => e.transaction.id == widget.transactionId);
    final t = d.transaction;
    if (t.kind == 'transfer' && t.toWalletId != null) {
      await db.addTransfer(
        fromWalletId: t.walletId,
        toWalletId: t.toWalletId!,
        amount: t.amount,
        note: t.note,
      );
    } else {
      await db.addTransaction(TransactionsCompanion.insert(
        walletId: t.walletId,
        categoryId: t.categoryId,
        kind: t.kind,
        amount: t.amount,
        note: Value(t.note),
        date: DateTime.now(),
      ));
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Record duplicated')));
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete record?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(databaseProvider).deleteTransaction(widget.transactionId);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
