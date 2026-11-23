import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Canonical JSON for a server payload: keys sorted alphabetically,
/// so the same row always hashes the same way regardless of map
/// insertion order. Payloads are flat (string/int/double/bool/null
/// values only), so one level of sorting is enough.
String canonicalJson(Map<String, dynamic> payload) {
  final keys = payload.keys.toList()..sort();
  final buffer = StringBuffer('{');
  for (var i = 0; i < keys.length; i++) {
    if (i > 0) buffer.write(',');
    buffer.write(jsonEncode(keys[i]));
    buffer.write(':');
    buffer.write(jsonEncode(payload[keys[i]]));
  }
  buffer.write('}');
  return buffer.toString();
}

/// SHA-256 hex of the canonical payload JSON. The push records one
/// hash per sync id after a successful upsert; a later entry whose
/// current payload hashes the same is skipped without a server call.
/// The skip matters: the server trigger bumps `server_updated_at` on
/// every UPDATE, even a no-op, so a blind re-push would churn every
/// other device's pull cursor for rows that never changed.
String payloadHash(Map<String, dynamic> payload) =>
    sha256.convert(utf8.encode(canonicalJson(payload))).toString();

/// A [DateTime] as the UTC ISO-8601 string the server's `timestamptz`
/// columns expect. Null stays null.
String? isoUtc(DateTime? value) => value?.toUtc().toIso8601String();
