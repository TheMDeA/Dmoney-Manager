import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../state/providers.dart';
import '../categories/categories_screen.dart';
import '../export/export_screen.dart';

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
              title: const Text('Your profile',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Personal finances',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
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
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('Password protection'),
            subtitle: const Text('Passcode + biometric lock',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            value: lockEnabled,
            onChanged: (v) {
              ref.read(lockEnabledProvider.notifier).set(v);
              if (v) ref.read(lockedProvider.notifier).lock();
            },
          ),
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
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('More currencies coming soon')))),
          _tile(context,
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Budget alerts & debt reminders',
              onTap: () {}),
          _tile(context,
              icon: Icons.info_outline,
              title: 'About',
              subtitle: 'Money Manager 0.1.0',
              onTap: () {}),
        ],
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
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
