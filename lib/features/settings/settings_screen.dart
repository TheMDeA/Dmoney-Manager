import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/app_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_accents.dart';
import '../../core/utils/formatters.dart';
import '../../state/providers.dart';
import '../categories/categories_screen.dart';
import '../backup/backup_screen.dart';
import '../export/export_screen.dart';
import '../lock/pin_setup_screen.dart';
import '../recurring/recurring_screen.dart';
import 'currency_screen.dart';
import 'notifications_screen.dart';

/// "More" tab: settings, tools, and app info.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final lockEnabled = ref.watch(lockEnabledProvider);
    final themeMode = ref.watch(themeModeProvider);
    final hapticsEnabled = ref.watch(hapticsEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          Card(
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [context.accent, AppColors.violet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.person, color: Colors.black),
              ),
              title: Text(ref.watch(displayNameProvider),
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Personal finances',
                  style: TextStyle(color: context.textMuted, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _editProfile(context, ref),
            ),
          ),
          const SizedBox(height: 8),
          _tile(context,
              icon: Icons.category_outlined,
              title: 'Categories',
              subtitle: 'Create, edit, delete',
              onTap: () => Navigator.of(context).push(
                  AppPageRoute(builder: (_) => const CategoriesScreen()))),
          _tile(context,
              icon: Icons.file_download_outlined,
              title: 'Export data',
              subtitle: 'CSV / Excel',
              onTap: () => Navigator.of(context).push(
                  AppPageRoute(builder: (_) => const ExportScreen()))),
          _tile(context,
              icon: Icons.backup_outlined,
              title: 'Backup & restore',
              subtitle: 'Full backup to a file',
              onTap: () => Navigator.of(context).push(
                  AppPageRoute(builder: (_) => BackupScreen()))),
          _tile(context,
              icon: Icons.repeat_outlined,
              title: 'Recurring transactions',
              subtitle: 'Subscriptions, salary, rent',
              onTap: () => Navigator.of(context).push(
                  AppPageRoute(builder: (_) => const RecurringScreen()))),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('Password protection'),
            subtitle: Text('Passcode + biometric lock',
                style: TextStyle(color: context.textMuted, fontSize: 12)),
            value: lockEnabled,
            onChanged: (v) => _toggleLock(context, ref, v),
          ),
          if (lockEnabled)
            _tile(context,
                icon: Icons.password_outlined,
                title: 'Change passcode',
                subtitle: 'Update your 4-digit PIN',
                onTap: () => Navigator.of(context).push(AppPageRoute(
                    builder: (_) => const PinSetupScreen(isChange: true)))),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Appearance',
                style: Theme.of(context).textTheme.labelLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Theme color',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: context.textMuted)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final a in appAccents) _accentSwatch(ref, a),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.settings_suggest_outlined, size: 18),
                    label: Text('System')),
                ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined, size: 18),
                    label: Text('Light')),
                ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined, size: 18),
                    label: Text('Dark')),
              ],
              selected: {themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).set(s.first),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration_outlined),
            title: const Text('Haptic feedback'),
            subtitle: Text('Vibrations on taps and actions',
                style: TextStyle(color: context.textMuted, fontSize: 12)),
            value: hapticsEnabled,
            onChanged: (v) {
              ref.read(hapticsEnabledProvider.notifier).set(v);
              // A confirming buzz when turning it back on.
              if (v) HapticFeedback.mediumImpact();
            },
          ),
          const Divider(),
          _tile(context,
              icon: Icons.attach_money,
              title: 'Currency',
              subtitle: currencyByCode(AppPrefs.currencyCode).label,
              onTap: () async {
                final changed = await Navigator.of(context).push<bool>(
                  AppPageRoute(
                      builder: (_) => const CurrencyScreen()),
                );
                if (changed == true && mounted) setState(() {});
              }),
          _tile(context,
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Budget alerts & debt reminders',
              onTap: () => Navigator.of(context).push(AppPageRoute(
                  builder: (_) => const NotificationsScreen()))),
          _tile(context,
              icon: Icons.info_outline,
              title: 'About',
              subtitle: 'Dmoney Manager 2.1.1',
              onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Dmoney Manager',
                    applicationVersion: '2.1.1',
                    applicationLegalese: 'A simple, modern money manager.',
                  )),
        ],
      ),
    );
  }

  Future<void> _toggleLock(
      BuildContext context, WidgetRef ref, bool enable) async {
    if (enable) {
      if (!AppPrefs.hasPin) {
        final set = await Navigator.of(context).push<bool>(
          AppPageRoute(builder: (_) => const PinSetupScreen()),
        );
        if (set != true) return;
      }
      await ref.read(lockEnabledProvider.notifier).set(true);
      ref.read(lockedProvider.notifier).lock();
    } else {
      await ref.read(lockEnabledProvider.notifier).set(false);
      ref.read(lockedProvider.notifier).unlock();
    }
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: ref.read(displayNameProvider));
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Your profile'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved == true && ctrl.text.trim().isNotEmpty) {
      await ref.read(displayNameProvider.notifier).set(ctrl.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    }
  }

  Widget _accentSwatch(WidgetRef ref, AppAccent a) {
    final selected = ref.watch(accentProvider) == a.id;
    final checkColor =
        a.color == null ? Colors.white : onAccent(a.color!);
    return InkWell(
      onTap: () => ref.read(accentProvider.notifier).set(a.id),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: a.color,
          gradient: a.color == null
              ? const SweepGradient(colors: [
                  Color(0xFFC6FF4A),
                  Color(0xFF38BDF8),
                  Color(0xFFA78BFA),
                  Color(0xFFFB923C),
                  Color(0xFFF472B6),
                  Color(0xFFC6FF4A),
                ])
              : null,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2.5,
                )
              : Border.all(
                  color: context.hairline,
                  width: 1,
                ),
        ),
        child: selected
            ? Icon(Icons.check, color: checkColor, size: 22)
            : (a.color == null
                ? const Icon(Icons.palette_outlined,
                    color: Colors.white, size: 22)
                : null),
      ),
    );
  }

  Widget _tile(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle,
          style: TextStyle(color: context.textMuted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
