import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_prefs.dart';
import '../../core/services/supabase_auth_service.dart';
import '../../core/services/sync_dead_letters_service.dart';
import '../../core/services/sync_devices.dart';
import '../../core/services/sync_failure_mode.dart';
import '../../core/services/sync_first_run.dart';
import '../../core/services/sync_reset_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// "Online sync" (Settings → Manage): status, Sync now, sign
/// in/out, per-account toggles (idea #3), the device list (idea
/// #2), and the first-run / replace-with-server-copy flow (§11,
/// idea #7 preview).
///
/// The screen reads live state where it can (last sync time and
/// pending count are streams); the last error is read from prefs
/// on build and after each manual sync. Signing in triggers the
/// first-run offer when it applies (local empty, server has data),
/// otherwise a plain sync (initial push / merge).
class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() =>
      _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  bool _syncing = false;
  bool _migrating = false;
  bool _resetting = false;
  String? _lastError;
  SyncFailureMode? _lastFailureMode;
  List<SyncDeviceRow>? _devices;
  bool _devicesFailed = false;

  @override
  void initState() {
    super.initState();
    _lastError = AppPrefs.syncLastError;
    _lastFailureMode = parseSyncFailureMode(AppPrefs.syncFailureMode);
    _loadDevices();
  }

  SyncFirstRunService get _firstRun => SyncFirstRunService(
    db: ref.read(databaseProvider),
    orchestrator: ref.read(syncOrchestratorProvider),
  );

  SyncResetService get _resetService => SyncResetService(
    db: ref.read(databaseProvider),
    orchestrator: ref.read(syncOrchestratorProvider),
  );

  Future<void> _loadDevices() async {
    if (!SupabaseAuthService.isSignedIn) {
      if (mounted) {
        setState(() {
          _devices = null;
          _devicesFailed = false;
        });
      }
      return;
    }
    try {
      final devices = await ref
          .read(syncOrchestratorProvider)
          .deviceService
          .listDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _devicesFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _devices = null;
          _devicesFailed = true;
        });
      }
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      final result = await ref.read(syncOrchestratorProvider).syncNow();
      if (!mounted) return;
      setState(() {
        _lastError = AppPrefs.syncLastError;
        _lastFailureMode = parseSyncFailureMode(AppPrefs.syncFailureMode);
      });
      _loadDevices();
      final l10n = AppLocalizations.of(context)!;
      final message = result.notSignedIn
          ? l10n.syncSettingsNotSignedIn
          : result.hasFailures
          ? l10n.syncSettingsSyncFailed(
              // Never an empty string (audit #15): the old
              // fallback rendered literally "Sync failed: " when
              // a per-row failure left both the mode and the
              // error null. The partial mode now covers that
              // case; the counts are the last-resort fallback.
              _lastFailureMode != null
                  ? _failureModeText(l10n, _lastFailureMode!)
                  : result.error?.toString() ??
                      (result.push.failed + result.pull.failed > 0
                          ? l10n.syncLogFailedPart(
                              result.push.failed + result.pull.failed,
                            )
                          : l10n.syncFailureUnknown),
            )
          // gen-l10n orders parameters alphabetically: (pulled, pushed).
          : l10n.syncSettingsSynced(result.pulled, result.pushed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.prefs.languageChanged
                ? '$message\n${l10n.syncSettingsLanguageDeferred}'
                : message,
          ),
        ),
      );
    } finally {
      // A cycle that throws must never leave the button spinning:
      // the failure is already recorded in the status UI.
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await SupabaseAuthService.signInWithGoogle();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.syncSettingsSignInFailed)),
      );
      return;
    }
    if (!mounted) return;
    setState(() {});
    _loadDevices();
    // First-run offer when it applies; otherwise a plain sync
    // (initial push on a fresh device, merge on an existing one).
    try {
      final check = await _firstRun.checkFirstRun();
      if (!mounted) return;
      if (check.eligible && check.preview != null) {
        _showMigrationDialog(check.preview!, firstRun: true);
        return;
      }
    } catch (_) {
      // Preview failed (offline?) — fall through to a plain sync.
    }
    _syncNow();
  }

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.syncSettingsSignOut),
        content: Text(l10n.syncSettingsSignOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.syncSettingsSignOut),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await SupabaseAuthService.signOut();
    if (!mounted) return;
    setState(() {
      _devices = null;
      _devicesFailed = false;
      _lastError = AppPrefs.syncLastError;
    });
  }

  /// The per-account toggle (idea #3 UI): the pref is null for
  /// "all accounts". Turning one off from "all" stores the
  /// explicit on-list; turning the last off one back on clears
  /// the pref to "all" again.
  Future<void> _setAccountSynced(
    List<Account> all,
    int accountId,
    bool on,
  ) async {
    final current = AppPrefs.syncAccountIds;
    if (on) {
      final next = {...?current, accountId}.toList();
      await AppPrefs.setSyncAccountIds(
        next.length == all.length ? null : next,
      );
    } else {
      final base = current ?? [for (final a in all) a.id];
      final next = base.where((id) => id != accountId).toList();
      await AppPrefs.setSyncAccountIds(next);
    }
    if (mounted) setState(() {});
  }

  void _showMigrationDialog(SyncPreview preview, {required bool firstRun}) {
    final l10n = AppLocalizations.of(context)!;
    final rows = [
      for (final table in SyncFirstRunService.previewTables)
        if (preview.count(table) > 0) (table: table, count: preview.count(table)),
    ];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.syncPreviewTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstRun
                    ? l10n.syncPreviewFirstRunBody
                    : l10n.syncPreviewBody,
              ),
              const SizedBox(height: 12),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${_tableLabel(row.table)}: ${row.count}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                l10n.syncPreviewBackupNote,
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _runMigration();
            },
            child: Text(l10n.syncPreviewConfirm),
          ),
        ],
      ),
    );
  }

  Future<void> _runMigration() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _migrating = true);
    // Generic progress dialog — the migration's steps (backup,
    // wipe, pull, prefs) are quick except the pull, so one
    // message covers them.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(l10n.syncFirstRunRunning)),
          ],
        ),
      ),
    );
    SyncMigrationResult? result;
    Object? error;
    try {
      result = await _firstRun.runMigration();
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // the progress dialog
    setState(() => _migrating = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.syncFirstRunFailed(error?.toString() ?? ''),
          ),
        ),
      );
      return;
    }
    // A pulled language applies immediately here: the first-run /
    // replace screen is the configuration moment, not a running
    // session (see SyncPrefsService).
    if (result.prefs.languageChanged) {
      await ref
          .read(appLocaleProvider.notifier)
          .setLanguage(AppPrefs.languageCode);
    }
    _loadDevices();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.syncFirstRunDone(result.pulled) +
              (result.prefs.languageChanged
                  ? '\n${l10n.syncSettingsLanguageDeferred}'
                  : ''),
        ),
      ),
    );
  }

  /// "Replace this device's data" (manual path): fetch the preview
  /// first, then the same confirm dialog as the first-run offer.
  Future<void> _showReplaceFlow() async {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(l10n.syncPreviewLoading)),
          ],
        ),
      ),
    );
    SyncPreview? preview;
    try {
      preview = await _firstRun.fetchPreview();
    } catch (_) {
      preview = null;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    if (preview == null || preview.total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.syncPreviewEmpty)),
      );
      return;
    }
    _showMigrationDialog(preview, firstRun: false);
  }

  /// "Reset sync data": confirm, then the service backs up
  /// locally, wipes the server, re-enqueues this device's book
  /// and pushes the first chunk. A large book keeps uploading in
  /// background cycles — the result says so, and warns that the
  /// other device must wait for the pending count to hit zero
  /// before it replaces its data.
  Future<void> _showResetFlow() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.syncResetConfirmTitle),
        content: Text(l10n.syncResetConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.syncSettingsResetTitle,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _resetting = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(l10n.syncResetRunning)),
          ],
        ),
      ),
    );
    SyncResetResult? result;
    Object? error;
    try {
      result = await _resetService.runReset();
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // the progress dialog
    setState(() => _resetting = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.syncResetFailed(error?.toString() ?? '')),
        ),
      );
      return;
    }
    _loadDevices();
    if (!mounted) return;
    var message = l10n.syncResetDone(result.queued);
    if (result.wipe.photosAttempted > result.wipe.photosRemoved) {
      message += '\n${l10n.syncResetPhotosLeft}';
    }
    if (result.cycleError != null) {
      message +=
          '\n${l10n.syncSettingsSyncFailed(result.cycleError.toString())}';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(databaseProvider);
    final accounts = ref.watch(accountsStreamProvider);
    final signedIn = SupabaseAuthService.isSignedIn;
    final email = SupabaseAuthService.currentUserEmail;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _sectionHeader(l10n.syncSettingsStatusTitle),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sync_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          signedIn
                              ? l10n.syncSettingsSignedInAs(email ?? '')
                              : l10n.syncSettingsNotSignedIn,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: signedIn ? _signOut : _signIn,
                        child: Text(
                          signedIn
                              ? l10n.syncSettingsSignOut
                              : l10n.syncSettingsSignIn,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder(
                    stream: db.watchSyncState(),
                    builder: (context, snapshot) {
                      final last = snapshot.data?.lastSyncAt;
                      return Text(
                        last == null
                            ? l10n.syncSettingsNeverSynced
                            : l10n.syncSettingsLastSync(formatDateTime(last)),
                        style: TextStyle(color: context.textMuted),
                      );
                    },
                  ),
                  StreamBuilder<int>(
                    stream: db.watchOutboxCount(),
                    builder: (context, snapshot) {
                      final pending = snapshot.data ?? 0;
                      // Chunked initial push (P6): the marker total
                      // is set while the upload runs; progress is
                      // the total minus what is still queued.
                      final total = AppPrefs.syncInitialPushTotal;
                      final uploaded = total == null
                          ? null
                          : (total - pending).clamp(0, total);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pending == 0
                                ? l10n.syncSettingsNoPending
                                : l10n.syncSettingsPendingCount(pending),
                            style: TextStyle(color: context.textMuted),
                          ),
                          if (uploaded != null)
                            Text(
                              l10n.syncSettingsInitialUpload(
                                uploaded,
                                total ?? 0,
                              ),
                              style: TextStyle(color: context.textMuted),
                            ),
                        ],
                      );
                    },
                  ),
                  if (_lastFailureMode != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _failureModeText(l10n, _lastFailureMode!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    )
                  else if (_lastError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.syncSettingsLastError(_lastError!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: signedIn && !_syncing ? _syncNow : null,
                    icon: _syncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(
                      _syncing
                          ? l10n.syncSettingsSyncing
                          : l10n.syncSettingsSyncNow,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _sectionHeader(l10n.syncLogTitle),
          StreamBuilder<List<SyncLogData>>(
            stream: db.watchRecentSyncLog(),
            builder: (context, snapshot) {
              final runs = snapshot.data ?? const [];
              if (runs.isEmpty) {
                return ListTile(title: Text(l10n.syncLogEmpty));
              }
              return Column(
                children: [
                  for (final run in runs)
                    ListTile(
                      // Error icon whenever the run failed — a run
                      // with per-row failures but no fatal error
                      // used to get a check icon despite its
                      // "· N failed" suffix (audit #25).
                      leading: Icon(
                        parseSyncFailureMode(run.failureMode) != null ||
                                run.failed > 0
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                      ),
                      title: Text(_logSummary(l10n, run)),
                      subtitle: Text(
                        run.error == null
                            ? formatDateTime(run.startedAt)
                            : '${formatDateTime(run.startedAt)}\n${run.error}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _showLogDetails(context, run),
                    ),
                ],
              );
            },
          ),
          StreamBuilder<List<SyncDeadLetter>>(
            stream: db.watchDeadLetters(),
            builder: (context, snapshot) {
              final letters = snapshot.data ?? const [];
              if (letters.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(l10n.syncDeadLettersTitle),
                  Text(
                    l10n.syncDeadLettersSubtitle,
                    style: TextStyle(color: context.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  for (final letter in letters)
                    _DeadLetterTile(letter: letter),
                ],
              );
            },
          ),
          if (signedIn) ...[
            _sectionHeader(l10n.syncSettingsAccountsTitle),
            Text(
              l10n.syncSettingsAccountsSubtitle,
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            accounts.when(
              data: (list) => Column(
                children: [
                  for (final account in list)
                    SwitchListTile(
                      title: Text(account.name),
                      value: AppPrefs.isAccountSynced(account.id),
                      onChanged: (v) =>
                          _setAccountSynced(list, account.id, v),
                    ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
            _sectionHeader(l10n.syncSettingsDevicesTitle),
            Text(
              l10n.syncSettingsDevicesSubtitle,
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            if (_devices == null && !_devicesFailed)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (_devicesFailed)
              ListTile(
                title: Text(l10n.syncSettingsDevicesFailed),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadDevices,
                ),
              )
            else if (_devices!.isEmpty)
              ListTile(title: Text(l10n.syncSettingsDevicesEmpty))
            else
              Column(
                children: [
                  for (final device in _devices!)
                    ListTile(
                      leading: const Icon(Icons.smartphone_outlined),
                      title: Text(device.label),
                      subtitle: Text(
                        '${l10n.syncSettingsLastSync(formatDateTime(device.lastSeenAt))}'
                        '${device.appVersion.isNotEmpty ? ' • v${device.appVersion}' : ''}',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: device.isThisDevice
                          ? Chip(
                              label: Text(l10n.syncSettingsThisDevice),
                            )
                          : null,
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _loadDevices,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(l10n.syncSettingsRefreshDevices),
                    ),
                  ),
                ],
              ),
            _sectionHeader(l10n.syncSettingsReplaceTitle),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: Text(l10n.syncSettingsReplaceTitle),
              subtitle: Text(
                l10n.syncSettingsReplaceSubtitle,
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
              trailing: _migrating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _migrating ? null : _showReplaceFlow,
            ),
            _sectionHeader(l10n.syncSettingsResetTitle),
            ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.syncSettingsResetTitle,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              subtitle: Text(
                l10n.syncSettingsResetSubtitle,
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
              trailing: _resetting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: (_resetting || _migrating || !signedIn)
                  ? null
                  : _showResetFlow,
            ),
          ],
        ],
      ),
    );
  }

  /// One log row's summary line (P6): the counts always render —
  /// a failed run used to show only its named failure mode, which
  /// discarded the counts (audit #25). The mode text is appended
  /// when present, so a failed run reads e.g. "0 pushed ·
  /// 0 pulled · 1 failed · Some changes couldn't sync…".
  String _logSummary(AppLocalizations l10n, SyncLogData run) {
    // gen-l10n orders parameters alphabetically: (pulled, pushed).
    var text = l10n.syncLogSummary(run.pulled, run.pushed);
    if (run.failed > 0) text += ' · ${l10n.syncLogFailedPart(run.failed)}';
    if (run.conflicts > 0) {
      text += ' · ${l10n.syncLogConflictsPart(run.conflicts)}';
    }
    final mode = parseSyncFailureMode(run.failureMode);
    if (mode != null) text += ' · ${_failureModeText(l10n, mode)}';
    return text;
  }

  /// One log row's detail view (audit #25): the diagnostic
  /// columns the summary line cannot carry — duration, phase,
  /// skipped count, the first failing row, and the full error.
  /// Labels stay English: this is a diagnostics view, like the
  /// technical table names in [_tableLabel].
  Future<void> _showLogDetails(BuildContext context, SyncLogData run) {
    final duration = run.durationMs == null
        ? '—'
        : run.durationMs! < 1000
            ? '${run.durationMs} ms'
            : '${(run.durationMs! / 1000).toStringAsFixed(1)} s';
    final firstFailed = run.firstFailedTable == null
        ? '—'
        : '${_tableLabel(run.firstFailedTable!)}'
            '${run.firstFailedSyncId == null ? '' : ' • ${run.firstFailedSyncId}'}';
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(formatDateTime(run.startedAt)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_logSummary(AppLocalizations.of(context)!, run)),
              const SizedBox(height: 12),
              Text('Duration: $duration'),
              Text('Phase: ${run.phase ?? '—'}'),
              Text('Skipped: ${run.skipped ?? '—'}'),
              Text('First failed row: $firstFailed'),
              if (run.error != null) ...[
                const SizedBox(height: 12),
                SelectableText(run.error!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
    child: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    ),
  );
}

/// The named failure mode's label (§12, P6): what the user
/// should do next, not what broke internally.
String _failureModeText(AppLocalizations l10n, SyncFailureMode mode) =>
    switch (mode) {
      SyncFailureMode.offline => l10n.syncFailureOffline,
      SyncFailureMode.authExpired => l10n.syncFailureAuthExpired,
      SyncFailureMode.serverPaused => l10n.syncFailureServerPaused,
      SyncFailureMode.unknown => l10n.syncFailureUnknown,
      SyncFailureMode.partial => l10n.syncFailurePartial,
    };

/// Human label for a sync table name. The names are technical
/// identifiers, so they stay English — the surrounding chrome is
/// localised. (Same mapping as the conflicts screen's _tableLabel.)
String _tableLabel(String table) => switch (table) {
  'accounts' => 'Account',
  'wallets' => 'Wallet',
  'categories' => 'Category',
  'transactions' => 'Transaction',
  'transaction_photos' => 'Receipt photo',
  'budgets' => 'Budget',
  'goals' => 'Goal',
  'debts' => 'Debt',
  'debt_payments' => 'Debt payment',
  'goal_deposits' => 'Goal deposit',
  'recurring_transactions' => 'Recurring rule',
  'transaction_templates' => 'Template',
  'category_keywords' => 'Keyword',
  'installment_plans' => 'Installment plan',
  _ => table,
};

/// One parked sync entry (audit #18): a receipt photo whose file
/// is missing on this device. Retry re-queues it (when the file
/// is back); Delete photo removes the photo row itself.
class _DeadLetterTile extends ConsumerStatefulWidget {
  const _DeadLetterTile({required this.letter});

  final SyncDeadLetter letter;

  @override
  ConsumerState<_DeadLetterTile> createState() => _DeadLetterTileState();
}

class _DeadLetterTileState extends ConsumerState<_DeadLetterTile> {
  bool _busy = false;

  Future<void> _retry() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final outcome = await SyncDeadLetterService(
      ref.read(databaseProvider),
    ).retryDeadLetter(widget.letter);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          switch (outcome) {
            SyncDeadLetterService.retryQueued => l10n.syncDeadLetterRetried,
            SyncDeadLetterService.retryStillMissing =>
              l10n.syncDeadLetterStillMissing,
            _ => l10n.syncDeadLetterGone,
          },
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    await SyncDeadLetterService(
      ref.read(databaseProvider),
    ).deleteDeadLetterPhoto(widget.letter);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.syncDeadLetterDeleted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(Icons.broken_image_outlined),
      title: Text(
        widget.letter.reason == 'photo_file_missing'
            ? l10n.syncDeadLetterPhotoMissing
            : _tableLabel(widget.letter.targetTable),
      ),
      subtitle: Text(
        formatDateTime(widget.letter.parkedAt),
        style: TextStyle(color: context.textMuted, fontSize: 12),
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: _retry,
                  child: Text(l10n.syncDeadLetterRetry),
                ),
                TextButton(
                  onPressed: _delete,
                  child: Text(l10n.syncDeadLetterDelete),
                ),
              ],
            ),
    );
  }
}
