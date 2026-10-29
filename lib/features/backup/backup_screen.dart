import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupTitle)),
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
                          l10n.backupHeroTitle,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    l10n.backupHeroMessage,
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
              label: Text(l10n.backupCreate),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed:
                  _busy ? null : () => _restoreFromFile(context, db),
              icon: const Icon(Icons.restore_outlined),
              label: Text(l10n.backupRestoreFile),
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.cloud_sync_outlined,
                color: AppColors.violet, size: 22),
            const SizedBox(width: 8),
            Text(
              l10n.backupDriveTitle,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.backupDriveMessage,
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
                  Text(
                    l10n.backupAutoTitle,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.backupAutoMessage,
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
            l10n.backupAutoWarning,
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
            label: Text(l10n.backupSignIn),
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
                child: Text(l10n.backupSignOut),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_driveNeedsReconnect) ...[
            Text(
              l10n.backupReconnectNote,
              style: TextStyle(color: context.textMuted),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _signInToDrive(db),
              icon: const Icon(Icons.refresh_outlined),
              label: Text(l10n.backupReconnect),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            onPressed: _busy ? null : () => _backUpToDrive(db),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(l10n.backupNow),
          ),
          if (_lastDriveBackupAt != null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.backupLastBackup(formatDateTime(_lastDriveBackupAt!.toLocal())),
              style: TextStyle(color: context.textMuted),
            ),
          ],
          if (_driveBackups != null) ...[
            const SizedBox(height: 8),
            if (_driveBackups!.isEmpty)
              Text(
                l10n.backupNoCloud,
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
                        ? l10n.backupAutoBackupSize(_formatSize(backup.sizeBytes))
                        : _formatSize(backup.sizeBytes),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore_outlined),
                        tooltip: l10n.backupRestoreTooltip,
                        onPressed:
                            _busy ? null : () => _restoreFromDrive(db, backup),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: l10n.backupDeleteTooltip,
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
    final l10n = AppLocalizations.of(context)!;
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
            ? l10n.backupSignInFailedDetail(detail)
            : l10n.backupSignInFailed);
      }
    } catch (_) {
      setState(() => _status = l10n.backupSignInFailed);
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
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _status = l10n.backupBackingUpDrive;
    });
    try {
      final backup = await _drive.backUpAuto(db);
      final backups = await _drive.listBackups();
      if (!mounted) return;
      setState(() {
        _driveBackups = backups;
        _lastDriveBackupAt = backup.createdAt;
        _status = l10n.backupSavedDrive;
      });
    } on DriveException catch (e) {
      setState(() => _status = e.message);
    } catch (_) {
      setState(() => _status = l10n.backupDriveFailed);
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
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _status = l10n.backupBackingUpDrive;
    });
    try {
      final backup = await _drive.backUpNow(db);
      final backups = await _drive.listBackups();
      if (!mounted) return;
      setState(() {
        _driveBackups = backups;
        _lastDriveBackupAt = backup.createdAt;
        _status = l10n.backupSavedDrive;
      });
    } on DriveException catch (e) {
      setState(() => _status = e.message);
    } catch (_) {
      setState(() => _status = l10n.backupDriveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreFromDrive(
      AppDatabase db, DriveBackup backup) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _status = l10n.backupDownloading;
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
        _status = l10n.backupDownloadFailed;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _confirmAndRestore(db, file);
  }

  Future<void> _deleteDriveBackup(DriveBackup backup) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.backupDeleteTitle),
        content: Text(
          l10n.backupDeleteMessage(formatDateTime(backup.createdAt.toLocal())),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.expense),
            child: Text(l10n.commonDelete),
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
        _status = l10n.backupDeleted;
      });
    } on DriveException catch (e) {
      setState(() => _status = e.message);
    } catch (_) {
      setState(() => _status = l10n.backupDeleteFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createBackup(
      BuildContext context, AppDatabase db) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _status = l10n.backupCreating;
    });
    try {
      final file = await BackupService.createBackup(db);
      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          text: l10n.backupShareText,
          files: [XFile(file.path)],
        ),
      );
      setState(() => _status = l10n.backupReady);
    } catch (e) {
      setState(() => _status = l10n.backupFailed('$e'));
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.backupRestoreTitle),
        content: Text(l10n.backupRestoreMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.expense),
            child: Text(l10n.backupRestoreAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _status = l10n.backupRestoring;
    });
    try {
      await BackupService.restoreBackup(db, file);
      // Prefs were restored too — re-read the cached ones.
      ref.invalidate(themeModeProvider);
      ref.invalidate(lockEnabledProvider);
      ref.invalidate(displayNameProvider);
      ref.invalidate(selectedAccountProvider);
      setState(() => _status = l10n.backupRestoreComplete);
    } on BackupException catch (e) {
      setState(() => _status = e.message);
    } catch (_) {
      setState(() => _status = l10n.backupRestoreFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
