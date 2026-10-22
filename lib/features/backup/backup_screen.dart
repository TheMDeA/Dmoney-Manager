import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/backup_service.dart';
import '../../core/services/drive_backup_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// Backup & restore: create a zip backup (database + receipt photos +
/// preferences) and share it, back it up to Google Drive, or restore
/// one from a file or from Drive.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  String? _status;

  String? _driveAccountEmail;
  bool _driveNeedsReconnect = false;
  List<DriveBackup>? _driveBackups;
  DateTime? _lastDriveBackupAt;
  bool _driveLoading = true;
  bool _autoBackup = false;

  DriveBackupService get _drive => ref.read(driveBackupServiceProvider);

  @override
  void initState() {
    super.initState();
    _loadDrive();
  }

  Future<void> _loadDrive() async {
    try {
      await _drive.init();
      final signedIn = _drive.isSignedIn;
      final backups = signedIn ? await _drive.listBackups() : null;
      final silent = signedIn ? await _drive.hasSilentAccess() : true;
      final last = await _drive.lastBackupAt();
      final auto = await _drive.autoBackupEnabled();
      if (!mounted) return;
      setState(() {
        _driveAccountEmail = _drive.signedInEmail;
        _driveNeedsReconnect = signedIn && !silent;
        _driveBackups = backups;
        _lastDriveBackupAt = last;
        _autoBackup = auto;
        _driveLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _driveLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_outlined,
                          color: AppColors.violet, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Keep a copy of everything',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'A backup contains your full database, receipt photos, '
                    'and app preferences in a single zip file. Save it to '
                    'your cloud drive or send it to another device, then '
                    'restore it here any time.',
                    style: TextStyle(
                        color: context.textMuted, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed:
                  _busy ? null : () => _createBackup(context, db),
              icon: const Icon(Icons.backup_outlined),
              label: const Text('Create backup'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed:
                  _busy ? null : () => _restoreFromFile(context, db),
              icon: const Icon(Icons.restore_outlined),
              label: const Text('Restore from file'),
            ),
            const SizedBox(height: 28),
            _driveSection(context, db),
            if (_busy) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_status != null) ...[
              const SizedBox(height: 16),
              Text(
                _status!,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _driveSection(BuildContext context, AppDatabase db) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.cloud_sync_outlined,
                color: AppColors.violet, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Google Drive',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Backups are stored in a private app folder in your Drive — '
          'only this app can see them. The 3 most recent are kept.',
          style: TextStyle(color: context.textMuted, height: 1.5),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Automatically backup',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Backup to Google Drive when entering and exiting '
                    'the application.',
                    style:
                        TextStyle(color: context.textMuted, height: 1.4),
                  ),
                ],
              ),
            ),
            Switch(
              value: _autoBackup,
              onChanged: _busy ? null : (v) => _setAutoBackup(db, v),
            ),
          ],
        ),
        if (_autoBackup) ...[
          const SizedBox(height: 4),
          Text(
            'Warning: This will overwrite the existing auto backup '
            'file every time a backup occurs.',
            style: TextStyle(color: context.textMuted, height: 1.4),
          ),
        ],
        const SizedBox(height: 12),
        if (_driveLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_driveAccountEmail == null) ...[
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _signInToDrive(db),
            icon: const Icon(Icons.login_outlined),
            label: const Text('Sign in with Google'),
          ),
        ] else ...[
          Row(
            children: [
              const Icon(Icons.account_circle_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _driveAccountEmail!,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _signOutOfDrive,
                child: const Text('Sign out'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_driveNeedsReconnect) ...[
            Text(
              'Drive access needs a quick reconnect.',
              style: TextStyle(color: context.textMuted),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _signInToDrive(db),
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Reconnect Google Drive'),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            onPressed: _busy ? null : () => _backUpToDrive(db),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Back up now'),
          ),
          if (_lastDriveBackupAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last backup: ${formatDateTime(_lastDriveBackupAt!.toLocal())}',
              style: TextStyle(color: context.textMuted),
            ),
          ],
          if (_driveBackups != null) ...[
            const SizedBox(height: 8),
            if (_driveBackups!.isEmpty)
              Text(
                'No cloud backups yet.',
                style: TextStyle(color: context.textMuted),
              )
            else
              for (final backup in _driveBackups!)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_zip_outlined),
                  title: Text(formatDateTime(backup.createdAt.toLocal())),
                  subtitle: Text(
                    backup.name == DriveBackupService.autoFileName
                        ? 'Auto backup · ${_formatSize(backup.sizeBytes)}'
                        : _formatSize(backup.sizeBytes),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore_outlined),
                        tooltip: 'Restore this backup',
                        onPressed:
                            _busy ? null : () => _restoreFromDrive(db, backup),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete this backup',
                        onPressed:
                            _busy ? null : () => _deleteDriveBackup(backup),
                      ),
                    ],
                  ),
                ),
          ],
        ],
      ],
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Signs in; returns false when the user cancels or it fails.
  Future<bool> _signInToDrive(AppDatabase db) async {
    setState(() => _status = null);
    try {
      await _drive.signIn();
      await _loadDrive();
      if (_autoBackup) await _runAutoBackupNow(db);
      return true;
    } on DriveException catch (e) {
      setState(() => _status = e.message);
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        // Show the real reason (e.g. a missing client ID or a SHA-1
        // mismatch) instead of a generic failure.
        final detail = e.description;
        setState(() => _status = detail != null && detail.isNotEmpty
            ? 'Sign-in failed: $detail'
            : 'Sign-in failed. Please try again.');
      }
    } catch (_) {
      setState(() => _status = 'Sign-in failed. Please try again.');
    }
    return false;
  }

  Future<void> _setAutoBackup(AppDatabase db, bool value) async {
    if (value && !_drive.isSignedIn) {
      // Auto backup needs a session: enabling it starts sign-in. If
      // sign-in doesn't complete, the toggle stays off.
      if (!await _signInToDrive(db)) return;
    }
    await _drive.setAutoBackupEnabled(value);
    if (!mounted) return;
    setState(() => _autoBackup = value);
    if (value && _drive.isSignedIn) await _runAutoBackupNow(db);
  }

  /// Immediate auto backup with user feedback (the lifecycle-triggered
  /// ones run silently in the service).
  Future<void> _runAutoBackupNow(AppDatabase db) async {
    setState(() {
      _busy = true;
      _status = 'Backing up to Google Drive…';
    });
    try {
      final backup = await _drive.backUpAuto(db);
      final backups = await _drive.listBackups();
      if (!mounted) return;
      setState(() {
        _driveBackups = backups;
        _lastDriveBackupAt = backup.createdAt;
        _status = 'Backup saved to Google Drive.';
      });
    } on DriveException catch (e) {
      setState(() => _status = e.message);
    } catch (_) {
      setState(() => _status = 'Drive backup failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOutOfDrive() async {
    await _drive.signOut();
    // Signing out also ends auto backup — it needs the session.
    await _drive.setAutoBackupEnabled(false);
    if (!mounted) return;
    setState(() {
      _driveAccountEmail = null;
      _driveNeedsReconnect = false;
      _driveBackups = null;
      _lastDriveBackupAt = null;
      _autoBackup = false;
      _status = null;
    });
  }

  Future<void> _backUpToDrive(AppDatabase db) async {
    setState(() {
      _busy = true;
      _status = 'Backing up to Google Drive…';
    });
    try {
      final backup = await _drive.backUpNow(db);
      final backups = await _drive.listBackups();
      if (!mounted) return;
      setState(() {
        _driveBackups = backups;
        _lastDriveBackupAt = backup.createdAt;
        _status = 'Backup saved to Google Drive.';
      });
    } on DriveException catch (e) {
      setState(() => _status = e.message);
    } catch (_) {
      setState(() => _status = 'Drive backup failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreFromDrive(
      AppDatabase db, DriveBackup backup) async {
    setState(() {
      _busy = true;
      _status = 'Downloading backup…';
    });
    final File file;
    try {
      file = await _drive.downloadBackup(backup);
    } on DriveException catch (e) {
      setState(() {
        _busy = false;
        _status = e.message;
      });
      return;
    } catch (_) {
      setState(() {
        _busy = false;
        _status = 'Download failed. Please try again.';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _confirmAndRestore(db, file);
  }

  Future<void> _deleteDriveBackup(DriveBackup backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete cloud backup?'),
        content: Text(
          'The backup from ${formatDateTime(backup.createdAt.toLocal())} '
          'will be permanently deleted from Google Drive.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.expense),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _drive.deleteBackup(backup.id);
      final backups = await _drive.listBackups();
      if (!mounted) return;
      setState(() {
        _driveBackups = backups;
        _status = 'Cloud backup deleted.';
      });
    } on DriveException catch (e) {
      setState(() => _status = e.message);
    } catch (_) {
      setState(() => _status = 'Delete failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createBackup(
      BuildContext context, AppDatabase db) async {
    setState(() {
      _busy = true;
      _status = 'Creating backup…';
    });
    try {
      final file = await BackupService.createBackup(db);
      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          text: 'Dmoney Manager backup',
          files: [XFile(file.path)],
        ),
      );
      setState(() => _status = 'Backup ready — save it somewhere safe.');
    } catch (e) {
      setState(() => _status = 'Backup failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreFromFile(
      BuildContext context, AppDatabase db) async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (picked == null || picked.path == null) return;
    if (!context.mounted) return;
    await _confirmAndRestore(db, File(picked.path!));
  }

  /// Confirm dialog + the restore itself, shared by the file picker
  /// and Google Drive restore paths.
  Future<void> _confirmAndRestore(AppDatabase db, File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'This replaces ALL current data — transactions, wallets, '
          'budgets, debts, photos, and settings — with the backup. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.expense),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _status = 'Restoring…';
    });
    try {
      await BackupService.restoreBackup(db, file);
      // Prefs were restored too — re-read the cached ones.
      ref.invalidate(themeModeProvider);
      ref.invalidate(lockEnabledProvider);
      ref.invalidate(displayNameProvider);
      ref.invalidate(selectedAccountProvider);
      setState(() => _status =
          'Restore complete. Your data is back.');
    } on BackupException catch (e) {
      setState(() => _status = e.message);
    } catch (_) {
      setState(() => _status =
          'Restore failed. Please try again with a valid backup file.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
