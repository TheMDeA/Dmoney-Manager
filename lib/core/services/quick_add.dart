import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_navigator.dart';
import '../../features/transactions/add_transaction_sheet.dart';
import '../../state/providers.dart';

/// Entry points that bypass the normal UI: launcher long-press shortcuts
/// ("Add expense" / "Add income") and the Quick Settings tile. The native
/// side fires an intent with a "quick_action" extra; MainActivity forwards
/// it over the dmoney/quickadd channel and this opens the add sheet
/// directly at the amount keypad.
class QuickAdd {
  static const _channel = MethodChannel('dmoney/quickadd');

  /// Action requested while the app was locked (or before the UI was
  /// ready). Delivered after unlock.
  static String? _pending;

  /// Wire the channel. Called once from [_QuickAddListener].
  static void bind(WidgetRef ref) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onQuickAction') {
        _handle(ref, call.arguments as String?);
      }
    });
    // Cold start: the intent arrived before Flutter was up.
    _channel.invokeMethod<String>('takePendingAction').then((action) {
      if (action != null) _handle(ref, action);
    });
  }

  static void _handle(WidgetRef ref, String? action) {
    final kind =
        (action == 'expense' || action == 'income') ? action : null;
    if (kind == null) return;
    final locked =
        ref.read(lockEnabledProvider) && ref.read(lockedProvider);
    if (locked) {
      // Don't open the sheet over the lock screen; deliver after unlock.
      _pending = kind;
      return;
    }
    _open(kind);
  }

  /// Delivers a lock-deferred action. Called when the lock screen unlocks.
  static void deliverPending(WidgetRef ref) {
    final action = _pending;
    _pending = null;
    if (action != null) _handle(ref, action);
  }

  static void _open(String action) {
    final context = appNavigatorKey.currentContext;
    if (context == null) {
      _pending = action;
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddTransactionSheet(initialKind: action),
    );
  }
}

/// Invisible widget that binds the quick-add channel once the app's
/// navigator exists, and flushes lock-deferred actions on unlock.
class QuickAddListener extends ConsumerStatefulWidget {
  const QuickAddListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<QuickAddListener> createState() =>
      _QuickAddListenerState();
}

class _QuickAddListenerState
    extends ConsumerState<QuickAddListener> {
  @override
  void initState() {
    super.initState();
    // Post-frame: the navigator key has a context by now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) QuickAdd.bind(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(lockedProvider, (_, locked) {
      if (!locked) QuickAdd.deliverPending(ref);
    });
    return widget.child;
  }
}
