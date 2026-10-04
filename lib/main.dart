import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/services/app_prefs.dart';
import 'core/services/notification_service.dart';
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
  final db = AppDatabase();
  // Materialize due recurring transactions. Must never prevent startup.
  try {
    final generated = await db.processDueRecurringTransactions();
    if (generated > 0) {
      await NotificationService.showRecurringGenerated(count: generated);
    }
  } catch (_) {}
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MoneyManagerApp(),
    ),
  );
}
