import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../utils/app_locale.dart';
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
      // modifiedTime, not createdTime: an overwritten auto backup keeps
      // its original createdTime but a fresh modifiedTime.
      createdAt: DateTime.tryParse(json['modifiedTime'] as String? ??
              json['createdTime'] as String? ??
              '') ??
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
  static const keepCount = 3;

  /// Fixed name of the auto-backup file. Auto backups overwrite this
  /// single file instead of adding to the manual backup history.
  static const autoFileName = 'dmoney-autobackup.zip';

  static const _lastBackupKey = 'drive_last_backup_at';
  static const _autoBackupKey = 'drive_auto_backup';
  static const _accountEmailKey = 'drive_account_email';

  GoogleSignInAccount? _account;
  String? _persistedEmail;
  Future<void>? _initFuture;
  bool _autoRunning = false;
  DateTime? _lastAutoAt;

  GoogleSignInAccount? get currentAccount => _account;

  /// Email of the signed-in Google account — from this run's sign-in or
  /// restored from the previous one. Null when signed out.
  String? get signedInEmail => _account?.email ?? _persistedEmail;

  bool get isSignedIn => signedInEmail != null;

  /// One-time SDK setup + loading the persisted sign-in identity, so
  /// the Google Drive session survives the app being closed. This never
  /// shows auth UI and never calls the plugin's lightweight restore —
  /// on Android that can fall back to an interactive account sheet,
  /// which must only ever appear from the sign-in button. Drive calls
  /// re-obtain authorization silently (see [_headers]); if that ever
  /// fails, the Backup screen offers a reconnect. Safe to call
  /// repeatedly.
  Future<void> init() {
    return _initFuture ??= _init();
  }

  Future<void> _init() async {
    await GoogleSignIn.instance.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    final prefs = await SharedPreferences.getInstance();
    _persistedEmail = prefs.getString(_accountEmailKey);
  }

  /// Whether the "Automatically backup" setting is on.
  Future<bool> autoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupKey) ?? false;
  }

  Future<void> setAutoBackupEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupKey, value);
  }

  /// Interactive sign-in, including consent for Drive access.
  Future<GoogleSignInAccount> signIn() async {
    if (serverClientId.isEmpty) {
      throw DriveException(localizedOrFallback(
        (l) => l.backupDriveNotConfigured,
        'Google Drive is not configured in this build yet.',
      ));
    }
    await init();
    final account = await GoogleSignIn.instance.authenticate();
    _account = account;
    // Ask for the Drive scope right away so later calls stay silent.
    await account.authorizationClient.authorizeScopes(_scopes);
    // Persist the identity so the session survives app restarts without
    // the plugin's (possibly interactive) lightweight restore.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accountEmailKey, account.email);
    _persistedEmail = account.email;
    return account;
  }

  Future<void> signOut() async {
    await init();
    await GoogleSignIn.instance.signOut();
    _account = null;
    _persistedEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountEmailKey);
  }

  /// Authorization headers for Drive calls. With
  /// [promptIfNecessary] the user may be shown a consent prompt, so only
  /// pass true from a user-initiated action.
  Future<Map<String, String>> _headers({bool promptIfNecessary = false}) async {
    if (!isSignedIn) {
      throw DriveException(localizedOrFallback(
        (l) => l.backupDriveNotSignedIn,
        'Not signed in to Google.',
      ));
    }
    // Prefer the account-bound client after a live sign-in; for a
    // session restored from the persisted identity, the instance-level
    // client re-authorizes silently from the earlier grant.
    final client =
        _account?.authorizationClient ?? GoogleSignIn.instance.authorizationClient;
    final headers = await client.authorizationHeaders(
      _scopes,
      promptIfNecessary: promptIfNecessary,
    );
    if (headers == null) {
      throw DriveException(localizedOrFallback(
        (l) => l.backupDriveAccessNotGranted,
        'Google Drive access has not been granted.',
      ));
    }
    return headers;
  }

  /// Creates a fresh backup zip and uploads it, then prunes old ones.
  Future<DriveBackup> backUpNow(AppDatabase db) async {
    await init();
    final file = await BackupService.createBackup(db);
    try {
      final backup = await _createFile(file, backupFileName(DateTime.now()),
          prompt: true);
      await _markBackedUp(backup);
      await _prune();
      return backup;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  /// Auto backup: uploads a fresh zip over the single fixed-name auto
  /// file, overwriting the previous one.
  Future<DriveBackup> backUpAuto(AppDatabase db) async {
    await init();
    final file = await BackupService.createBackup(db);
    try {
      final existing = findAutoBackup(await listBackups());
      final backup = existing == null
          ? await _createFile(file, autoFileName)
          : await _updateFile(existing.id, file);
      await _markBackedUp(backup);
      return backup;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  /// Runs an auto backup when the setting is on and a Google session is
  /// available; otherwise does nothing. Never prompts for auth and never
  /// throws — auto backups must not disturb app startup or exit.
  Future<void> maybeAutoBackup(AppDatabase db) async {
    if (_autoRunning) return;
    final last = _lastAutoAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 60)) {
      return;
    }
    try {
      await init();
      if (!await autoBackupEnabled() || !isSignedIn) return;
      _autoRunning = true;
      await backUpAuto(db);
      _lastAutoAt = DateTime.now();
    } catch (_) {
      // Silent by design.
    } finally {
      _autoRunning = false;
    }
  }

  Future<void> _markBackedUp(DriveBackup backup) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _lastBackupKey, backup.createdAt.toIso8601String());
  }

  /// Whether Drive authorization is currently obtainable without any
  /// user interaction. False means the Backup screen should offer a
  /// reconnect (the interactive sign-in) for this restored session.
  Future<bool> hasSilentAccess() async {
    await init();
    if (!isSignedIn) return false;
    try {
      await _headers();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<DateTime?> lastBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastBackupKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<DriveBackup> _createFile(File file, String name,
      {bool prompt = false}) async {
    final headers = await _headers(promptIfNecessary: prompt);
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
          '&fields=id,name,createdTime,modifiedTime,size'),
      headers: {
        ...headers,
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );
    if (response.statusCode != 200) {
      throw DriveException(_errorMessage(
          response,
          localizedOrFallback(
              (l) => l.backupDriveUploadFailed, 'Upload failed')));
    }
    return DriveBackup.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Replaces the contents of an existing Drive file (media upload).
  Future<DriveBackup> _updateFile(String id, File file) async {
    final headers = await _headers();
    final bytes = await file.readAsBytes();
    final response = await http.patch(
      Uri.parse('$_uploadBase/files/$id?uploadType=media'
          '&fields=id,name,createdTime,modifiedTime,size'),
      headers: {...headers, 'Content-Type': 'application/zip'},
      body: bytes,
    );
    if (response.statusCode != 200) {
      throw DriveException(_errorMessage(
          response,
          localizedOrFallback(
              (l) => l.backupDriveUploadFailed, 'Upload failed')));
    }
    return DriveBackup.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// All cloud backups, newest first. Empty when Drive access has not
  /// been granted yet (the upload path requests it interactively).
  Future<List<DriveBackup>> listBackups() async {
    await init();
    if (!isSignedIn) return [];
    final Map<String, String> headers;
    try {
      headers = await _headers();
    } on DriveException {
      return [];
    }
    final query = Uri.encodeQueryComponent(
        "name contains 'dmoney-backup-' or name = '$autoFileName'");
    final response = await http.get(
      Uri.parse('$_apiBase/files?spaces=appDataFolder&q=$query'
          '&fields=files(id,name,createdTime,modifiedTime,size)'
          '&orderBy=createdTime desc'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw DriveException(_errorMessage(
          response,
          localizedOrFallback(
              (l) => l.backupDriveListFailed, 'Could not list backups')));
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
      throw DriveException(_errorMessage(
          response,
          localizedOrFallback(
              (l) => l.backupDriveDownloadFailed, 'Download failed')));
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
      throw DriveException(_errorMessage(
          response,
          localizedOrFallback(
              (l) => l.backupDriveDeleteFailed, 'Delete failed')));
    }
  }

  Future<void> _prune() async {
    final backups = await listBackups();
    // The auto backup file lives outside the manual history.
    final manuals = [
      for (final b in backups)
        if (b.name != autoFileName) b,
    ];
    for (final old in backupsToPrune(manuals)) {
      try {
        await deleteBackup(old.id);
      } catch (_) {
        // Pruning is best-effort; the new backup is already safe.
      }
    }
  }

  /// The auto backup in [backups], or null when none exists yet.
  static DriveBackup? findAutoBackup(List<DriveBackup> backups) {
    for (final b in backups) {
      if (b.name == autoFileName) return b;
    }
    return null;
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
      return localizedOrFallback(
        (l) => l.backupDriveSessionExpired,
        'Google session expired — sign out and sign in again.',
      );
    }
    if (response.statusCode == 403) {
      return localizedOrFallback(
        (l) => l.backupDriveAccessDenied,
        'Google Drive access was denied or quota exceeded.',
      );
    }
    if (response.statusCode == 404) {
      return localizedOrFallback(
        (l) => l.backupDriveBackupGone,
        'That backup is no longer in Google Drive.',
      );
    }
    return '$fallback (${response.statusCode}).';
  }
}
