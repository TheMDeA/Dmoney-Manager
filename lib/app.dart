import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/auto_backup_listener.dart';
import 'core/utils/app_locale.dart';
import 'l10n/app_localizations.dart';
import 'core/services/quick_add.dart';
import 'core/theme/app_accents.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_navigator.dart';
import 'features/lock/lock_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/app_shell.dart';
import 'state/providers.dart';

class MoneyManagerApp extends ConsumerWidget {
  const MoneyManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final lockEnabled = ref.watch(lockEnabledProvider);
    final locked = ref.watch(lockedProvider);
    final accounts = ref.watch(accountsStreamProvider);
    final accentId = ref.watch(accentProvider);
    final languageOverride = ref.watch(appLocaleProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // Fixed accents ignore the dynamic schemes; Material You takes
        // the OS color, falling back to lime where dynamic is unavailable.
        Color resolve(ColorScheme? dynamicScheme) {
          final accent = accentById(accentId);
          return accent.color ??
              dynamicScheme?.primary ??
              context.accent;
        }

        return MaterialApp(
          title: 'Dmoney Manager',
          debugShowCheckedModeBanner: false,
          locale: languageOverride == null ? null : Locale(languageOverride),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorKey: appNavigatorKey,
          theme: AppTheme.light(resolve(lightDynamic)),
          darkTheme: AppTheme.dark(resolve(darkDynamic)),
          themeMode: themeMode,
          // Screens without an AppBar (e.g. Home) get their status-bar
          // icon style from here; AppBar screens use the theme's
          // AppBarTheme.systemOverlayStyle instead.
          builder: (context, child) {
            // Keep context-free formatters (formatDate, month names) on
            // the resolved app locale. localeOf here is already resolved
            // to one of supportedLocales, never the raw device locale.
            appLocaleCode = Localizations.localeOf(context).languageCode;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: AppTheme.overlayStyle(Theme.of(context).brightness),
              // Binds the launcher-shortcut / Quick Settings tile channel,
              // and runs Drive auto backups on app enter/exit.
              child: QuickAddListener(
                  child: AutoBackupListener(child: child!)),
            );
          },
          home: accounts.when(
            // No accounts yet -> first-launch onboarding. Existing installs that
            // already have (seeded) accounts skip straight to the app.
            data: (list) => list.isEmpty
                ? const OnboardingScreen()
                : (lockEnabled && locked)
                    ? const LockScreen()
                    : const AppShell(),
            loading: () => const _BootSplash(),
            // A database that fails to open must NEVER look like a
            // loading screen: 3.0.0 showed the splash forever when
            // the v17->v18 migration threw (2026-11-23). Surface the
            // error with a retry instead.
            error: (error, _) => _BootError(
              error: error,
              onRetry: () => ref.invalidate(accountsStreamProvider),
            ),
          ),
        );
      },
    );
  }
}

/// Minimal brand splash shown while the database opens.
class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Text(
          'Dmoney',
          style: TextStyle(
            color: context.accent,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

/// Shown when the database fails to open (e.g. a migration throws):
/// the raw error, so the cause is visible, plus a retry. Never a
/// second splash — a failed open must not look like a slow one.
class _BootError extends StatelessWidget {
  const _BootError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Dmoney',
                style: TextStyle(
                  color: context.accent,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Couldn't open your books.",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
