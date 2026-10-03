import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../state/providers.dart';
import '../categories/categories_screen.dart';
import '../backup/backup_screen.dart';
import '../export/export_screen.dart';
import '../lock/pin_setup_screen.dart';
import 'notifications_screen.dart';

/// "More" tab: settings, tools, and app info.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockEnabled = ref.watch(lockEnabledProvider);
    final themeMode = ref.watch(themeModeProvider);

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
                  gradient: const LinearGradient(
                    colors: [AppColors.lime, AppColors.violet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.person, color: Colors.black),
              ),
              title: Text(ref.watch(displayNameProvider),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Personal finances',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
                  MaterialPageRoute(builder: (_) => const CategoriesScreen()))),
          _tile(context,
              icon: Icons.file_download_outlined,
              title: 'Export data',
              subtitle: 'CSV / Excel',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExportScreen()))),
          _tile(context,
              icon: Icons.backup_outlined,
              title: 'Backup & restore',
              subtitle: 'Full backup to a file',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BackupScreen()))),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('Password protection'),
            subtitle: const Text('Passcode + biometric lock',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            value: lockEnabled,
            onChanged: (v) => _toggleLock(context, ref, v),
          ),
          if (lockEnabled)
            _tile(context,
                icon: Icons.password_outlined,
                title: 'Change passcode',
                subtitle: 'Update your 4-digit PIN',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PinSetupScreen(isChange: true)))),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Appearance',
                style: Theme.of(context).textTheme.labelLarge),
          ),
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
          const Divider(),
          _tile(context,
              icon: Icons.attach_money,
              title: 'Currency',
              subtitle: 'Indonesian Rupiah (IDR)',
              onTap: () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Currency'),
                      content: const Text(
                          'Dmoney Manager uses Indonesian Rupiah (IDR) for all amounts.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  )),
          _tile(context,
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Budget alerts & debt reminders',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const NotificationsScreen()))),
          _tile(context,
              icon: Icons.info_outline,
              title: 'About',
              subtitle: 'Dmoney Manager 1.1.0',
              onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Dmoney Manager',
                    applicationVersion: '1.1.0',
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
          MaterialPageRoute(builder: (_) => const PinSetupScreen()),
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

  Widget _tile(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
