import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/services/sync_remote.dart';

/// One row of the server `devices` table (idea #2, P5).
class SyncDeviceRow {
  const SyncDeviceRow({
    required this.deviceId,
    required this.label,
    required this.lastSeenAt,
    required this.appVersion,
  });

  final String deviceId;
  final String label;
  final DateTime lastSeenAt;
  final String appVersion;

  /// True when this row is the device running the app.
  bool get isThisDevice => deviceId == AppPrefs.syncDeviceId;
}

/// The device list (idea #2, P5): a heartbeat row per device, and
/// nothing else. A device row is NOT data — it carries only an id,
/// a label, a last-seen timestamp and the app version, so a stale
/// device is obvious in Settings and no app data flows through it.
///
/// The label defaults to the Android model string
/// (`device_info_plus`); on any failure it falls back to
/// "Android device" — a missing label must never fail a sync.
/// The app version comes from `package_info_plus`. Both are
/// injectable so tests can drive them without platform channels.
class SyncDeviceService {
  SyncDeviceService({
    required this.remote,
    Future<String> Function()? labelProvider,
    Future<String> Function()? appVersionProvider,
  }) : _labelProvider = labelProvider ?? _defaultLabel,
       _appVersionProvider = appVersionProvider ?? _defaultAppVersion;

  final SyncRemote remote;
  final Future<String> Function() _labelProvider;
  final Future<String> Function() _appVersionProvider;

  /// This device's stable id, generated once on the first sync and
  /// kept in prefs. Two installs on the same phone get different
  /// ids (a reinstall is a new device row) — that is deliberate:
  /// the row is a heartbeat, and a stale row is how a reinstall
  /// shows up.
  Future<String> deviceId() async {
    final existing = AppPrefs.syncDeviceId;
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await AppPrefs.setSyncDeviceId(id);
    return id;
  }

  /// Upserts this device's heartbeat row. Best-effort: never
  /// throws, so a failed heartbeat can never fail a sync cycle.
  Future<void> heartbeat(String ownerId) async {
    try {
      final id = await deviceId();
      await remote.upsertDevice({
        'device_id': id,
        'owner_id': ownerId,
        'label': await _labelProvider(),
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        'app_version': await _appVersionProvider(),
      });
    } catch (_) {
      // Heartbeat only — swallow: the cycle already completed.
    }
  }

  /// The owner's device rows, newest heartbeat first. Throws for
  /// auth/transport failures — the caller shows the error.
  Future<List<SyncDeviceRow>> listDevices() async {
    final rows = await remote.listDevices();
    return [
      for (final r in rows)
        SyncDeviceRow(
          deviceId: r['device_id'] as String,
          label: (r['label'] as String?) ?? 'Unknown device',
          lastSeenAt:
              DateTime.tryParse(r['last_seen_at'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
          appVersion: (r['app_version'] as String?) ?? '',
        ),
    ];
  }

  static Future<String> _defaultLabel() async {
    try {
      final model = (await DeviceInfoPlugin().androidInfo).model;
      if (model.isNotEmpty) return model;
    } catch (_) {
      // No platform channel (tests) or an unreadable model.
    }
    return 'Android device';
  }

  static Future<String> _defaultAppVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return 'unknown';
    }
  }
}
