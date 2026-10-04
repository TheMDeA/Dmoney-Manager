import 'package:flutter/widgets.dart';

/// Global navigator key so background entry points (launcher shortcuts,
/// the Quick Settings tile) can open UI without a BuildContext.
final appNavigatorKey = GlobalKey<NavigatorState>();
