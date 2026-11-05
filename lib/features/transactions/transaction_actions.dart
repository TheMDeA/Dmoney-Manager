import 'package:flutter/material.dart';
import 'package:dmoney_manager/core/widgets/form_sheet.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
import '../../core/services/paylater_reminder_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'add_transaction_sheet.dart';

/// Shared edit/delete flows, used by the transaction tile (swipe actions)
/// and the transaction detail screen (app-bar buttons).

/// Opens the edit sheet for [details], honoring the transfer/debt
/// restrictions. Returns true when the sheet was opened.
Future<bool> editTransaction(
  BuildContext context,
  TransactionWithDetails details,
) async {
  final l10n = AppLocalizations.of(context)!;
  final t = details.transaction;
  if (t.kind == 'transfer') {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.txTransferEdit)));
    return false;
  }
  if (t.debtId != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.txDebtManaged)));
    return false;
  }
  await showSnackSheet(context, (_) => AddTransactionSheet(existing: details));
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
  final l10n = AppLocalizations.of(context)!;
  final db = ref.read(databaseProvider);
  final t = details.transaction;
  if (t.debtId != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.txDebtDeleteHere)));
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(l10n.txDeleteRecordTitle),
      content: Text(l10n.txUndoDeleteHint),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            Haptics.medium();
            Navigator.pop(context, true);
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
          child: Text(l10n.commonDelete),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  // Capture the messenger before [afterDelete] potentially pops this page.
  final messenger = ScaffoldMessenger.of(context);
  final photos = await db.watchPhotos(t.id).first;
  // A transfer's fee rows are deleted with it — snapshot them (and their
  // photos) so undo can bring them back too.
  final feeRows = t.kind == 'transfer'
      ? await db.transferFeeRows(t.id)
      : <Transaction>[];
  final feePhotos = <int, List<TransactionPhoto>>{
    for (final f in feeRows) f.id: await db.watchPhotos(f.id).first,
  };
  await db.deleteTransaction(t.id);
  // Deleting a record on a paylater wallet changes what it owes.
  await syncPaylaterReminder(db, t.walletId);
  if (t.toWalletId != null) await syncPaylaterReminder(db, t.toWalletId!);
  afterDelete?.call();
  // Don't let rapid deletes queue up a seemingly endless snackbar.
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.txRecordDeleted),
      duration: const Duration(seconds: 5),
      // Snackbars with an action persist until dismissed by default —
      // opt back into the intended 5-second undo window.
      persist: false,
      action: SnackBarAction(
        label: l10n.txUndo,
        onPressed: () async {
          Haptics.light();
          await db.restoreTransaction(t, photos);
          for (final f in feeRows) {
            await db.restoreTransaction(f, feePhotos[f.id] ?? const []);
          }
          await syncPaylaterReminder(db, t.walletId);
          if (t.toWalletId != null) {
            await syncPaylaterReminder(db, t.toWalletId!);
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
