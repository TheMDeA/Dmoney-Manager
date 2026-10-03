import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/app_prefs.dart';
import 'core/services/notification_service.dart';
import 'data/database/app_database.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPrefs.init();
  // Notifications must never prevent the app from starting.
  try {
    await NotificationService.init();
  } catch (_) {
    // Leave notifications disabled; the app runs fine without them.
  }
  final db = AppDatabase();
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MoneyManagerApp(),
    ),
  );
}
