import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

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
    headers: {'Accept': 'application/vnd.github+json'},
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

/// Downloads the APK to the app cache and fires Android's installer.
/// [onProgress] receives 0.0–1.0 (-1 when the size is unknown).
/// Throws on download or install errors.
Future<void> downloadAndInstall(
  String apkUrl, {
  required void Function(double progress) onProgress,
}) async {
  if (apkUrl.isEmpty) {
    throw StateError('This release has no APK attached.');
  }
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/dmoney-manager-update.apk');
  if (await file.exists()) await file.delete();

  final client = http.Client();
  try {
    final req = http.Request('GET', Uri.parse(apkUrl));
    final streamed =
        await client.send(req).timeout(const Duration(seconds: 30));
    if (streamed.statusCode != 200) {
      throw HttpException('Download failed (${streamed.statusCode})',
          uri: Uri.parse(apkUrl));
    }
    final total = streamed.contentLength ?? -1;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in streamed.stream) {
        received += chunk.length;
        sink.add(chunk);
        onProgress(total > 0 ? received / total : -1);
      }
    } finally {
      await sink.close();
    }
  } finally {
    client.close();
  }

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
