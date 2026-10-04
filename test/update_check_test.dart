import 'package:flutter_test/flutter_test.dart';
import 'package:dmoney_manager/core/services/update_service.dart';

void main() {
  group('isNewerVersion', () {
    test('detects a newer patch/minor/major', () {
      expect(isNewerVersion('2.1.2', '2.1.1'), isTrue);
      expect(isNewerVersion('2.2.0', '2.1.9'), isTrue);
      expect(isNewerVersion('3.0.0', '2.9.9'), isTrue);
    });

    test('compares numerically, not lexicographically', () {
      expect(isNewerVersion('2.1.10', '2.1.9'), isTrue);
      expect(isNewerVersion('2.1.9', '2.1.10'), isFalse);
    });

    test('equal versions are not newer', () {
      expect(isNewerVersion('2.1.1', '2.1.1'), isFalse);
      expect(isNewerVersion('2.1', '2.1.0'), isFalse);
    });

    test('older versions are not newer', () {
      expect(isNewerVersion('2.1.0', '2.1.1'), isFalse);
      expect(isNewerVersion('1.9.9', '2.0.0'), isFalse);
    });

    test('ignores build metadata and leading v', () {
      expect(isNewerVersion('v2.1.2', '2.1.1+24'), isTrue);
      expect(isNewerVersion('2.1.1', '2.1.1+24'), isFalse);
    });
  });
}
