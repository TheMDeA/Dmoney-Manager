import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/haptics.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'add_transaction_sheet.dart';

/// Shared edit/delete flows, used by the transaction tile (swipe actions)
/// and the transaction detail screen (app-bar buttons).

/// Opens the edit sheet for [details], honoring the transfer/debt
/// restrictions. Returns true when the sheet was opened.
Future<bool> editTransaction(
    BuildContext context, TransactionWithDetails details) async {
  final t = details.transaction;
  if (t.kind == 'transfer') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Transfers can\'t be edited — delete and create a new one')),
    );
    return false;
  }
  if (t.debtId != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Debt entries are managed from the debt itself')),
    );
    return false;
  }
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => AddTransactionSheet(existing: details),
  );
  return true;
}

/// Confirms, deletes, and offers the 5-second undo snackbar.
/// [afterDelete] runs right after a successful delete (e.g. popping a
/// detail page that was showing the deleted record).
Future<void> deleteTransactionFlow(
  BuildContext context,
  WidgetRef ref,
  TransactionWithDetails details, {
  VoidCallback? afterDelete,
}) async {
  final db = ref.read(databaseProvider);
  final t = details.transaction;
  if (t.debtId != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Debt entries can\'t be deleted here — delete the debt itself')),
    );
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete record?'),
      content: const Text('You can undo this right after deleting.'),
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
  if (confirmed != true || !context.mounted) return;
  Haptics.medium();
  // Capture the messenger before [afterDelete] potentially pops this page.
  final messenger = ScaffoldMessenger.of(context);
  final photos = await db.watchPhotos(t.id).first;
  await db.deleteTransaction(t.id);
  afterDelete?.call();
  // Don't let rapid deletes queue up a seemingly endless snackbar.
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Record deleted'),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          Haptics.light();
          await db.restoreTransaction(t, photos);
          messenger.clearSnackBars();
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Record restored'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    ),
  );
}
