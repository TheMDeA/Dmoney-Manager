import 'package:dmoney_manager/core/services/receipt_ocr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseIdrAmount', () {
    test('Indonesian thousands', () {
      expect(parseIdrAmount('59.500'), 59500);
      expect(parseIdrAmount('1.250.000'), 1250000);
      expect(parseIdrAmount('Rp 59.500'), 59500);
      expect(parseIdrAmount('Rp.1.250.000'), 1250000);
    });

    test('decimals are dropped', () {
      expect(parseIdrAmount('59.500,00'), 59500);
    });

    test('plain digits', () {
      expect(parseIdrAmount('125000'), 125000);
    });

    test('US-style thousands', () {
      expect(parseIdrAmount('1,250,000'), 1250000);
    });

    test('rejects non-amounts', () {
      expect(parseIdrAmount(''), isNull);
      expect(parseIdrAmount('abc'), isNull);
      expect(parseIdrAmount('0'), isNull);
    });
  });

  group('parseReceiptTotal', () {
    test('prefers the total line', () {
      final lines = [
        'Indomaret',
        'Kopi 25000',
        'Roti 15000',
        'TOTAL Rp 59.500',
        'Tunai 100.000',
      ];
      expect(parseReceiptTotal(lines), 59500);
    });

    test('prefers grand total over total', () {
      final lines = ['TOTAL 40000', 'GRAND TOTAL Rp 59.500'];
      expect(parseReceiptTotal(lines), 59500);
    });

    test('falls back to largest amount', () {
      final lines = ['Kopi 25000', 'Roti 15000'];
      expect(parseReceiptTotal(lines), 25000);
    });

    test('ignores phone numbers and dates', () {
      final lines = ['Telp 081234567890', '08/10/2026', 'TOTAL Rp 59.500'];
      expect(parseReceiptTotal(lines), 59500);
    });

    test('empty lines', () {
      expect(parseReceiptTotal(const []), isNull);
    });
  });

  group('parseReceiptDate', () {
    test('numeric date', () {
      final d = parseReceiptDate(['Struk', '08/10/2026', 'Total 59500']);
      expect(d, DateTime(2026, 10, 8));
    });

    test('dashes and 2-digit year', () {
      final d = parseReceiptDate(['08-10-26']);
      expect(d, DateTime(2026, 10, 8));
    });

    test('Indonesian month name', () {
      final d = parseReceiptDate(['8 Okt 2026']);
      expect(d, DateTime(2026, 10, 8));
    });

    test('rejects future dates', () {
      final future = '${DateTime.now().day}/12/${DateTime.now().year + 2}';
      expect(parseReceiptDate([future]), isNull);
    });

    test('rejects invalid dates', () {
      expect(parseReceiptDate(['32/13/2026']), isNull);
    });
  });

  group('parseReceiptMerchant', () {
    test('first meaningful line', () {
      final lines = [
        'INDOMARET',
        'Jl. Merdeka No. 1',
        'Telp 081234567890',
        'TOTAL Rp 59.500',
      ];
      expect(parseReceiptMerchant(lines), 'INDOMARET');
    });

    test('skips receipt keywords', () {
      final lines = ['STRUK BELANJA', 'Sate Ayam Pak Kumis'];
      expect(parseReceiptMerchant(lines), 'Sate Ayam Pak Kumis');
    });

    test('empty lines', () {
      expect(parseReceiptMerchant(const []), isNull);
    });
  });
}
