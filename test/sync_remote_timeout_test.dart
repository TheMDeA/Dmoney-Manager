/// A stalled Supabase request must end the sync cycle with a
/// named failure, never hang it forever (first sync on a fresh
/// device, 2026-11-23: "Syncing..." spun with no error, no log row
/// and a frozen pending count — the Dart http client has no
/// default timeout, and the launch pull's 30 s wrapper was the
/// only timeout in the sync path).
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dmoney_manager/core/services/sync_failure_mode.dart';
import 'package:dmoney_manager/core/services/sync_remote.dart';

/// An http client whose requests never answer — the shape of a
/// stalled connection (captive portal, blackholed route, weak
/// signal), not a refused one.
class _HangingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Completer<http.StreamedResponse>().future;
}

void main() {
  test('a stalled upsert times out instead of hanging the cycle', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'fake-anon-key',
      httpClient: _HangingHttpClient(),
    );
    final remote = SupabaseSyncRemote(
      client,
      const Duration(milliseconds: 100),
    );
    Object? error;
    try {
      await remote.upsert('categories', [
        {'sync_id': 'x', 'owner_id': 'u', 'name': 'Food'},
      ]);
    } catch (e) {
      error = e;
    }
    expect(error, isA<SyncFatalException>());
    expect(error.toString(), contains('timed out'));
    expect(
      classifySyncError(error),
      SyncFailureMode.offline,
      reason: 'a timeout must read as offline, so the UI offers a retry',
    );
  });

  test('a stalled device list times out the same way', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'fake-anon-key',
      httpClient: _HangingHttpClient(),
    );
    final remote = SupabaseSyncRemote(
      client,
      const Duration(milliseconds: 100),
    );
    await expectLater(
      remote.listDevices(),
      throwsA(
        isA<SyncFatalException>().having(
          (e) => e.message,
          'message',
          contains('timed out'),
        ),
      ),
    );
  });
}
