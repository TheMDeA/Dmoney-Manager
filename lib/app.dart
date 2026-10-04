import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          navigatorKey: appNavigatorKey,
          theme: AppTheme.light(resolve(lightDynamic)),
          darkTheme: AppTheme.dark(resolve(darkDynamic)),
          themeMode: themeMode,
          // Screens without an AppBar (e.g. Home) get their status-bar
          // icon style from here; AppBar screens use the theme's
          // AppBarTheme.systemOverlayStyle instead.
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value:
                AppTheme.overlayStyle(Theme.of(context).brightness),
            // Binds the launcher-shortcut / Quick Settings tile channel.
            child: QuickAddListener(child: child!),
          ),
          home: accounts.when(
            // No accounts yet -> first-launch onboarding. Existing installs that
            // already have (seeded) accounts skip straight to the app.
            data: (list) => list.isEmpty
                ? const OnboardingScreen()
                : (lockEnabled && locked)
                    ? const LockScreen()
                    : const AppShell(),
            loading: () => const _BootSplash(),
            error: (_, _) => const _BootSplash(),
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
