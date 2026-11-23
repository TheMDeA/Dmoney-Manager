import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/services/sync_remote.dart';

/// Prefs sync (P5, §7): ONLY currency + language cross devices.
/// Everything else in AppPrefs is device-local by design (theme,
/// lock, notification toggles, account scope, …) and never leaves
/// the device.
///
/// Ordering: one fetch-compare-upsert round per sync cycle, with the
/// server's `server_updated_at` as the only authority (local clocks
/// are never trusted, like the row pull):
/// - server row newer than our stamp (or we never synced prefs) →
///   adopt the server values.
/// - server row not newer and local values differ → push local.
/// - anything fails → best-effort: the data sync already ran, so a
///   prefs failure never fails the cycle; the next cycle retries.
///
/// Locale-switch UX (the question P3 deferred): a pulled language
/// change is written to the pref but the running UI does NOT switch
/// mid-session — the locale is owned by [AppLocaleNotifier] state,
/// and yanking it from a background sync would rebuild every
/// screen under the user's fingers. It applies on the next launch
/// (the notifier reads the pref at startup). The one exception is
/// the first-run migration screen, which applies a pulled language
/// immediately via the notifier — setup is the configuration moment,
/// not a running session. Currency applies immediately everywhere:
/// it is read straight from AppPrefs at every use site.
class SyncPrefsService {
  SyncPrefsService({required this.remote});

  final SyncRemote remote;

  /// One prefs round. Never throws — a failure is reported in the
  /// result and retried next cycle.
  Future<SyncPrefsResult> syncPrefs(String ownerId) async {
    final Map<String, dynamic>? server;
    try {
      server = await remote.fetchPrefs();
    } catch (_) {
      return const SyncPrefsResult(serverUnreachable: true);
    }
    final localCurrency = AppPrefs.currencyCode;
    final localLanguage = AppPrefs.languageCode;
    final stamp = AppPrefs.syncPrefsUpdatedAt;
    if (server != null) {
      final serverTs = _canonical(server['server_updated_at'] as String?);
      final serverCurrency = server['currency_code'] as String?;
      final serverLanguage = server['language_code'] as String?;
      if (stamp == null ||
          (serverTs != null && serverTs.compareTo(stamp) > 0)) {
        // Server is newer (or we never synced prefs): adopt it.
        var currencyChanged = false;
        var languageChanged = false;
        if (serverCurrency != null && serverCurrency != localCurrency) {
          await AppPrefs.setCurrencyCode(serverCurrency);
          currencyChanged = true;
        }
        if (serverLanguage != localLanguage) {
          await AppPrefs.setLanguageCode(serverLanguage);
          languageChanged = true;
        }
        await AppPrefs.setSyncPrefsUpdatedAt(serverTs);
        return SyncPrefsResult(
          currencyChanged: currencyChanged,
          languageChanged: languageChanged,
          appliedServer: true,
        );
      }
      // Server is not newer: push local values if they differ.
      if (serverCurrency != localCurrency ||
          serverLanguage != localLanguage) {
        return _push(ownerId, localCurrency, localLanguage);
      }
      return const SyncPrefsResult();
    }
    // No server row yet: push local values.
    return _push(ownerId, localCurrency, localLanguage);
  }

  Future<SyncPrefsResult> _push(
    String ownerId,
    String currency,
    String? language,
  ) async {
    try {
      await remote.upsertPrefs({
        'owner_id': ownerId,
        'currency_code': currency,
        'language_code': language,
      });
      // Re-fetch so the stamp is the trigger-stamped value the
      // server actually recorded, not a local guess.
      final back = await remote.fetchPrefs();
      await AppPrefs.setSyncPrefsUpdatedAt(
        _canonical(back?['server_updated_at'] as String?),
      );
      return const SyncPrefsResult(pushed: true);
    } catch (_) {
      return const SyncPrefsResult(serverUnreachable: true);
    }
  }

  /// Canonical UTC ISO, like the pull cursor's format — string
  /// comparison then orders timestamps correctly.
  static String? _canonical(String? raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw).toUtc().toIso8601String();
    } catch (_) {
      return raw;
    }
  }
}

/// The outcome of one prefs round.
class SyncPrefsResult {
  const SyncPrefsResult({
    this.currencyChanged = false,
    this.languageChanged = false,
    this.appliedServer = false,
    this.pushed = false,
    this.serverUnreachable = false,
  });

  /// The server's currency was adopted (applies immediately).
  final bool currencyChanged;

  /// The server's language was adopted into the pref — it applies
  /// on the next launch, not mid-session (see the class doc).
  final bool languageChanged;

  /// The server row was newer and its values were adopted.
  final bool appliedServer;

  /// Local values were pushed to the server.
  final bool pushed;

  /// The server could not be reached at all; retry next cycle.
  final bool serverUnreachable;
}
