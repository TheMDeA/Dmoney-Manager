import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/services/supabase_auth_service.dart';
import 'package:dmoney_manager/core/services/sync_devices.dart';
import 'package:dmoney_manager/core/services/sync_failure_mode.dart';
import 'package:dmoney_manager/core/services/sync_initial_push.dart';
import 'package:dmoney_manager/core/services/sync_photos.dart';
import 'package:dmoney_manager/core/services/sync_prefs.dart';
import 'package:dmoney_manager/core/services/sync_pull_service.dart';
import 'package:dmoney_manager/core/services/sync_push_service.dart';
import 'package:dmoney_manager/core/services/sync_remote.dart';
import 'package:dmoney_manager/core/services/sync_row_failure.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// One sync cycle's outcome: the push counts, the pull counts, the
/// prefs round, and any fatal error. The Settings status UI reads
/// this; the cycle itself never throws for remote failures — they
/// land here (and in [AppPrefs.syncLastError]) instead.
class SyncCycleResult {
  const SyncCycleResult({
    required this.push,
    required this.pull,
    this.prefs = const SyncPrefsResult(),
    this.notSignedIn = false,
  });

  /// Signed-out cycle: nothing ran, nothing failed.
  const SyncCycleResult.signedOut()
    : push = const SyncPushResult(notSignedIn: true),
      pull = const SyncPullResult(notSignedIn: true),
      prefs = const SyncPrefsResult(),
      notSignedIn = true;

  final SyncPushResult push;
  final SyncPullResult pull;
  final SyncPrefsResult prefs;
  final bool notSignedIn;

  /// True when either half failed (a fatal error or per-row
  /// failures) — the pending outbox count in Settings is what the
  /// user acts on next.
  bool get hasFailures => push.hasFailures || pull.hasFailures;

  /// The fatal error of either half, if any.
  Object? get error => push.error ?? pull.error;

  /// The first row that failed in either half, when any did
  /// (audit #15/#25) — push first, since it runs first.
  SyncRowFailure? get firstFailure => push.firstFailure ?? pull.firstFailure;

  /// Rows deliberately left queued by either half this run.
  int get skipped => push.skipped + pull.skipped;

  /// Rows upserted or tombstoned on the server.
  int get pushed => push.pushed;

  /// Server rows applied locally (inserts + updates + tombstones).
  int get pulled => pull.applied + pull.tombstoned;
}

/// `syncNow()` (P5): one push-then-pull cycle, plus the prefs
/// round and the device heartbeat. The ordering is the contract
/// P3's pull relies on (§6): pending local edits are pushed first,
/// so the pull never overwrites an edit this device hasn't sent
/// yet. Prefs sync last (they are not in the outbox) and the
/// heartbeat runs only after a clean cycle.
///
/// Single-flight: a second call while a cycle runs joins the
/// running one instead of starting a second cycle — the triggers
/// (launch, resume, connectivity regain, save-debounce) can all
/// fire at once without stacking cycles.
///
/// The signed-in user is read fresh on every cycle (a sign-in or
/// sign-out between cycles changes the next one). Signed out, the
/// cycle is a silent no-op.
class SyncOrchestrator {
  SyncOrchestrator({
    required this.db,
    SyncRemote? remote,
    SyncRemote Function()? remoteFactory,
    SyncPrefsService? prefsService,
    SyncDeviceService? deviceService,
    SyncInitialPushService? initialPushService,
    PhotoUploadGate? photoGate,
    String? Function()? currentUserId,
  }) : _remoteFactory =
             remoteFactory ?? (() => remote ?? SupabaseSyncRemote()),
       _prefsService = prefsService,
       _deviceService = deviceService,
       _initialPushService = initialPushService,
       _photoGate = photoGate,
       _getCurrentUserId =
           currentUserId ?? (() => SupabaseAuthService.currentUserId);

  final AppDatabase db;

  /// The remote for this cycle — built lazily through the factory
  /// so a failed Supabase init (no client yet) never crashes
  /// construction. The default factory builds the real
  /// [SupabaseSyncRemote]; tests pass a fake remote instead.
  /// Only invoked once a cycle has confirmed a signed-in user.
  final SyncRemote Function() _remoteFactory;
  SyncRemote get remote => _remoteFactory();

  SyncPrefsService? _prefsService;
  SyncDeviceService? _deviceService;
  SyncInitialPushService? _initialPushService;
  final PhotoUploadGate? _photoGate;

  /// The prefs service, built on first use (lazily, like [remote]).
  SyncPrefsService get prefsService =>
      _prefsService ??= SyncPrefsService(remote: remote);

  /// The device service, built on first use (lazily, like [remote]).
  SyncDeviceService get deviceService =>
      _deviceService ??= SyncDeviceService(remote: remote);

  /// The chunked initial-push service (P6), built on first use.
  SyncInitialPushService get initialPushService =>
      _initialPushService ??= SyncInitialPushService(
        db: db,
        remoteFactory: () => remote,
        currentUserId: () => currentUserId,
        photoGate: _photoGate,
      );

  /// True while a chunked initial push is in progress — the
  /// trigger service schedules follow-up cycles until this clears.
  bool get initialPushPending => initialPushService.isActive;

  final String? Function() _getCurrentUserId;

  /// The signed-in user id right now (null when signed out).
  /// Injectable so tests can drive it without Supabase init.
  String? get currentUserId => _getCurrentUserId();

  Future<SyncCycleResult>? _running;

  /// Runs one cycle, or joins the running one when a cycle is
  /// already in flight. Never throws for remote failures.
  Future<SyncCycleResult> syncNow() {
    final running = _running;
    if (running != null) return running;
    final future = _runCycle();
    _running = future;
    future.whenComplete(() {
      if (identical(_running, future)) _running = null;
    });
    return future;
  }

  Future<SyncCycleResult> _runCycle() async {
    final stopwatch = Stopwatch()..start();
    final ownerId = currentUserId;
    if (ownerId == null) return const SyncCycleResult.signedOut();
    // Push first: the pull's conflict gate trusts that anything
    // still in the outbox has already left this device.
    //
    // First sync on this device: rows that predate sync (seed
    // categories, v18-backfilled rows) have no outbox entry — seed
    // the outbox once, so the initial push has something to send
    // (P6). Later cycles only push what changed since.
    //
    // Each step is guarded: a step that throws unexpectedly (a
    // local database error — never a remote one, which the push
    // and pull report in their results) must not kill the cycle.
    // The pull still runs, and the failure is recorded in the
    // result, the named mode, and the log.
    SyncPushResult push;
    try {
      if (!AppPrefs.syncInitialPushSeeded) {
        await db.enqueueAllRowsForInitialPush();
        await AppPrefs.setSyncInitialPushSeeded(true);
      }
      final pending = await db.outboxCount();
      // Once a chunked push starts (the marker is set), every
      // cycle stays on the chunked path until the marker clears
      // — otherwise a small remainder would take the plain drain
      // and the marker would never be cleared.
      push = AppPrefs.syncInitialPushTotal != null ||
              pending > SyncInitialPushService.chunkSize
          ? await initialPushService.pushNextChunk()
          : await SyncPushService(
              db: db,
              remote: remote,
              ownerId: ownerId,
              photoGate: _photoGate,
            ).pushNow();
    } catch (e) {
      // A fatal abort settles nothing: no row was attempted, so
      // nothing failed — the queued rows stay queued and the next
      // cycle retries them. (Counting the still-queued outbox
      // here would double-count them: failed in this run's log
      // and pushed in the next run's.)
      push = SyncPushResult(error: e);
    }
    SyncPullResult pull;
    try {
      pull = await SyncPullService(
        db: db,
        remote: remote,
        ownerId: ownerId,
      ).pullNow();
    } catch (e) {
      pull = SyncPullResult(error: e);
    }
    // Prefs are best-effort and never fail the cycle — including
    // a remote that cannot even be built (Supabase not
    // initialised): the data sync already ran, so a prefs failure
    // is reported, never thrown.
    SyncPrefsResult prefs;
    try {
      prefs = await prefsService.syncPrefs(ownerId);
    } catch (_) {
      prefs = const SyncPrefsResult(serverUnreachable: true);
    }
    // Heartbeat only after a clean cycle — a device that only ever
    // fails should not look freshly seen. Best-effort like prefs:
    // a heartbeat that cannot run must not fail the cycle.
    if (!push.hasFailures && !pull.hasFailures) {
      try {
        await deviceService.heartbeat(ownerId);
      } catch (_) {
        // Best-effort: see above.
      }
    }
    final result = SyncCycleResult(push: push, pull: pull, prefs: prefs);
    // Named failure mode (§12) + raw message for the status UI,
    // and one log row for the run. All best-effort: logging must
    // never fail a cycle.
    //
    // A run with per-row failures but no fatal error is a
    // PARTIAL failure (audit #15): it used to store no mode and
    // clear the last error, so the snackbar rendered "Sync
    // failed: " with nothing after the colon and the status card
    // looked clean. The stored error names the first failing row
    // (audit #25) when the services recorded one.
    final mode = result.error == null
        ? (result.hasFailures ? SyncFailureMode.partial : null)
        : classifySyncError(result.error);
    final modeKey = mode == null ? null : syncFailureModeKey(mode);
    final firstFailure = result.firstFailure;
    final errorText = result.error?.toString() ??
        (firstFailure != null
            ? firstFailure.toString()
            : (result.hasFailures
                ? '${result.push.failed + result.pull.failed} '
                    'rows failed to sync'
                : null));
    try {
      await AppPrefs.setSyncLastError(errorText);
      await AppPrefs.setSyncFailureMode(modeKey);
      await db.recordSyncLog(
        pushed: result.pushed,
        pulled: result.pulled,
        conflicts: result.pull.conflicts,
        failed: result.push.failed + result.pull.failed,
        failureMode: modeKey,
        error: errorText,
        durationMs: stopwatch.elapsedMilliseconds,
        phase: 'both',
        skipped: result.skipped,
        firstFailedTable: firstFailure?.table,
        firstFailedSyncId: firstFailure?.syncId,
      );
    } catch (_) {
      // Best-effort: see above.
    }
    return result;
  }
}
