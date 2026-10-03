import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/formatters.dart';

/// Local notifications: budget threshold alerts and debt due-date reminders.
class NotificationService {
  NotificationService._();
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notif'),
      ),
    );
    _ready = true;
  }

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'dmoney_alerts',
      'Dmoney alerts',
      channelDescription: 'Budget threshold alerts and debt reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// Immediate budget alert (id range offset to avoid clashing with debts).
  static Future<void> showBudgetAlert({
    required int budgetId,
    required String categoryName,
    required int percent,
    required bool over,
  }) async {
    if (!_ready) return;
    await _plugin.show(
      id: 1000000 + budgetId,
      title: over ? 'Budget exceeded' : 'Budget alert',
      body: over
          ? '$categoryName is over budget'
          : '$categoryName reached $percent% of its budget',
      notificationDetails: _details,
    );
  }

  /// Fired when boot-time processing materializes recurring transactions.
  static Future<void> showRecurringGenerated({required int count}) async {
    if (!_ready || count <= 0) return;
    await _plugin.show(
      id: 2000000,
      title: 'Recurring transactions added',
      body: count == 1
          ? '1 recurring transaction was recorded'
          : '$count recurring transactions were recorded',
      notificationDetails: _details,
    );
  }

  /// Reminder at 9:00 AM the day before the due date (inexact — no exact-alarm
  /// permission needed). Skipped when the due date is already past.
  static Future<void> scheduleDebtReminder({
    required int debtId,
    required String person,
    required int amount,
    required bool payable,
    required DateTime dueDate,
  }) async {
    if (!_ready) return;
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      dueDate.year,
      dueDate.month,
      dueDate.day,
      9,
    ).subtract(const Duration(days: 1));
    if (when.isBefore(now)) {
      when = tz.TZDateTime(tz.local, dueDate.year, dueDate.month, dueDate.day, 9);
      if (when.isBefore(now)) return;
    }
    await _plugin.zonedSchedule(
      id: debtId,
      title: 'Debt reminder',
      body: payable
          ? 'You owe ${formatMoney(amount)} to $person'
          : '$person owes you ${formatMoney(amount)}',
      scheduledDate: when,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancelDebtReminder(int debtId) async {
    if (!_ready) return;
    await _plugin.cancel(id: debtId);
  }
}
