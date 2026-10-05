import 'dart:io';

import 'package:dmoney_manager/core/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

/// Serves [payload] over HTTP, optionally honoring `Range: bytes=N-`
/// with a 206 partial response.
class _RangeServer {
  _RangeServer(this.payload, {this.honorRange = true});

  final List<int> payload;
  final bool honorRange;
  late final HttpServer _server;
  int hits = 0;

  Future<Uri> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((req) async {
      hits++;
      final range = req.headers.value('range');
      final m = range == null
          ? null
          : RegExp(r'bytes=(\d+)-').firstMatch(range);
      if (honorRange && m != null) {
        final start = int.parse(m.group(1)!);
        final remaining = payload.sublist(start);
        req.response.statusCode = HttpStatus.partialContent;
        req.response.headers.set('content-range',
            'bytes $start-${payload.length - 1}/${payload.length}');
        req.response.headers.set('content-length', remaining.length);
        req.response.add(remaining);
      } else {
        req.response.statusCode = HttpStatus.ok;
        req.response.headers.set('content-length', payload.length);
        req.response.add(payload);
      }
      await req.response.close();
    });
    return Uri.parse(
        'http://${_server.address.host}:${_server.port}/app.apk');
  }

  Future<void> stop() => _server.close(force: true);
}

/// Fake HTTP client that drips [payload] in three chunks ~700 ms apart.
/// Unlike a loopback [HttpServer] (which buffers the whole body until
/// close), this genuinely delivers separate chunk events, so the
/// speedometer has something to measure mid-download.
class _DripClient extends http.BaseClient {
  _DripClient(this.payload, {required this.onHit});

  final List<int> payload;
  final void Function() onHit;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    onHit();
    Stream<List<int>> drip() async* {
      yield payload.sublist(0, 1024);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      yield payload.sublist(1024, 2048);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      yield payload.sublist(2048);
    }

    return http.StreamedResponse(
      drip(),
      200,
      contentLength: payload.length,
      request: request,
    );
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('upd_resume_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('formatSpeed uses B/s, KB/s and MB/s', () {
    expect(formatSpeed(0), '0 B/s');
    expect(formatSpeed(850), '850 B/s');
    expect(formatSpeed(1536), '1.5 KB/s');
    expect(formatSpeed(1024 * 1024), '1.0 MB/s');
    expect(formatSpeed(2.5 * 1024 * 1024), '2.5 MB/s');
  });

  test('fresh download writes the full file', () async {
    final payload = List<int>.generate(1024, (i) => i % 256);
    final server = _RangeServer(payload);
    final url = (await server.start()).toString();
    try {
      var lastProgress = -1.0;
      await downloadApk(url, '9.9.1',
          onProgress: (p) => lastProgress = p.fraction);
      final file = File('${tempDir.path}/dmoney-manager-9.9.1.apk');
      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), payload);
      expect(lastProgress, 1.0);
      expect(server.hits, 1);
    } finally {
      await server.stop();
    }
  });

  test('interrupted download resumes instead of restarting', () async {
    final payload = List<int>.generate(2048, (i) => i % 256);
    final server = _RangeServer(payload);
    final url = (await server.start()).toString();
    try {
      // Simulate an interrupted download: half the bytes in the .part file.
      final part = File('${tempDir.path}/dmoney-manager-9.9.2.apk.part');
      await part.writeAsBytes(payload.sublist(0, 1024));

      var lastProgress = -1.0;
      await downloadApk(url, '9.9.2',
          onProgress: (p) => lastProgress = p.fraction);

      final file = File('${tempDir.path}/dmoney-manager-9.9.2.apk');
      expect(await file.readAsBytes(), payload);
      expect(lastProgress, 1.0);
      // One ranged request; the first 1024 bytes were NOT re-downloaded.
      expect(server.hits, 1);
    } finally {
      await server.stop();
    }
  });

  test('falls back to a fresh download when the server ignores Range',
      () async {
    final payload = List<int>.generate(1024, (i) => i % 256);
    final server = _RangeServer(payload, honorRange: false);
    final url = (await server.start()).toString();
    try {
      final part = File('${tempDir.path}/dmoney-manager-9.9.3.apk.part');
      await part.writeAsBytes(payload.sublist(0, 512));

      await downloadApk(url, '9.9.3', onProgress: (_) {});

      final file = File('${tempDir.path}/dmoney-manager-9.9.3.apk');
      // Full 1024 bytes, not 512 + 1024 of duplicated content.
      expect(await file.readAsBytes(), payload);
    } finally {
      await server.stop();
    }
  });

  test('a second request attaches to the in-flight download', () async {
    final payload = List<int>.generate(4096, (i) => i % 256);
    var hits = 0;
    final client = _DripClient(payload, onHit: () => hits++);
    const url = 'https://example.com/dmoney-manager-9.9.4.apk';
    final progressA = <DownloadProgress>[];
    final progressB = <DownloadProgress>[];
    // Back-to-back: the second call must attach to the first instead of
    // starting a competing download (registration is synchronous).
    final a = downloadApk(url, '9.9.4',
        onProgress: progressA.add, client: client);
    final b = downloadApk(url, '9.9.4',
        onProgress: progressB.add, client: client);
    await Future.wait([a, b]);

    final file = File('${tempDir.path}/dmoney-manager-9.9.4.apk');
    expect(await file.readAsBytes(), payload);
    // Only one actual HTTP download happened — no competing writer.
    expect(hits, 1);
    // The late attacher still saw progress updates.
    expect(progressB, isNotEmpty);
    expect(progressA.last.fraction, 1.0);
    // Both the direct downloader and the attacher observed a speed.
    expect(progressA.any((p) => p.bytesPerSecond > 0), isTrue);
    expect(progressB.any((p) => p.bytesPerSecond > 0), isTrue);
  });
}
