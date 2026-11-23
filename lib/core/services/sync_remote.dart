import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// The server calls the push needs, behind an interface so tests can
/// substitute a fake — no real network in tests.
abstract class SyncRemote {
  /// Upserts [rows] into [table] by `sync_id` (insert or update).
  /// Every row must carry `sync_id` and `owner_id`.
  Future<void> upsert(String table, List<Map<String, dynamic>> rows);

  /// Marks the server rows with these sync ids as deleted
  /// (`deleted_at` set) — sync never hard-deletes server rows.
  Future<void> tombstone(
    String table,
    List<String> syncIds,
    DateTime deletedAt,
  );

  /// Fetches one page of rows from [table] with
  /// `server_updated_at` strictly greater than [updatedAfter]
  /// (null fetches from the beginning), ordered by
  /// `server_updated_at` then `sync_id`, both ascending.
  /// [offset]/[limit] page through that ordered set (offset is
  /// zero-based, limit is the page size). Returns the raw server
  /// rows (snake_case, `sync_id` identity, `server_updated_at`
  /// included). Throws [SyncFatalException] for auth/transport
  /// failures, like the push calls.
  Future<List<Map<String, dynamic>>> pull(
    String table,
    String? updatedAfter,
    int offset,
    int limit,
  );

  /// Uploads one receipt photo's bytes to the `receipts` bucket at
  /// [key] (the Storage object key, never a local path). The file is read by the Storage client (one
  /// in-memory copy, never pre-read by the caller); `upsert: true`
  /// so a retry after a partial failure overwrites instead of
  /// 409-ing. Throws [SyncFatalException] for auth/transport
  /// failures; other Storage errors rethrow unchanged.
  Future<void> uploadPhoto(String key, File file);

  /// Downloads one receipt photo's bytes from the `receipts`
  /// bucket. Throws [SyncFatalException] for auth/transport
  /// failures; a missing object (404) rethrows as a
  /// [StorageException] for the caller to treat as "unavailable".
  Future<Uint8List> downloadPhoto(String key);

  /// Deletes one object from the `receipts` bucket. Best-effort:
  /// a missing object is a no-op, and the caller never lets a
  /// failure here fail a pull/push run. Throws
  /// [SyncFatalException] for auth/transport failures.
  Future<void> deletePhotoObject(String key);

  /// Fetches one server row by sync id, or null when absent. Used
  /// by the photo tombstone path to recover the Storage object key
  /// of a deleted photo (the local row — and its key — is gone by
  /// push time, so the server row is the only place it survives).
  Future<Map<String, dynamic>?> fetchRow(String table, String syncId);

  /// Counts the live (non-deleted) rows of [table] — the sync
  /// preview (P5, idea #7) shows these before a first-run wipe so
  /// the user sees what will arrive. Throws [SyncFatalException]
  /// for auth/transport failures.
  Future<int> countRows(String table);

  /// Upserts one row of the `devices` heartbeat table, keyed by
  /// `device_id` (not `sync_id` — devices has no sync id). A
  /// heartbeat only; no app data flows through it.
  Future<void> upsertDevice(Map<String, dynamic> row);

  /// Lists the signed-in owner's device rows, newest heartbeat
  /// first, for the Settings device list (P5, idea #2).
  Future<List<Map<String, dynamic>>> listDevices();

  /// Fetches the owner's single `sync_prefs` row (currency +
  /// language), or null when prefs were never synced (P5, §7).
  Future<Map<String, dynamic>?> fetchPrefs();

  /// Upserts the owner's `sync_prefs` row, keyed by `owner_id`.
  Future<void> upsertPrefs(Map<String, dynamic> row);
}

/// Thrown (or wrapped) by the remote for errors that must abort the
/// whole push run: auth failures and transport failures. Anything
/// else — a bad row, a foreign-key violation — is a data error: the
/// push falls back to per-row upserts so one bad row cannot block
/// the rest of the queue.
class SyncFatalException implements Exception {
  SyncFatalException(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() => 'SyncFatalException: $message';
}

/// The real remote, over the Supabase REST client.
class SupabaseSyncRemote implements SyncRemote {
  SupabaseSyncRemote([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<void> upsert(String table, List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return Future.value();
    return _guard<void>(
      () => _client.from(table).upsert(rows, onConflict: 'sync_id'),
    );
  }

  @override
  Future<void> tombstone(
    String table,
    List<String> syncIds,
    DateTime deletedAt,
  ) {
    if (syncIds.isEmpty) return Future.value();
    final stamp = deletedAt.toUtc().toIso8601String();
    return _guard<void>(
      () => _client.from(table).upsert(
        [
          for (final id in syncIds)
            {'sync_id': id, 'deleted_at': stamp},
        ],
        onConflict: 'sync_id',
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> pull(
    String table,
    String? updatedAfter,
    int offset,
    int limit,
  ) async {
    // Filters first, then order/range: PostgrestFilterBuilder
    // carries the filters; order() and range() live on the
    // transform builder it extends, and order() appends, so the
    // two order() calls compose into one `order` parameter.
    // `order` defaults to descending — ascending must be explicit.
    var query = _client.from(table).select();
    if (updatedAfter != null) {
      query = query.gt('server_updated_at', updatedAfter);
    }
    final data = await _guard(
      () => query
          .order('server_updated_at', ascending: true)
          .order('sync_id', ascending: true)
          .range(offset, offset + limit - 1),
    );
    return List<Map<String, dynamic>>.from(data);
  }

  @override
  Future<void> uploadPhoto(String key, File file) {
    // The Storage client reads the file itself (one in-memory copy)
    // and derives the content type from the extension when
    // fileOptions.contentType is left null. upsert: true so a retry
    // after a partial failure overwrites instead of 409-ing.
    return _guard<void>(
      () => _client.storage.from('receipts').upload(
        key,
        file,
        fileOptions: const FileOptions(upsert: true),
      ),
    );
  }

  @override
  Future<Uint8List> downloadPhoto(String key) {
    return _guard<Uint8List>(
      () => _client.storage.from('receipts').download(key),
    );
  }

  @override
  Future<void> deletePhotoObject(String key) {
    return _guard<void>(
      () => _client.storage.from('receipts').remove([key]),
    );
  }

  @override
  Future<Map<String, dynamic>?> fetchRow(String table, String syncId) async {
    final data = await _guard(
      () => _client
          .from(table)
          .select()
          .eq('sync_id', syncId)
          .maybeSingle(),
    );
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<int> countRows(String table) async {
    // Exact count, no data: limit(0) returns an empty page while
    // the count still reflects every row the filters match (the
    // count ignores limit/range modifiers). Tombstones don't count
    // — the preview shows what will actually arrive.
    final res = await _guard(
      () => _client
          .from(table)
          .select('sync_id')
          .isFilter('deleted_at', null)
          .limit(0)
          .count(CountOption.exact),
    );
    return res.count;
  }

  @override
  Future<void> upsertDevice(Map<String, dynamic> row) {
    return _guard<void>(
      () => _client.from('devices').upsert(row, onConflict: 'device_id'),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> listDevices() async {
    // RLS restricts the rows to this owner; the order puts the
    // most recently seen device first.
    final data = await _guard(
      () => _client
          .from('devices')
          .select('device_id,label,last_seen_at,app_version')
          .order('last_seen_at', ascending: false),
    );
    return List<Map<String, dynamic>>.from(data);
  }

  @override
  Future<Map<String, dynamic>?> fetchPrefs() async {
    // One row per owner (owner_id is the primary key); RLS
    // restricts the query to this owner, so maybeSingle is safe.
    final data = await _guard(
      () => _client.from('sync_prefs').select().maybeSingle(),
    );
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<void> upsertPrefs(Map<String, dynamic> row) {
    return _guard<void>(
      () => _client.from('sync_prefs').upsert(row, onConflict: 'owner_id'),
    );
  }

  /// Runs a Supabase call, classifying failures: auth (401/403) and
  /// transport errors abort the run; data errors (PostgREST 400/409,
  /// FK violations, …) rethrow unchanged for the per-row fallback.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PostgrestException catch (e) {
      final code = int.tryParse(e.code ?? '');
      if (code == 401 || code == 403) {
        throw SyncFatalException(
          'Supabase rejected the request (${e.code}): ${e.message}',
          e,
        );
      }
      // The service is unavailable (502/503/504 — a paused
      // free-tier project answers 503): abort the run like any
      // other transport failure. Retrying per row would fail the
      // same way, and the named failure mode (§12) names it.
      if (code == 502 || code == 503 || code == 504) {
        throw SyncFatalException(
          'Supabase is unavailable (${e.code}): ${e.message}',
          e,
        );
      }
      rethrow;
    } on AuthException catch (e) {
      throw SyncFatalException('Supabase auth failed: ${e.message}', e);
    } on StorageException catch (e) {
      // Storage errors carry the HTTP status as a string ('401',
      // '403', '404', …). Auth failures abort the run like the
      // PostgREST ones above; anything else (missing object,
      // conflict, …) is a data error for the caller to handle.
      if (e.statusCode == '401' || e.statusCode == '403') {
        throw SyncFatalException(
          'Supabase Storage rejected the request (${e.statusCode}): ${e.message}',
          e,
        );
      }
      if (e.statusCode == '502' ||
          e.statusCode == '503' ||
          e.statusCode == '504') {
        throw SyncFatalException(
          'Supabase Storage is unavailable (${e.statusCode}): ${e.message}',
          e,
        );
      }
      rethrow;
    } on SocketException catch (e) {
      throw SyncFatalException('No connection to Supabase: $e', e);
    } on TimeoutException catch (e) {
      throw SyncFatalException('Supabase request timed out: $e', e);
    } on http.ClientException catch (e) {
      throw SyncFatalException('Supabase request failed: $e', e);
    }
  }
}
