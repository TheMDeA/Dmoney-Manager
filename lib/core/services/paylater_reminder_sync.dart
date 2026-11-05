import '../../data/database/app_database.dart';
import '../utils/paylater.dart';
import 'app_prefs.dart';
import 'notification_service.dart';

/// Keeps a paylater wallet's due-date reminder in sync with what it
/// currently owes: reschedules it with the fresh amount and due date,
/// or cancels it when nothing is owed, no due day is set, reminders
/// are off, the wallet isn't paylater — or the wallet is gone, which
/// is also how deleting a wallet cancels its reminder.
///
/// Every flow that changes a paylater wallet's outstanding balance
/// (purchases, installment payments, plan add/edit/delete, transfers,
/// balance adjustments, wallet edits, restores) must call this for the
/// affected wallet; before this helper existed, only the wallet form
/// and the dashboard's Next-due card did, so reminders routinely
/// quoted stale amounts or fired for settled wallets.
Future<void> syncPaylaterReminder(AppDatabase db, int walletId) async {
  final wallet = await db.getWalletById(walletId);
  if (wallet != null &&
      wallet.kind == 'paylater' &&
      wallet.dueDay != null &&
      paylaterOutstanding(wallet) > 0 &&
      AppPrefs.paylaterReminders) {
    await NotificationService.schedulePaylaterReminder(
      walletId: wallet.id,
      walletName: wallet.name,
      amount: paylaterOutstanding(wallet),
      dueDate: walletNextDueDate(wallet, DateTime.now())!,
    );
  } else {
    await NotificationService.cancelPaylaterReminder(walletId);
  }
}
