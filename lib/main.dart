import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/services/app_prefs.dart';
import 'core/services/notification_service.dart';
import 'core/services/paylater_reminder_sync.dart';
import 'core/services/supabase_auth_service.dart';
import 'core/services/sync_orchestrator.dart';
import 'core/services/sync_pull_service.dart';
import 'core/services/sync_triggers.dart';
import 'data/database/app_database.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPrefs.init();
  // Date symbols for every locale (needed by DateFormat with an explicit
  // locale, e.g. weekday names in the goal detail screen). Without this,
  // those calls throw LocaleDataException and the screen goes blank.
  await initializeDateFormatting();
  // Notifications must never prevent the app from starting.
  try {
    await NotificationService.init();
  } catch (_) {
    // Leave notifications disabled; the app runs fine without them.
  }
  // Supabase sync client (v3.0.0): init only — a failure here must
  // never affect startup. The auth getters are safe (null/false)
  // when init fails, and the sync remote is built lazily by the
  // orchestrator only once a cycle confirms a signed-in user.
  try {
    await SupabaseAuthService.init();
  } catch (e) {
    debugPrint('Supabase init failed: $e');
  }
  final db = AppDatabase();
  // The sync orchestrator (P5): one shared instance for the launch
  // sync, the triggers and the Settings screen, so single-flight and
  // status are shared. The remote is built lazily by the
  // orchestrator (only once a cycle confirms a signed-in user), so
  // a failed Supabase init never crashes startup here.
  final syncOrchestrator = SyncOrchestrator(db: db);
  final syncTriggers = SyncTriggerService(
    db: db,
    orchestrator: syncOrchestrator,
  );
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        syncOrchestratorProvider.overrideWithValue(syncOrchestrator),
      ],
      child: const MoneyManagerApp(),
    ),
  );
  // Post-frame launch work (P5): never blocks the first frame.
  // 1. Pull first — a server-newer recurring `next_due` must land
  //    BEFORE generation runs, or the rule double-posts (§6 / P0
  //    deviation #2). The pull is bounded: a 30 s timeout means
  //    the server state is unknown, so generation is SKIPPED this
  //    launch (it runs next launch) rather than risking a
  //    double-post. A fast failure (offline, signed out) is known
  //    state — generation runs on local data, exactly as before
  //    sync existed.
  // 2. Recurring generation + notification.
  // 3. Paylater reminder sync.
  // 4. Start the sync triggers (launch syncNow + resume / regain /
  //    save-debounce watchers).
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    var pullSettled = SupabaseAuthService.currentUserId == null;
    // Set when the launch pull's 30 s timeout fires: the timed-out
    // future keeps running detached (Dart futures are not
    // cancellable), so the pull checks this between pages and
    // stops after its current one — otherwise it races the
    // trigger cycle's own pull for the whole remaining library
    // on a slow connection, doubling the timeout risk.
    var launchPullStopped = false;
    if (!pullSettled) {
      try {
        await SyncPullService(
          db: db,
          remote: syncOrchestrator.remote,
          ownerId: SupabaseAuthService.currentUserId,
        ).pullNow(shouldStop: () => launchPullStopped).timeout(const Duration(seconds: 30));
        pullSettled = true;
      } on TimeoutException {
        launchPullStopped = true;
        debugPrint('Launch pull timed out — skipping recurring generation this launch');
      } catch (e) {
        // Fast failure (offline / auth): known state, generate on
        // local data.
        debugPrint('Launch pull failed: $e');
        pullSettled = true;
      }
    }
    // Materialize due recurring transactions. Must never prevent startup.
    if (pullSettled) {
      try {
        final generated = await db.processDueRecurringTransactions();
        if (generated > 0) {
          await NotificationService.showRecurringGenerated(count: generated);
        }
      } catch (e, st) {
        // Never fatal — but never silent either: a failure here means
        // recurring transactions did not post, and that must be visible
        // in the logs instead of vanishing.
        debugPrint('Recurring generation failed: $e\n$st');
      }
    }
    // Generated records can change what paylater wallets owe — keep
    // their due reminders in sync. Never fatal at startup either.
    try {
      for (final w in await db.watchWallets().first) {
        if (w.kind == 'paylater') await syncPaylaterReminder(db, w.id);
      }
    } catch (e) {
      debugPrint('Paylater reminder sync failed: $e');
    }
    syncTriggers.start();
  });
}
