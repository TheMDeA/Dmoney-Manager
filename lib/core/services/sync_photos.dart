import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:dmoney_manager/core/services/sync_remote.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// Photo bytes for sync (P4): the Storage object key layout, the
/// Wi-Fi-only upload gate (idea #4), and lazy download.
///
/// Row vs bytes (§9): a `transaction_photos` row syncs like any other
/// row on any connection; only the FILE bytes wait for Wi-Fi on upload.
/// Downloads are lazy — the row applies with [TransactionPhoto.remoteKey]
/// recorded and the local file fetched on demand when the user opens the
/// photo — so a first sync on a new device never stalls on megabytes of
/// receipts. Downloads are never Wi-Fi-gated: opening a photo is an
/// explicit request for it, on whatever connection the user is on.

/// Object key for a receipt photo in the `receipts` bucket. The server
/// row's `path` stores exactly this key, never a device-local path.
String photoObjectKey(String ownerId, String txSyncId, String photoSyncId) =>
    'receipts/$ownerId/$txSyncId/$photoSyncId.jpg';

/// Whether receipt-photo uploads may run right now. Injectable so
/// tests can drive the Wi-Fi gate without a radio.
abstract class PhotoUploadGate {
  Future<bool> get canUploadPhotos;
}

/// The real gate over connectivity_plus (idea #4, v1): Wi-Fi only.
/// Strictly Wi-Fi — ethernet/VPN do not count, and there is no
/// mobile-data toggle yet (a one-line setting later if wanted).
/// [ConnectivityResult.none] is in the list only when offline, so a
/// plain `contains(wifi)` check covers the offline case too.
class ConnectivityPhotoUploadGate implements PhotoUploadGate {
  @override
  Future<bool> get canUploadPhotos async {
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }
}

/// Downloads photo bytes from Storage into their local destination.
class SyncPhotoService {
  SyncPhotoService({required this.db, required this.remote});

  final AppDatabase db;
  final SyncRemote remote;

  /// Makes sure [photo]'s local file exists, downloading its bytes
  /// from Storage when they are missing. Returns true when the local
  /// file exists afterwards. Never throws — a failed download (offline,
  /// revoked access, object gone) just means the photo stays
  /// unavailable, exactly like a photo whose file was deleted locally.
  /// The row already points at its destination ([TransactionPhoto.path]),
  /// so no database write is needed after a download.
  Future<bool> ensureLocalFile(TransactionPhoto photo) async {
    final file = File(photo.path);
    if (await file.exists()) return true;
    final key = photo.remoteKey;
    if (key == null) return false;
    try {
      final bytes = await remote.downloadPhoto(key);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Downloads every synced photo whose local file is missing —
  /// the Settings "Download all receipt photos" action for a new
  /// device (§9). Best-effort per photo: one failure never stops
  /// the rest. Returns how many actually downloaded vs failed
  /// (photos already on this device are skipped, not counted).
  Future<({int downloaded, int failed})> downloadMissingPhotos() async {
    final photos = await (db.select(
      db.transactionPhotos,
    )..where((p) => p.remoteKey.isNotNull())).get();
    var downloaded = 0;
    var failed = 0;
    for (final photo in photos) {
      if (await File(photo.path).exists()) continue;
      if (await ensureLocalFile(photo)) {
        downloaded++;
      } else {
        failed++;
      }
    }
    return (downloaded: downloaded, failed: failed);
  }
}
