import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_prefs.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/paylater_reminder_sync.dart';
import '../../state/providers.dart';
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
  late bool _paylaterReminders;

  @override
  void initState() {
    super.initState();
    _budgetAlerts = AppPrefs.budgetAlerts;
    _debtReminders = AppPrefs.debtReminders;
    _paylaterReminders = AppPrefs.paylaterReminders;
  }

  Future<bool> _ensurePermission() async {
    final granted = await NotificationService.requestPermission();
    if (!granted && mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settingsNotifPermissionDenied),
        ),
      );
    }
    return granted;
  }

  /// Re-runs the per-wallet paylater reminder sweep (same as the
  /// main.dart launch loop): schedules when the pref is ON, cancels
  /// when it is OFF — syncPaylaterReminder reads the pref itself, so
  /// one sweep covers both directions.
  Future<void> _resyncPaylaterReminders() async {
    try {
      final db = ref.read(databaseProvider);
      for (final w in await db.watchWallets().first) {
        if (w.kind == 'paylater') await syncPaylaterReminder(db, w.id);
      }
    } catch (e) {
      debugPrint('Paylater reminder sync failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsNotifications)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.savings_outlined),
            title: Text(l10n.settingsBudgetAlerts),
            subtitle: Text(
              l10n.settingsBudgetAlertsSubtitle,
              style: TextStyle(color: context.textMuted, fontSize: 12),
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
            title: Text(l10n.settingsDebtReminders),
            subtitle: Text(
              l10n.settingsDebtRemindersSubtitle,
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
            value: _debtReminders,
            onChanged: (v) async {
              if (v && !await _ensurePermission()) return;
              await AppPrefs.setDebtReminders(v);
              setState(() => _debtReminders = v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.credit_card_outlined),
            title: Text(l10n.settingsPaylaterReminders),
            subtitle: Text(
              l10n.settingsPaylaterRemindersSubtitle,
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
            value: _paylaterReminders,
            onChanged: (v) async {
              if (v && !await _ensurePermission()) return;
              await AppPrefs.setPaylaterReminders(v);
              await _resyncPaylaterReminders();
              if (mounted) setState(() => _paylaterReminders = v);
            },
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              l10n.settingsNotifFootnote,
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
