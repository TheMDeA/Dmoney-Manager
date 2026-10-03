import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_prefs.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';

/// Notification preferences: budget threshold alerts and debt reminders.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late bool _budgetAlerts;
  late bool _debtReminders;

  @override
  void initState() {
    super.initState();
    _budgetAlerts = AppPrefs.budgetAlerts;
    _debtReminders = AppPrefs.debtReminders;
  }

  Future<bool> _ensurePermission() async {
    final granted = await NotificationService.requestPermission();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Notification permission denied — enable it in system settings'),
        ),
      );
    }
    return granted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.savings_outlined),
            title: const Text('Budget alerts'),
            subtitle: const Text(
              'Notify when a budget reaches 80% and 100%',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            value: _budgetAlerts,
            onChanged: (v) async {
              if (v && !await _ensurePermission()) return;
              await AppPrefs.setBudgetAlerts(v);
              setState(() => _budgetAlerts = v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.alarm_outlined),
            title: const Text('Debt reminders'),
            subtitle: const Text(
              'Remind me a day before a debt is due',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            value: _debtReminders,
            onChanged: (v) async {
              if (v && !await _ensurePermission()) return;
              await AppPrefs.setDebtReminders(v);
              setState(() => _debtReminders = v);
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'Reminders are scheduled on this device when you add a debt with a due date.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
