import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import 'package:dmoney_manager/core/services/sync_failure_mode.dart';
import 'package:dmoney_manager/core/services/sync_orchestrator.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// Sync triggers (P5, §6/§13): launch, manual "Sync now", app
/// resume, connectivity regain, and a debounced save trigger.
///
/// What the concept doc leaves open, decided here:
/// - The doc lists launch, resume, after-a-local-save and manual.
///   Connectivity regain is added (the brief's trigger): a cycle
///   that failed while offline should not wait for the next launch.
/// - The save trigger watches the outbox count, not every write
///   site: any local change that enqueues an outbox entry
///   schedules a sync ~2 s after the last change, so a burst of
///   edits (or a bulk delete) runs one cycle, never one per edit.
///   Only growth schedules — the push acking entries (or a
///   pull-side apply, which enqueues nothing) never re-triggers.
/// - A cycle that fails with a transient error (timeout, offline,
///   paused server) retries with backoff — previously nothing
///   re-scheduled it, so a timed-out pull sat dead until a manual
///   resync, a resume, or a local edit. Auth failures and
///   per-row data errors do not retry: the first needs the user,
///   the second fails the same way every time.
/// - The launch sync runs after the first frame (start() is called
///   from a post-frame callback in main) and never blocks startup:
///   a failure lands in the result / the status UI, never in a
///   crash or a spinner. Signed out, every trigger is a silent
///   no-op.
///
/// The orchestrator's single-flight dedupes overlapping triggers —
/// a resume and a regain landing together run one cycle.
class SyncTriggerService with WidgetsBindingObserver {
  SyncTriggerService({
    required this.db,
    required this.orchestrator,
    Duration debounce = const Duration(seconds: 2),
    Duration retryBaseDelay = const Duration(seconds: 10),
    Stream<List<ConnectivityResult>>? connectivityStream,
  }) : _debounce = debounce,
       _retryBaseDelay = retryBaseDelay,
       _connectivityStream =
           connectivityStream ?? Connectivity().onConnectivityChanged;

  final AppDatabase db;
  final SyncOrchestrator orchestrator;

  /// How long to wait after the last trigger event before running
  /// a cycle. Injectable (short in tests).
  final Duration _debounce;

  /// Base delay before retrying a failed cycle; doubled per
  /// consecutive failure, capped at 60 s. Injectable (short in
  /// tests).
  final Duration _retryBaseDelay;

  final Stream<List<ConnectivityResult>> _connectivityStream;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<int>? _outboxSub;
  Timer? _debounceTimer;
  bool _wasOffline = false;
  bool _started = false;

  /// True while a cycle is running. Outbox growth during a cycle
  /// is almost always the sync itself (the P6 initial-push seed
  /// enqueues rows inside syncNow) — it must not schedule a
  /// follow-up cycle of its own. Growth is remembered instead (see
  /// [_growthDuringCycle]) and checked when the cycle ends.
  bool _cycleRunning = false;

  /// Outbox growth seen while a cycle was running. At cycle end, a
  /// follow-up is scheduled only when the outbox is still non-empty
  /// — the seed's rows are pushed by the running cycle, so they
  /// leave nothing behind, while a user edit made mid-cycle does.
  bool _growthDuringCycle = false;

  /// Consecutive trigger-run cycles that ended with failures —
  /// drives the retry backoff. Reset by a clean cycle.
  int _consecutiveFailures = 0;

  /// The last outbox count seen — a cycle is scheduled only when
  /// the count GROWS (a new local change). The push acking entries
  /// shrinks the count, and a pull-side apply never touches the
  /// outbox, so neither re-triggers a cycle of its own.
  int? _lastOutboxCount;

  /// Arms the triggers and runs the launch sync (fire-and-forget).
  /// Call once, from a post-frame callback — never before the first
  /// frame, and never twice.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = _connectivityStream.listen((results) {
      final offline =
          results.isEmpty || results.contains(ConnectivityResult.none);
      if (_wasOffline && !offline) _schedule();
      _wasOffline = offline;
    });
    _outboxSub = db.watchOutboxCount().listen((count) {
      final last = _lastOutboxCount;
      _lastOutboxCount = count;
      // The first emission is the baseline, not a change.
      if (last == null || count <= last) return;
      // Growth during a cycle is the sync itself (the seed) or a
      // user edit made mid-cycle: remember it, do not schedule
      // now — the cycle end decides (see _run).
      if (_cycleRunning) {
        _growthDuringCycle = true;
        return;
      }
      _schedule();
    });
    // Launch sync: runs now (post-frame by the caller).
    unawaited(_run());
  }

  /// Stops all triggers. The app-lifetime service never calls this
  /// in practice; tests use it for cleanup.
  void stop() {
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _outboxSub?.cancel();
    _outboxSub = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _consecutiveFailures = 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  void _schedule() => _scheduleDelayed(_debounce);

  void _scheduleDelayed(Duration delay) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      unawaited(_run());
    });
  }

  /// Retryable failures are the transient ones: offline (a timeout
  /// or transport failure) and a paused server. Auth needs the
  /// user to sign in again, per-row (partial) failures are data
  /// errors that fail the same way every time, and unknown errors
  /// stay manual — retrying any of those would spin forever.
  bool _isRetryable(SyncCycleResult result) {
    final error = result.error;
    if (error == null) return false;
    final mode = classifySyncError(error);
    return mode == SyncFailureMode.offline ||
        mode == SyncFailureMode.serverPaused;
  }

  /// Backoff between retries of a failed cycle: base, doubled per
  /// consecutive failure, capped at 60 s.
  Duration _retryDelay() {
    final shift = min(_consecutiveFailures - 1, 3);
    final ms = min(_retryBaseDelay.inMilliseconds * (1 << shift), 60000);
    return Duration(milliseconds: ms);
  }

  /// One cycle, guarded: signed out is a silent no-op, and the
  /// orchestrator never throws for remote failures (they land in
  /// the result). The try/catch covers programming errors only.
  Future<void> _run() async {
    if (orchestrator.currentUserId == null) return;
    _cycleRunning = true;
    SyncCycleResult? result;
    try {
      result = await orchestrator.syncNow();
    } catch (_) {
      // Never crash the app from a background trigger.
      result = null;
    } finally {
      _cycleRunning = false;
    }
    // A thrown cycle is a programming error, not a sync failure:
    // it neither counts toward the retry backoff nor resets it.
    if (result != null) {
      if (result.hasFailures) {
        _consecutiveFailures++;
      } else {
        _consecutiveFailures = 0;
      }
    }
    Duration? delay;
    // A user edit made mid-cycle left entries the running cycle
    // did not push (its push read the outbox first): follow up.
    // The seed's rows were pushed by the cycle itself, so the
    // outbox is empty and this stays quiet for them.
    if (_growthDuringCycle) {
      _growthDuringCycle = false;
      if (await db.outboxCount() > 0) delay = _debounce;
    }
    // A chunked initial push spans cycles: keep scheduling
    // follow-ups (debounced like any trigger) until the backlog
    // drains. Steady state never has a marker, so this is a
    // no-op outside an initial push.
    if (orchestrator.initialPushPending) delay = _debounce;
    // A failed cycle otherwise schedules nothing — a timed-out
    // pull (or plain push) would sit dead until a manual resync,
    // a resume, or a local edit. Retry transient failures with
    // backoff. A sooner follow-up above already covers the cycle,
    // so the retry only fires when nothing else scheduled one.
    if (delay == null && result != null && _isRetryable(result)) {
      delay = _retryDelay();
    }
    if (delay != null) _scheduleDelayed(delay);
  }
}
