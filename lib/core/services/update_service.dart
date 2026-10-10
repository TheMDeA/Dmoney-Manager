import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'app_prefs.dart';

/// In-app update check against the public GitHub releases feed, plus
/// in-app APK download and install (no browser involved).
///
/// Flow: [checkForUpdate] -> if an [UpdateInfo] comes back, show the update
/// sheet -> [downloadAndInstall] streams the APK with progress, then hands
/// it to Android's installer through the `dmoney/update` method channel.
/// Android shows a one-time "allow installs from this app" system prompt on
/// first use (OS requirement, can't be skipped).
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.tag,
    required this.releaseNotes,
    required this.apkUrl,
    required this.releaseUrl,
  });

  /// Latest version without the leading "v", e.g. "2.1.2".
  final String version;

  /// Full tag, e.g. "v2.1.2".
  final String tag;

  /// Release notes (changelog markdown) from GitHub.
  final String releaseNotes;

  /// Direct download URL of the release APK.
  final String apkUrl;

  /// Fallback: the release page on github.com.
  final String releaseUrl;
}

const _releasesUrl =
    'https://api.github.com/repos/TheMDeA/Dmoney-Manager/releases/latest';

const _updateChannel = MethodChannel('dmoney/update');

/// Numeric version comparison: "2.1.10" > "2.1.9". Non-numeric suffixes
/// (e.g. "+24" build metadata) are ignored.
bool isNewerVersion(String latest, String current) {
  List<int> parts(String v) => v
      .split('+')
      .first
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
  final l = parts(latest);
  final c = parts(current);
  for (var i = 0; i < l.length || i < c.length; i++) {
    final lv = i < l.length ? l[i] : 0;
    final cv = i < c.length ? c[i] : 0;
    if (lv != cv) return lv > cv;
  }
  return false;
}

/// Returns the installed app version, e.g. "2.1.1".
Future<String> installedVersion() async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
}

/// Checks GitHub for the latest release. Returns [UpdateInfo] when a newer
/// version exists, null when up to date. Throws on network/API errors.
Future<UpdateInfo?> checkForUpdate() async {
  final current = await installedVersion();
  final res = await http.get(
    Uri.parse(_releasesUrl),
    headers: {
      'Accept': 'application/vnd.github+json',
      // GitHub rejects API requests without a User-Agent (403).
      'User-Agent': 'Dmoney-Manager/$current',
    },
  ).timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw HttpException(
        'GitHub API returned ${res.statusCode}', uri: Uri.parse(_releasesUrl));
  }
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  final tag = (json['tag_name'] as String? ?? '').trim();
  final version = tag.replaceFirst(RegExp(r'^v'), '');
  if (version.isEmpty || !isNewerVersion(version, current)) return null;

  String? apkUrl;
  for (final a in (json['assets'] as List? ?? const [])) {
    final name = (a['name'] as String? ?? '').toLowerCase();
    final url = a['browser_download_url'] as String?;
    if (name.endsWith('.apk') && url != null) {
      apkUrl = url;
      break;
    }
  }
  return UpdateInfo(
    version: version,
    tag: tag,
    releaseNotes: (json['body'] as String? ?? '').trim(),
    apkUrl: apkUrl ?? '',
    releaseUrl: (json['html_url'] as String? ?? '').trim(),
  );
}

/// File handle for the cached APK of [version]. The file may not exist yet.
Future<File> _apkFile(String version) async {
  final dir = await getTemporaryDirectory();
  return File('${dir.path}/dmoney-manager-$version.apk');
}

/// True when a complete APK for [version] is already in the cache —
/// e.g. the download finished but the Android install prompt was dismissed.
Future<bool> isApkCached(String version) async =>
    await (await _apkFile(version)).exists();

/// Streams the APK into the cache. Writes to a `.part` file first and
/// renames on completion, so a partial download is never mistaken for a
/// finished one. Stale cached versions are removed.
///
/// Interrupted downloads are resumed with an HTTP Range request instead of
/// restarted: if the sheet was dismissed (or the app killed) mid-download,
/// the next attempt continues from the partial file. If the server won't
/// honor ranges, it falls back to a fresh download.
///
/// Only one download runs per version: a second request while one is in
/// flight attaches to it (receiving its progress) instead of starting a
/// competing writer on the same `.part` file.
Future<void> downloadApk(
  String apkUrl,
  String version, {
  required void Function(DownloadProgress progress) onProgress,
  // Test-only: inject a fake HTTP client. When omitted, a real client is
  // created (and closed) for the download.
  http.Client? client,
}) async {
  final running = _runningDownloads[version];
  if (running != null) {
    await _attachToRunning(version, running, onProgress);
    return;
  }
  final future = _downloadResumable(apkUrl, version, onProgress,
      client: client);
  _runningDownloads[version] = future;
  try {
    await future;
  } finally {
    _runningDownloads.remove(version);
    _runningProgress.remove(version);
  }
}

/// Versions with a download currently in flight.
final _runningDownloads = <String, Future<void>>{};

/// Latest progress of in-flight downloads, so a sheet opened mid-download
/// can report progress while it waits.
final _runningProgress = <String, DownloadProgress>{};

/// Waits for an in-flight download, forwarding its progress to [onProgress].
Future<void> _attachToRunning(
  String version,
  Future<void> running,
  void Function(DownloadProgress progress) onProgress,
) async {
  final timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
    final p = _runningProgress[version];
    if (p != null) onProgress(p);
  });
  try {
    await running;
  } finally {
    timer.cancel();
  }
}

Future<http.StreamedResponse> _sendDownloadRequest(
  http.Client client,
  String apkUrl,
  int startByte,
) async {
  final req = http.Request('GET', Uri.parse(apkUrl));
  // Some hosts reject requests without a User-Agent; reuse the same one.
  req.headers['User-Agent'] = 'Dmoney-Manager';
  if (startByte > 0) req.headers['Range'] = 'bytes=$startByte-';
  return client.send(req).timeout(const Duration(seconds: 30));
}

Future<void> _downloadResumable(
  String apkUrl,
  String version,
  void Function(DownloadProgress progress) onProgress, {
  http.Client? client,
}) async {
  if (apkUrl.isEmpty) {
    throw StateError('This release has no APK attached.');
  }
  final file = await _apkFile(version);
  final fileName = file.path.split('/').last;
  await for (final e in file.parent.list()) {
    final name = e.path.split('/').last;
    if (e is File &&
        name.startsWith('dmoney-manager-') &&
        name != fileName &&
        (name.endsWith('.apk') || name.endsWith('.apk.part'))) {
      try {
        await e.delete();
      } catch (_) {}
    }
  }

  final part = File('${file.path}.part');
  var startByte = await part.exists() ? await part.length() : 0;

  final http.Client effectiveClient = client ?? http.Client();
  try {
    late final http.StreamedResponse streamed;
    if (startByte > 0) {
      final res =
          await _sendDownloadRequest(effectiveClient, apkUrl, startByte);
      if (res.statusCode == 206) {
        streamed = res; // Server honors resume.
      } else {
        // 416 (nothing left) or the server ignored the Range header:
        // discard the partial file and fall back to a fresh download.
        await res.stream.drain<void>();
        await part.delete();
        startByte = 0;
        streamed = await _sendDownloadRequest(effectiveClient, apkUrl, 0);
      }
    } else {
      streamed = await _sendDownloadRequest(effectiveClient, apkUrl, 0);
    }
    if (streamed.statusCode != 200 && streamed.statusCode != 206) {
      throw HttpException('Download failed (${streamed.statusCode})',
          uri: Uri.parse(apkUrl));
    }
    final resumed = startByte > 0 && streamed.statusCode == 206;
    final remaining = streamed.contentLength ?? -1;
    final total = remaining > 0 ? startByte + remaining : -1;

    var received = startByte;
    // Rolling speedometer: recomputed from the bytes landed in the last
    // ~0.5 s window, so the displayed speed stays stable instead of
    // jumping with every chunk.
    var windowStart = DateTime.now();
    var windowBytes = startByte;
    var speedBps = 0.0;
    void report() {
      final elapsed =
          DateTime.now().difference(windowStart).inMilliseconds / 1000.0;
      if (elapsed >= 0.5 && received > windowBytes) {
        speedBps = (received - windowBytes) / elapsed;
        windowBytes = received;
        windowStart = DateTime.now();
      }
      final progress = DownloadProgress(
        fraction: total > 0 ? received / total : -1.0,
        bytesPerSecond: speedBps,
      );
      _runningProgress[version] = progress;
      onProgress(progress);
    }

    report();
    // Time-driven reports on top of the per-chunk ones: chunks can arrive
    // in bursts (or stall), and a sheet attached mid-download polls this
    // state — so keep it fresh on a steady cadence regardless.
    final reporter =
        Timer.periodic(const Duration(milliseconds: 500), (_) => report());
    final sink =
        part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
    try {
      await for (final chunk in streamed.stream) {
        received += chunk.length;
        sink.add(chunk);
        report();
      }
    } finally {
      reporter.cancel();
      await sink.close();
    }
  } finally {
    // Only close the client we created; an injected test client is owned
    // by the caller.
    if (client == null) effectiveClient.close();
  }
  await part.rename(file.path);
}

/// Hands a cached APK to Android's installer through the `dmoney/update`
/// method channel. Throws on install errors.
Future<void> installApk(File file) async {
  try {
    await _updateChannel.invokeMethod('installApk', {'path': file.path});
  } on PlatformException catch (e) {
    if (e.code == 'UNKNOWN_SOURCES') {
      throw StateError(
          'Allow "Install unknown apps" for Dmoney Manager in system settings, then try again.');
    }
    rethrow;
  }
}

/// Progress of an in-flight APK download.
class DownloadProgress {
  const DownloadProgress({
    required this.fraction,
    required this.bytesPerSecond,
  });

  /// 0.0–1.0, or -1 when the total size is unknown.
  final double fraction;

  /// Rolling download speed in bytes per second (0 until measured).
  final double bytesPerSecond;
}

/// Formats a bytes-per-second speed as "850 B/s", "1.5 KB/s" or "2.4 MB/s".
String formatSpeed(double bytesPerSecond) {
  const kb = 1024.0;
  const mb = 1024.0 * 1024.0;
  if (bytesPerSecond >= mb) {
    return '${(bytesPerSecond / mb).toStringAsFixed(1)} MB/s';
  }
  if (bytesPerSecond >= kb) {
    return '${(bytesPerSecond / kb).toStringAsFixed(1)} KB/s';
  }
  return '${bytesPerSecond.toStringAsFixed(0)} B/s';
}

/// Downloads the APK to the app cache (reusing it when already cached for
/// [version]) and fires Android's installer.
/// [onProgress] receives the fraction (0.0–1.0, -1 when unknown) and the
/// rolling download speed. Throws on download or install errors.
Future<void> downloadAndInstall(
  String apkUrl, {
  required String version,
  required void Function(DownloadProgress progress) onProgress,
}) async {
  if (!await isApkCached(version)) {
    await downloadApk(apkUrl, version, onProgress: onProgress);
  }
  await installApk(await _apkFile(version));
}

/// Automatic update check: runs at most once per day, silently.
/// Returns the [UpdateInfo] when a newer version is available and the user
/// hasn't dismissed it — the caller decides how to surface it (snackbar,
/// never a blocking dialog). Returns null when disabled, throttled,
/// dismissed, up-to-date, or on any failure.
///
/// Call after the first frame (e.g. from AppShell's initState).
Future<UpdateInfo?> maybeAutoCheckUpdate() async {
  if (!AppPrefs.autoCheckUpdate) return null;
  final now = DateTime.now().millisecondsSinceEpoch;
  if (now - AppPrefs.lastUpdateCheck <
      const Duration(days: 1).inMilliseconds) {
    return null;
  }
  await AppPrefs.setLastUpdateCheck(now);
  try {
    final info = await checkForUpdate();
    if (info == null) return null;
    if (info.version == AppPrefs.dismissedUpdateVersion) return null;
    return info;
  } catch (_) {
    return null; // Silent: offline or GitHub hiccup.
  }
}
