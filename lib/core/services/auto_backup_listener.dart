import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

/// Runs the Google Drive auto backup when the user enters and exits
/// the application, while the "Automatically backup" setting is on.
///
/// Entering = once after the first frame (the service silently restores
/// the session only when the setting is on). Exiting = when the app is
/// paused or detached. The service itself guards on the setting, the
/// sign-in state, and a minimum interval, and never prompts or throws.
class AutoBackupListener extends ConsumerStatefulWidget {
  const AutoBackupListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutoBackupListener> createState() =>
      _AutoBackupListenerState();
}

class _AutoBackupListenerState extends ConsumerState<AutoBackupListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _run();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _run();
    }
  }

  void _run() {
    final db = ref.read(databaseProvider);
    ref.read(driveBackupServiceProvider).maybeAutoBackup(db);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
