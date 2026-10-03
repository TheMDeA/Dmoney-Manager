import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/backup_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// Backup & restore: create a zip backup (database + receipt photos +
/// preferences) and share it, or restore one from a file.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  String? _status;

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
            const GlassCard(
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
                        color: AppColors.textMuted, height: 1.5),
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
            if (_busy) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_status != null) ...[
              const SizedBox(height: 16),
              Text(
                _status!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
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
    if (confirmed != true || !context.mounted) return;

    setState(() {
      _busy = true;
      _status = 'Restoring…';
    });
    try {
      await BackupService.restoreBackup(db, File(picked.path!));
      // Prefs were restored too — re-read the cached ones.
      ref.invalidate(themeModeProvider);
      ref.invalidate(lockEnabledProvider);
      ref.invalidate(displayNameProvider);
      ref.invalidate(selectedAccountProvider);
      setState(() => _status =
          'Restore complete. Your data is back.');
    } on BackupException catch (e) {
      setState(() => _status = e.message);
    } catch (e) {
      setState(() => _status = 'Restore failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
