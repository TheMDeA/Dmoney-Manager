/// The orchestrator must never be unusable from the way main()
/// builds it — and a cycle must never throw.
///
/// Regression for the first-sync failure on 2026-11-23 (3.0.0):
/// main() builds `SyncOrchestrator(db: db)` with no remote, and the
/// constructor's fallback was `(() => remote!)` — a null check that
/// threw on first use in the release build (the debug assert that
/// would have caught it is compiled out). Every sync step then
/// failed instantly — device list, push, pull — and the cycle threw
/// at the unguarded prefs step, leaving the Settings button stuck
/// on "Syncing..." with no log row and 0 of 1934 rows pushed.
/// The constructor default now builds the real [SupabaseSyncRemote],
/// and the cycle tail (prefs + heartbeat) is guarded.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/services/sync_devices.dart';
import 'package:dmoney_manager/core/services/sync_orchestrator.dart';
import 'package:dmoney_manager/core/services/sync_prefs.dart';
import 'package:dmoney_manager/core/services/sync_remote.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// A prefs service whose round throws — the cycle must report it,
/// never throw it.
class _ThrowingPrefsService extends SyncPrefsService {
  _ThrowingPrefsService() : super(remote: _NoopRemote());

  @override
  Future<SyncPrefsResult> syncPrefs(String ownerId) async {
    throw StateError('prefs unavailable');
  }
}

/// Minimal remote that answers empty/success for every call.
class _NoopRemote implements SyncRemote {
  @override
  Future<void> upsert(String table, List<Map<String, dynamic>> rows) async {}

  @override
  Future<void> tombstone(
    String table,
    List<String> syncIds,
    DateTime deletedAt,
    String ownerId,
  ) async {}

  @override
  Future<List<Map<String, dynamic>>> pull(
    String table,
    String? updatedAfter,
    int offset,
    int limit,
  ) async => [];

  @override
  Future<void> uploadPhoto(String key, File file) async {}

  @override
  Future<Uint8List> downloadPhoto(String key) async => Uint8List(0);

  @override
  Future<void> deletePhotoObject(String key) async {}

  @override
  Future<Map<String, dynamic>?> fetchRow(
    String table,
    String syncId,
  ) async => null;

  @override
  Future<int> countRows(String table) async => 0;

  @override
  Future<void> upsertDevice(Map<String, dynamic> row) async {}

  @override
  Future<List<Map<String, dynamic>>> listDevices() async => [];

  @override
  Future<Map<String, dynamic>?> fetchPrefs() async => null;

  @override
  Future<void> upsertPrefs(Map<String, dynamic> row) async {}

  @override
  Future<ServerWipeResult> wipeServerData(List<String> photoKeys) async =>
      const ServerWipeResult(deletedRows: {}, photosRemoved: 0, photosAttempted: 0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory root;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'fake-anon-key',
    );
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sync_default_remote_test');
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => root.path,
        );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await AppPrefs.init();
  });

  tearDown(() async {
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('an orchestrator built like main() builds the real remote', () {
    final orchestrator = SyncOrchestrator(db: db);
    expect(orchestrator.remote, isA<SupabaseSyncRemote>());
  });

  test('a remote that cannot be built cannot throw the cycle', () async {
    final orchestrator = SyncOrchestrator(
      db: db,
      remoteFactory: () => throw StateError('Supabase not initialised'),
      currentUserId: () => 'test-owner',
    );
    final result = await orchestrator.syncNow();
    expect(result.hasFailures, isTrue);
    expect(result.prefs.serverUnreachable, isTrue);
    expect(result.error, isNotNull);
  });

  test('a throwing prefs round cannot throw the cycle', () async {
    final remote = _NoopRemote();
    final orchestrator = SyncOrchestrator(
      db: db,
      remote: remote,
      currentUserId: () => 'test-owner',
      prefsService: _ThrowingPrefsService(),
      deviceService: SyncDeviceService(
        remote: remote,
        labelProvider: () async => 'Test Phone',
        appVersionProvider: () async => '3.0.0',
      ),
    );
    final result = await orchestrator.syncNow();
    expect(result.hasFailures, isFalse);
    expect(result.prefs.serverUnreachable, isTrue);
  });
}
