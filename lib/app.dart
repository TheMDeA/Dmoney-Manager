import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/lock/lock_screen.dart';
import 'features/shell/app_shell.dart';
import 'state/providers.dart';

class MoneyManagerApp extends ConsumerWidget {
  const MoneyManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final lockEnabled = ref.watch(lockEnabledProvider);
    final locked = ref.watch(lockedProvider);

    return MaterialApp(
      title: 'Money Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: (lockEnabled && locked) ? const LockScreen() : const AppShell(),
    );
  }
}
