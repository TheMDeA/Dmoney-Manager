import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import 'backup_service.dart';

/// Thrown when a Google Drive backup operation fails.
class DriveException implements Exception {
  DriveException(this.message);
  final String message;
  @override
  String toString() => 'DriveException: $message';
}

/// One backup stored in Google Drive.
class DriveBackup {
  const DriveBackup({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.sizeBytes,
  });

  factory DriveBackup.fromJson(Map<String, dynamic> json) {
    return DriveBackup(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt:
          DateTime.tryParse(json['createdTime'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      sizeBytes: int.tryParse(json['size'] as String? ?? '') ?? 0,
    );
  }

  final String id;
  final String name;
  final DateTime createdAt;
  final int sizeBytes;
}

/// Google Drive backup: the same zip [BackupService] creates, uploaded
/// to the app's hidden `appDataFolder` — invisible in the user's Drive
/// file list, and the app can only ever see its own backups.
///
/// Only the `drive.appdata` scope is requested. Sign-in and consent run
/// through google_sign_in; the Drive REST calls use the plain `http`
/// package with the authorization headers it provides.
class DriveBackupService {
  static const _scopes = ['https://www.googleapis.com/auth/drive.appdata'];
  static const _apiBase = 'https://www.googleapis.com/drive/v3';
  static const _uploadBase = 'https://www.googleapis.com/upload/drive/v3';

  /// The Web OAuth client ID from the Google Cloud project (Credentials →
  /// OAuth client ID → Web application). Credential Manager sign-in on
  /// Android requires it. A client ID is a public identifier, not a
  /// secret — it ships inside the APK.
  static const serverClientId =
      '762584749177-fcu62fjiqs36e9adqht5e4q0jkop16p1.apps.googleusercontent.com';

  /// How many cloud backups to keep; older ones are pruned after upload.
  static const keepCount = 5;

  static const _lastBackupKey = 'drive_last_backup_at';

  GoogleSignInAccount? _account;
  Future<void>? _initFuture;

  GoogleSignInAccount? get currentAccount => _account;
  bool get isSignedIn => _account != null;

  /// One-time SDK setup + a silent attempt to restore the previous
  /// sign-in. Safe to call repeatedly.
  Future<void> init() {
    return _initFuture ??= _init();
  }

  Future<void> _init() async {
    await GoogleSignIn.instance.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    try {
      _account =
          await GoogleSignIn.instance.attemptLightweightAuthentication();
    } catch (_) {
      _account = null;
    }
  }

  /// Interactive sign-in, including consent for Drive access.
  Future<GoogleSignInAccount> signIn() async {
    if (serverClientId.isEmpty) {
      throw DriveException(
          'Google Drive is not configured in this build yet.');
    }
    await init();
    final account = await GoogleSignIn.instance.authenticate();
    _account = account;
    // Ask for the Drive scope right away so later calls stay silent.
    await account.authorizationClient.authorizeScopes(_scopes);
    return account;
  }

  Future<void> signOut() async {
    await init();
    await GoogleSignIn.instance.signOut();
    _account = null;
  }

  /// Authorization headers for Drive calls. With
  /// [promptIfNecessary] the user may be shown a consent prompt, so only
  /// pass true from a user-initiated action.
  Future<Map<String, String>> _headers({bool promptIfNecessary = false}) async {
    final account = _account;
    if (account == null) {
      throw DriveException('Not signed in to Google.');
    }
    final headers = await account.authorizationClient.authorizationHeaders(
      _scopes,
      promptIfNecessary: promptIfNecessary,
    );
    if (headers == null) {
      throw DriveException('Google Drive access has not been granted.');
    }
    return headers;
  }

  /// Creates a fresh backup zip and uploads it, then prunes old ones.
  Future<DriveBackup> backUpNow(AppDatabase db) async {
    await init();
    final file = await BackupService.createBackup(db);
    try {
      final backup = await _upload(file);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _lastBackupKey, backup.createdAt.toIso8601String());
      await _prune();
      return backup;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<DateTime?> lastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastBackupKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<DriveBackup> _upload(File file) async {
    final headers = await _headers(promptIfNecessary: true);
    final name = backupFileName(DateTime.now());
    final bytes = await file.readAsBytes();

    const boundary = 'dmoney_backup_boundary';
    final metadata = jsonEncode({
      'name': name,
      'parents': ['appDataFolder'],
      'mimeType': 'application/zip',
    });
    final body = <int>[
      ...utf8.encode('--$boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n'
          '$metadata\r\n'
          '--$boundary\r\n'
          'Content-Type: application/zip\r\n\r\n'),
      ...bytes,
      ...utf8.encode('\r\n--$boundary--'),
    ];

    final response = await http.post(
      Uri.parse('$_uploadBase/files?uploadType=multipart'
          '&fields=id,name,createdTime,size'),
      headers: {
        ...headers,
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );
    if (response.statusCode != 200) {
      throw DriveException(_errorMessage(response, 'Upload failed'));
    }
    return DriveBackup.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// All cloud backups, newest first. Empty when Drive access has not
  /// been granted yet (the upload path requests it interactively).
  Future<List<DriveBackup>> listBackups() async {
    await init();
    if (_account == null) return [];
    final Map<String, String> headers;
    try {
      headers = await _headers();
    } on DriveException {
      return [];
    }
    final query = Uri.encodeQueryComponent("name contains 'dmoney-backup-'");
    final response = await http.get(
      Uri.parse('$_apiBase/files?spaces=appDataFolder&q=$query'
          '&fields=files(id,name,createdTime,size)'
          '&orderBy=createdTime desc'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw DriveException(_errorMessage(response, 'Could not list backups'));
    }
    final files = (jsonDecode(response.body)
        as Map<String, dynamic>)['files'] as List<dynamic>? ?? [];
    final backups = [
      for (final f in files)
        DriveBackup.fromJson(f as Map<String, dynamic>),
    ];
    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups;
  }

  /// Downloads a cloud backup to a temp file ready for
  /// [BackupService.restoreBackup].
  Future<File> downloadBackup(DriveBackup backup) async {
    final headers = await _headers();
    final response = await http.get(
      Uri.parse('$_apiBase/files/${backup.id}?alt=media'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw DriveException(_errorMessage(response, 'Download failed'));
    }
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/${backup.name}');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  Future<void> deleteBackup(String id) async {
    final headers = await _headers();
    final response = await http.delete(
      Uri.parse('$_apiBase/files/$id'),
      headers: headers,
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw DriveException(_errorMessage(response, 'Delete failed'));
    }
  }

  Future<void> _prune() async {
    final backups = await listBackups();
    for (final old in backupsToPrune(backups)) {
      try {
        await deleteBackup(old.id);
      } catch (_) {
        // Pruning is best-effort; the new backup is already safe.
      }
    }
  }

  /// Backups beyond the newest [keep] (input order doesn't matter).
  static List<DriveBackup> backupsToPrune(List<DriveBackup> backups,
      {int keep = keepCount}) {
    final sorted = [...backups]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.length <= keep ? [] : sorted.sublist(keep);
  }

  /// Zip file name for a backup created at [when] — same stamp format
  /// as the local backup.
  static String backupFileName(DateTime when) {
    final stamp = when
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    return 'dmoney-backup-$stamp.zip';
  }

  static String _errorMessage(http.Response response, String fallback) {
    if (response.statusCode == 401) {
      return 'Google session expired — sign out and sign in again.';
    }
    if (response.statusCode == 403) {
      return 'Google Drive access was denied or quota exceeded.';
    }
    if (response.statusCode == 404) {
      return 'That backup is no longer in Google Drive.';
    }
    return '$fallback (${response.statusCode}).';
  }
}
