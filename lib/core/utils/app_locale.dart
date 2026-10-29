import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'app_navigator.dart';

/// The UI language resolved for the whole app ('en' or 'id'), used by
/// formatters that have no BuildContext (formatDate, month names).
/// Defaults to English; app.dart keeps it in sync with the resolved
/// MaterialApp locale on every build. Widget tests that pump their own
/// MaterialApp never run that sync, so they keep the English default.
String appLocaleCode = 'en';

/// Short month names for the resolved locale, e.g. Jan..Dec in English,
/// Jan..Des in Indonesian. Replaces the hardcoded English month arrays.
List<String> monthAbbreviations() => [
  for (var m = 1; m <= 12; m++)
    DateFormat('MMM', appLocaleCode).format(DateTime(2020, m)),
];

/// Short weekday names for the resolved locale, Sunday first to match the
/// calendar grid, e.g. Sun..Sat in English, Min..Sab in Indonesian.
List<String> weekdayAbbreviations() => [
  for (var i = 0; i < 7; i++)
    DateFormat('EEE', appLocaleCode).format(DateTime(2020, 1, 5 + i)),
];

/// Full month names for the resolved locale.
List<String> monthNames() => [
  for (var m = 1; m <= 12; m++)
    DateFormat('MMMM', appLocaleCode).format(DateTime(2020, m)),
];

/// Resolves a localized string without a [BuildContext], for
/// notification bodies, exception messages and other service-layer text
/// built outside the widget tree.
///
/// Tries [appNavigatorKey]'s current context first; when there is none
/// (e.g. a startup path that runs before MaterialApp builds, or a unit
/// test with no localizations) it returns [fallback] — the English
/// string — instead of throwing. Pass the English text as [fallback]
/// so the call site stays readable when the lookup cannot run.
String localizedOrFallback(
  String Function(AppLocalizations l10n) get,
  String fallback,
) {
  // Best-effort: any failure (no binding yet in pure unit tests, no
  // MaterialApp built yet on the startup path) just means English.
  try {
    final context = appNavigatorKey.currentContext;
    if (context == null) return fallback;
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return fallback;
    return get(l10n);
  } catch (_) {
    return fallback;
  }
}
