import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/app_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_prefs.dart';
import '../../core/services/supabase_auth_service.dart';
import '../../core/services/sync_photos.dart';
import '../../core/services/sync_remote.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ambient_glow.dart';
import '../../core/widgets/screen_header.dart';
import '../../core/theme/app_accents.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../categories/categories_screen.dart';
import '../backup/backup_screen.dart';
import '../export/export_screen.dart';
import '../lock/pin_setup_screen.dart';
import '../recurring/recurring_screen.dart';
import '../tour/feature_tour_screen.dart';
import 'currency_screen.dart';
import 'notifications_screen.dart';
import 'sync_conflicts_screen.dart';
import 'sync_settings_screen.dart';
import 'update_sheet.dart';

/// "Settings" tab: settings, tools, and app info.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = '';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    installedVersion().then((v) {
      if (mounted) setState(() => _version = v);
    });
  }

  Future<void> _pickLanguage(BuildContext context, String? current) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.languageTitle),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: RadioGroup<String?>(
          groupValue: current,
          onChanged: (v) => Navigator.of(context).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (value, label) in <(String?, String)>[
                (null, l10n.languageSystem),
                ('en', l10n.languageEnglish),
                ('id', l10n.languageIndonesian),
              ])
                RadioListTile<String?>(
                  value: value,
                  title: Text(label),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != current && context.mounted) {
      await ref.read(appLocaleProvider.notifier).setLanguage(picked);
    }
  }

  Future<void> _checkForUpdates() async {
    if (_checking) return;
    setState(() => _checking = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final info = await checkForUpdate();
      if (!mounted) return;
      if (info == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsLatestVersion(_version))),
        );
      } else {
        await showUpdateSheet(context, info);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settingsUpdateCheckFailed),
        ),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockEnabled = ref.watch(lockEnabledProvider);
    final themeMode = ref.watch(themeModeProvider);
    final hapticsEnabled = ref.watch(hapticsEnabledProvider);
    final languageCode = ref.watch(appLocaleProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: AmbientGlow(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(title: l10n.settingsTitle, tabIndex: 5),
            Expanded(
              child: ListView(
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
                      title: Text(
                        ref.watch(displayNameProvider),
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        l10n.settingsProfileSubtitle,
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _editProfile(context, ref),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _sectionHeader(context, l10n.settingsSectionManage),
                  _tile(
                    context,
                    icon: Icons.category_outlined,
                    title: l10n.settingsCategories,
                    subtitle: l10n.settingsCategoriesSubtitle,
                    onTap: () => Navigator.of(context).push(
                      AppPageRoute(builder: (_) => const CategoriesScreen()),
                    ),
                  ),
                  _tile(
                    context,
                    icon: Icons.repeat_outlined,
                    title: l10n.settingsRecurring,
                    subtitle: l10n.settingsRecurringSubtitle,
                    onTap: () => Navigator.of(context).push(
                      AppPageRoute(builder: (_) => const RecurringScreen()),
                    ),
                  ),
                  _tile(
                    context,
                    icon: Icons.file_download_outlined,
                    title: l10n.settingsExport,
                    subtitle: l10n.settingsExportSubtitle,
                    onTap: () => Navigator.of(
                      context,
                    ).push(AppPageRoute(builder: (_) => const ExportScreen())),
                  ),
                  _tile(
                    context,
                    icon: Icons.backup_outlined,
                    title: l10n.settingsBackup,
                    subtitle: l10n.settingsBackupSubtitle,
                    onTap: () => Navigator.of(
                      context,
                    ).push(AppPageRoute(builder: (_) => BackupScreen())),
                  ),
                  _syncSettingsTile(context),
                  _syncConflictsTile(context),
                  _syncPhotosTile(context),
                  _sectionHeader(context, l10n.settingsSectionSecurity),
                  SwitchListTile(
                    secondary: const Icon(Icons.lock_outline),
                    title: Text(l10n.settingsPasswordProtection),
                    subtitle: Text(
                      l10n.settingsPasswordProtectionSubtitle,
                      style: TextStyle(color: context.textMuted, fontSize: 12),
                    ),
                    value: lockEnabled,
                    onChanged: (v) => _toggleLock(context, ref, v),
                  ),
                  if (lockEnabled)
                    _tile(
                      context,
                      icon: Icons.password_outlined,
                      title: l10n.settingsChangePasscode,
                      subtitle: l10n.settingsChangePasscodeSubtitle,
                      onTap: () => Navigator.of(context).push(
                        AppPageRoute(
                          builder: (_) => const PinSetupScreen(isChange: true),
                        ),
                      ),
                    ),
                  _sectionHeader(context, l10n.settingsSectionAppearance),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      l10n.settingsThemeColor,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.textMuted,
                      ),
                    ),
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
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: const Icon(Icons.settings_suggest_outlined,
                              size: 18),
                          label: Text(l10n.settingsThemeSystem),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: const Icon(Icons.light_mode_outlined, size: 18),
                          label: Text(l10n.settingsThemeLight),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: const Icon(Icons.dark_mode_outlined, size: 18),
                          label: Text(l10n.settingsThemeDark),
                        ),
                      ],
                      selected: {themeMode},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          ref.read(themeModeProvider.notifier).set(s.first),
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration_outlined),
                    title: Text(l10n.settingsHaptics),
                    subtitle: Text(
                      l10n.settingsHapticsSubtitle,
                      style: TextStyle(color: context.textMuted, fontSize: 12),
                    ),
                    value: hapticsEnabled,
                    onChanged: (v) {
                      ref.read(hapticsEnabledProvider.notifier).set(v);
                      // A confirming buzz when turning it back on.
                      if (v) HapticFeedback.mediumImpact();
                    },
                  ),
                  _sectionHeader(context, l10n.settingsSectionAssistant),
                  SwitchListTile(
                    secondary: const Icon(Icons.auto_awesome_outlined),
                    title: Text(l10n.settingsSmartSuggestions),
                    subtitle: Text(
                      l10n.settingsSmartSuggestionsSubtitle,
                      style: TextStyle(color: context.textMuted, fontSize: 12),
                    ),
                    value: AppPrefs.smartSuggestions,
                    onChanged: (v) async {
                      await AppPrefs.setSmartSuggestions(v);
                      setState(() {});
                    },
                  ),
                  _sectionHeader(context, l10n.settingsSectionGeneral),
                  _tile(
                    context,
                    icon: Icons.attach_money,
                    title: l10n.settingsCurrency,
                    subtitle: currencyByCode(AppPrefs.currencyCode).label,
                    onTap: () async {
                      final changed = await Navigator.of(context).push<bool>(
                        AppPageRoute(builder: (_) => const CurrencyScreen()),
                      );
                      if (changed == true && mounted) setState(() {});
                    },
                  ),
                  _tile(
                    context,
                    icon: Icons.language_outlined,
                    title: l10n.languageTitle,
                    subtitle: switch (languageCode) {
                      'en' => l10n.languageEnglish,
                      'id' => l10n.languageIndonesian,
                      _ => l10n.languageSystem,
                    },
                    onTap: () => _pickLanguage(context, languageCode),
                  ),
                  _tile(
                    context,
                    icon: Icons.notifications_outlined,
                    title: l10n.settingsNotifications,
                    subtitle: l10n.settingsNotificationsSubtitle,
                    onTap: () => Navigator.of(context).push(
                      AppPageRoute(builder: (_) => const NotificationsScreen()),
                    ),
                  ),
                  _sectionHeader(context, l10n.settingsSectionApp),
                  ListTile(
                    leading: const Icon(Icons.system_update_outlined),
                    title: Text(l10n.settingsCheckUpdates),
                    subtitle: Text(
                      _version.isEmpty
                          ? l10n.settingsCheckUpdatesSubtitle
                          : l10n.settingsInstalledVersion(_version),
                      style: TextStyle(color: context.textMuted, fontSize: 12),
                    ),
                    trailing: _checking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _checkForUpdates,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.autorenew_outlined),
                    title: Text(l10n.settingsAutoCheck),
                    subtitle: Text(
                      l10n.settingsAutoCheckSubtitle,
                      style: TextStyle(color: context.textMuted, fontSize: 12),
                    ),
                    value: AppPrefs.autoCheckUpdate,
                    onChanged: (v) async {
                      await AppPrefs.setAutoCheckUpdate(v);
                      if (mounted) setState(() {});
                    },
                  ),
                  _tile(
                    context,
                    icon: Icons.explore_outlined,
                    title: l10n.settingsFeatureTour,
                    subtitle: l10n.settingsFeatureTourSubtitle,
                    onTap: () => FeatureTourScreen.show(context),
                  ),
                  _tile(
                    context,
                    icon: Icons.info_outline,
                    title: l10n.settingsAbout,
                    subtitle: _version.isEmpty
                        ? 'Dmoney Manager'
                        : 'Dmoney Manager $_version',
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'Dmoney Manager',
                      applicationVersion: _version.isEmpty ? '' : _version,
                      applicationLegalese: l10n.settingsAboutLegalese,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLock(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    if (enable) {
      if (!AppPrefs.hasPin) {
        final set = await Navigator.of(
          context,
        ).push<bool>(AppPageRoute(builder: (_) => const PinSetupScreen()));
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
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController(text: ref.read(displayNameProvider));
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.settingsProfileTitle),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: l10n.settingsDisplayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (saved == true && ctrl.text.trim().isNotEmpty) {
      await ref.read(displayNameProvider.notifier).set(ctrl.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.settingsProfileUpdated)));
      }
    }
    ctrl.dispose();
  }

  Widget _accentSwatch(WidgetRef ref, AppAccent a) {
    final selected = ref.watch(accentProvider) == a.id;
    final checkColor = a.color == null ? Colors.white : onAccent(a.color!);
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
              ? const SweepGradient(
                  colors: [
                    Color(0xFFC6FF4A),
                    Color(0xFF38BDF8),
                    Color(0xFFA78BFA),
                    Color(0xFFFB923C),
                    Color(0xFFF472B6),
                    Color(0xFFC6FF4A),
                  ],
                )
              : null,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2.5,
                )
              : Border.all(color: context.hairline, width: 1),
        ),
        child: selected
            ? Icon(Icons.check, color: checkColor, size: 22)
            : (a.color == null
                  ? const Icon(
                      Icons.palette_outlined,
                      color: Colors.white,
                      size: 22,
                    )
                  : null),
      ),
    );
  }

  /// Sync conflicts entry (idea #1): the subtitle shows how many
  /// overwritten changes are waiting for review, so the user
  /// notices them without opening the screen.
  /// "Online sync" (P5): status, Sync now, per-account toggles,
  /// devices and the first-run flow live on their own screen; the
  /// tile here shows the signed-in account (or "Not signed in").
  Widget _syncSettingsTile(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final email = SupabaseAuthService.currentUserEmail;
    return _tile(
      context,
      icon: Icons.sync_outlined,
      title: l10n.syncSettingsTitle,
      subtitle: email ?? l10n.syncSettingsNotSignedIn,
      onTap: () => Navigator.of(context).push(
        AppPageRoute(builder: (_) => const SyncSettingsScreen()),
      ),
    );
  }

  Widget _syncConflictsTile(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(databaseProvider);
    return StreamBuilder(
      stream: db.watchSyncConflicts(),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        return _tile(
          context,
          icon: Icons.history_outlined,
          title: l10n.syncConflictsTitle,
          subtitle: count > 0
              ? l10n.syncConflictsToReview(count)
              : l10n.syncConflictsSubtitle,
          onTap: () => Navigator.of(context).push(
            AppPageRoute(builder: (_) => const SyncConflictsScreen()),
          ),
        );
      },
    );
  }

  /// "Download all receipt photos" (§9): fetches the bytes of
  /// every synced photo that is missing on this device — the
  /// one-tap catch-up for a new device, instead of opening each
  /// photo to trigger its lazy download. Downloads are not
  /// Wi-Fi-gated: tapping the tile is an explicit request.
  Widget _syncPhotosTile(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(databaseProvider);
    return _tile(
      context,
      icon: Icons.cloud_download_outlined,
      title: l10n.syncPhotosDownloadAll,
      subtitle: l10n.syncPhotosDownloadAllSubtitle,
      onTap: () => _downloadAllPhotos(context, db),
    );
  }

  Future<void> _downloadAllPhotos(BuildContext context, AppDatabase db) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      if (!SupabaseAuthService.isSignedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.syncPhotosSignInRequired)),
        );
        return;
      }
      final service = SyncPhotoService(
        db: db,
        remote: SupabaseSyncRemote(),
      );
      final result = await service.downloadMissingPhotos();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.failed > 0
                ? l10n.syncPhotosDownloadFailed
                : result.downloaded == 0
                    ? l10n.syncPhotosDownloadNone
                    : l10n.syncPhotosDownloaded(result.downloaded),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.syncPhotosDownloadFailed)),
      );
    }
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: context.textMuted, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  /// Section header grouping related settings.
  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: context.accent),
      ),
    );
  }
}
