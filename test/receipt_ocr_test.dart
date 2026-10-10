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

    test('captures time after numeric date', () {
      final dt = parseReceiptDate(['08/10/2026 14:30']);
      expect(dt, isNotNull);
      expect(dt!.hour, 14);
      expect(dt.minute, 30);
    });

    test('captures time with seconds', () {
      final dt = parseReceiptDate(['08-10-2026 09:05:25']);
      expect(dt, isNotNull);
      expect(dt!.hour, 9);
      expect(dt.minute, 5);
    });

    test('captures time after month-name date', () {
      final dt = parseReceiptDate(['8 Okt 2026 18:45']);
      expect(dt, isNotNull);
      expect(dt!.hour, 18);
      expect(dt.minute, 45);
    });

    test('date without time defaults to midnight', () {
      final dt = parseReceiptDate(['08/10/2026']);
      expect(dt, isNotNull);
      expect(dt!.hour, 0);
      expect(dt.minute, 0);
    });

    test('invalid time keeps the date, drops the time', () {
      final dt = parseReceiptDate(['08/10/2026 25:99']);
      expect(dt, isNotNull);
      expect(dt!.hour, 0);
      expect(dt.minute, 0);
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
      expect(parseReceiptMerchant(lines), 'Indomaret');
    });

    test('known merchant matched in messy line', () {
      final lines = [
        '*** ALFAMART ***',
        'Jl. Sudirman',
        'TOTAL Rp 25.000',
      ];
      expect(parseReceiptMerchant(lines), 'Alfamart');
    });

    test('skips receipt keywords', () {
      final lines = ['STRUK BELANJA', 'Sate Ayam Pak Kumis'];
      expect(parseReceiptMerchant(lines), 'Sate Ayam Pak Kumis');
    });

    test('empty lines', () {
      expect(parseReceiptMerchant(const []), isNull);
    });
  });

  group('parseReceiptTotal payment-line exclusion', () {
    test('tunai/kembali never beat the total in fallback', () {
      final lines = [
        'Mie Ayam 15.000',
        'Es Teh 5.000',
        // No "total" keyword: fallback must skip payment lines.
        'TUNAI 100.000',
        'KEMBALI 80.000',
      ];
      expect(parseReceiptTotal(lines), 15000);
    });

    test('total keyword still wins over payment lines', () {
      final lines = [
        'TOTAL Rp 59.500',
        'TUNAI 100.000',
        'KEMBALI 40.500',
      ];
      expect(parseReceiptTotal(lines), 59500);
    });

    test('new total variants recognized', () {
      expect(parseReceiptTotal(['TAGIHAN 75.000']), 75000);
      expect(parseReceiptTotal(['JUMLAH Rp 32.000']), 32000);
      expect(parseReceiptTotal(['Total Belanja 18.500']), 18500);
    });

    test('qris/debit lines excluded from fallback', () {
      final lines = [
        'Kopi 20.000',
        'QRIS 20.000',
      ];
      expect(parseReceiptTotal(lines), 20000);
    });
  });

  group('parseReceiptTotal subtotal handling', () {
    test('subtotal printed above the total does not win', () {
      final lines = [
        'SUBTOTAL 25.000',
        'TOTAL 27.500',
        'TUNAI 30.000',
      ];
      expect(parseReceiptTotal(lines), 27500);
    });

    test('subtotal alone still counts when there is no grand total', () {
      final lines = [
        'Kopi 20.000',
        'SUBTOTAL 20.000',
        'TUNAI 20.000',
      ];
      expect(parseReceiptTotal(lines), 20000);
    });

    test('total still matches with colon or surrounding marks', () {
      expect(parseReceiptTotal(['TOTAL: 59.500']), 59500);
      expect(parseReceiptTotal(['* TOTAL 59.500 *']), 59500);
    });
  });

  group('receiptTotalCandidates', () {
    test('best first, no duplicates', () {
      final lines = [
        'TOTAL Rp 59.500',
        'TUNAI 100.000',
        'KEMBALI 40.500',
        'Parkir 5.000',
      ];
      final c = receiptTotalCandidates(lines);
      expect(c.first, 59500);
      expect(c, contains(5000));
      expect(c, isNot(contains(100000)));
      expect(c, isNot(contains(40500)));
      expect(c.toSet().length, c.length);
    });

    test('empty when no amounts', () {
      expect(receiptTotalCandidates(['hello world']), isEmpty);
    });

    test('subtotal does not outrank the grand total', () {
      final lines = [
        'SUBTOTAL 25.000',
        'TOTAL 27.500',
      ];
      final c = receiptTotalCandidates(lines);
      expect(c.first, 27500);
    });
  });
}
