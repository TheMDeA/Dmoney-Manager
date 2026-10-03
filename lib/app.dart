import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
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

    return MaterialApp(
      title: 'Dmoney Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
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
  }
}

/// Minimal brand splash shown while the database opens.
class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Center(
        child: Text(
          'Dmoney',
          style: TextStyle(
            color: AppColors.lime,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}
