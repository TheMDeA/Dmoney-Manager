import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../core/widgets/app_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'photo_viewer_screen.dart';
import 'transaction_actions.dart';

/// Record detail screen with duplicate / edit / delete actions
/// and attachable receipt photos ("Save Photos").
///
/// [iconKey]/[colorHex]/[title] describe the header and are passed in so it
/// — including the hero icon shared with the transaction row — renders
/// synchronously without waiting for the record to load.
class TransactionDetailScreen extends ConsumerStatefulWidget {
  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
    required this.iconKey,
    required this.colorHex,
    required this.title,
  });

  final int transactionId;
  final String iconKey;
  final String colorHex;
  final String title;

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  late Future<TransactionWithDetails?> _future;
  late String _iconKey = widget.iconKey;
  late String _colorHex = widget.colorHex;
  late String _title = widget.title;

  @override
  void initState() {
    super.initState();
    _future = _load(ref.read(databaseProvider));
  }

  Future<void> _refresh() async {
    final d = await _load(ref.read(databaseProvider));
    if (!mounted) return;
    setState(() {
      _future = Future.value(d);
      // Keep the hoisted header in sync after edits.
      if (d != null) {
        _iconKey = d.category.iconKey;
        _colorHex = d.category.colorHex;
        _title = d.transaction.note.isEmpty
            ? d.category.name
            : d.transaction.note;
      }
    });
  }

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
              if (await editTransaction(context, d)) _refresh();
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () async {
              final d = await _future;
              if (!context.mounted || d == null) return;
              await deleteTransactionFlow(context, ref, d,
                  afterDelete: () => Navigator.of(context).pop());
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Synchronous header (hero icon + title) so the shared-element
          // transition has its destination on the first frame.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Hero(
                  tag: 'tx-icon-${widget.transactionId}',
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color:
                          colorFromHex(_colorHex).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(iconForKey(_iconKey),
                        color: colorFromHex(_colorHex), size: 30),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _title,
                    style: AppTextStyles.displaySection,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<TransactionWithDetails?>(
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
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (t.debtId != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.raised,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.handshake_outlined, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Linked to a debt — view or manage it from the debt detail.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                if (t.note.isNotEmpty)
                  _row(context, 'Description', t.note),
                if (t.memo.isNotEmpty) _row(context, 'Memo', t.memo),
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
          ),
        ],
      ),
    );
  }

  Future<TransactionWithDetails?> _load(AppDatabase db) =>
      db.getTransactionDetailById(widget.transactionId);

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
              for (var i = 0; i < photos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.push(
                      context,
                      AppPageRoute(
                        builder: (_) => PhotoViewerScreen(
                          transactionId: widget.transactionId,
                          initialIndex: i,
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(File(photos[i].path),
                          width: 120,
                          height: 120,
                          // Decode a downscaled copy: the source can be a
                          // multi-megapixel camera photo, far larger than
                          // this 120px thumbnail.
                          cacheWidth: 240,
                          cacheHeight: 240,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                                width: 120,
                                height: 120,
                                color: context.raised,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: context.textMuted,
                                ),
                              )),
                    ),
                  ),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _addPhoto(context, ref),
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

  Future<void> _addPhoto(BuildContext context, WidgetRef ref) async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) {
        await ref
            .read(databaseProvider)
            .addPhoto(widget.transactionId, picked.path);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add photo: $e')),
        );
      }
    }
  }

  Future<void> _duplicate(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final d = await db.getTransactionDetailById(widget.transactionId);
    if (d == null) return;
    final t = d.transaction;
    if (t.debtId != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Debt entries can\'t be duplicated — add a new debt')),
        );
      }
      return;
    }
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


}
