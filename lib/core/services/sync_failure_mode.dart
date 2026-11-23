import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_remote.dart';

/// Named sync failure modes (§12, P6): the status UI shows one of
/// these instead of a raw error string, so the user knows what to
/// do next instead of what broke internally.
///
/// The mapping is best-effort — the client can only see what the
/// error carries. Two signals are reliable: auth rejections
/// (401/403) and the HTTP 503 a paused project answers with. A
/// transport failure while the device is online has the same shape
/// as a paused project, so a refused connection is also read as
/// paused. When in doubt the mode is `offline` for transport
/// failures (retrying is the right action either way) and
/// `unknown` for anything unrecognised.
enum SyncFailureMode {
  /// No connection to the server (or a timeout) — will retry.
  offline,

  /// The Supabase session was rejected (401/403) — sign in again.
  authExpired,

  /// The server answered that it is unavailable (502/503/504) or
  /// refused the connection — the free-tier project is paused;
  /// open the Supabase dashboard to resume it.
  serverPaused,

  /// Something else failed; the raw message is kept in the log.
  unknown,

  /// Some rows failed while the run itself completed — a per-row
  /// (partial) failure with no fatal error (audit #15). The run
  /// is not clean, but nothing aborted it; the log names the
  /// first failing row and the status line points at it.
  partial,
}

/// The storage key for a mode (its enum name).
String syncFailureModeKey(SyncFailureMode mode) => mode.name;

/// Parses a stored mode key, or null when it is absent or unknown.
SyncFailureMode? parseSyncFailureMode(String? raw) {
  if (raw == null) return null;
  for (final mode in SyncFailureMode.values) {
    if (mode.name == raw) return mode;
  }
  return null;
}

/// Maps a sync error to its named mode. Walks the cause chain of
/// [SyncFatalException] first — the orchestrator's fatal errors
/// wrap the underlying PostgREST / auth / transport failure —
/// then classifies the leaf error by type, and falls back to
/// message heuristics for anything else. Never throws.
SyncFailureMode classifySyncError(Object? error) {
  if (error == null) return SyncFailureMode.unknown;
  if (error is SyncFatalException) {
    final cause = error.cause;
    if (cause != null) return classifySyncError(cause);
    return _modeFromMessage(error.message);
  }
  if (error is AuthException) return SyncFailureMode.authExpired;
  if (error is PostgrestException) {
    final code = int.tryParse(error.code ?? '');
    if (code == 401 || code == 403) return SyncFailureMode.authExpired;
    if (code == 502 || code == 503 || code == 504) {
      return SyncFailureMode.serverPaused;
    }
    return _modeFromMessage(error.message);
  }
  if (error is StorageException) {
    if (error.statusCode == '401' || error.statusCode == '403') {
      return SyncFailureMode.authExpired;
    }
    if (error.statusCode == '502' ||
        error.statusCode == '503' ||
        error.statusCode == '504') {
      return SyncFailureMode.serverPaused;
    }
    return _modeFromMessage(error.message);
  }
  if (error is SocketException) {
    final message = error.message;
    if (message.contains('Failed host lookup') ||
        message.contains('Network is unreachable')) {
      return SyncFailureMode.offline;
    }
    // DNS resolved but the host refused the connection — the
    // server side is down, which for a free-tier project means
    // paused (see the module doc).
    if (message.contains('Connection refused')) {
      return SyncFailureMode.serverPaused;
    }
    return SyncFailureMode.offline;
  }
  if (error is TimeoutException || error is http.ClientException) {
    return SyncFailureMode.offline;
  }
  return _modeFromMessage(error.toString());
}

/// Message heuristics for errors without a recognisable type.
/// Checked in order: paused first (the rarest, most specific
/// word), then auth, then transport.
SyncFailureMode _modeFromMessage(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('paused')) return SyncFailureMode.serverPaused;
  if (lower.contains('auth') ||
      lower.contains('sign-in') ||
      lower.contains('sign in') ||
      lower.contains('401') ||
      lower.contains('403')) {
    return SyncFailureMode.authExpired;
  }
  if (lower.contains('no connection') ||
      lower.contains('timed out') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable')) {
    return SyncFailureMode.offline;
  }
  return SyncFailureMode.unknown;
}
