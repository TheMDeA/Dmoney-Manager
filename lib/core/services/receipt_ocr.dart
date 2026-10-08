import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Best-effort fields read off a receipt photo. Everything is nullable —
/// the caller falls back to manual entry for whatever OCR couldn't find.
class ReceiptScan {
  const ReceiptScan({
    this.merchant,
    this.total,
    this.date,
    required this.rawText,
    this.candidates = const [],
  });

  /// Store/merchant name, e.g. "Indomaret".
  final String? merchant;

  /// Total in whole IDR, e.g. 59500.
  final int? total;

  /// Receipt date, if one was found.
  final DateTime? date;

  final String rawText;

  /// Other plausible totals, best first (excluding [total]). Lets the user
  /// cycle alternatives when the top pick is wrong.
  final List<int> candidates;

  /// True when at least one useful field was extracted.
  bool get hasData => merchant != null || total != null || date != null;
}

/// On-device receipt OCR (Google ML Kit, Latin script — no network, no
/// cost). Takes a photo path, returns parsed receipt fields.
///
/// Returns null when the photo was read fine but nothing useful could be
/// extracted (caller falls back to manual entry silently).
/// Throws [ReceiptOcrException] when text recognition itself failed
/// (missing/broken native model, unreadable file, ...), so the caller can
/// tell the user instead of failing silently.
class ReceiptOcr {
  ReceiptOcr._();

  static Future<ReceiptScan?> scan(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(inputImage);
      final lines = result.text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) return null;
      final total = parseReceiptTotal(lines);
      final candidates = receiptTotalCandidates(
        lines,
      ).where((c) => c != total).toList();
      final scan = ReceiptScan(
        merchant: parseReceiptMerchant(lines),
        total: total,
        date: parseReceiptDate(lines),
        rawText: result.text,
        candidates: candidates,
      );
      return scan.hasData ? scan : null;
    } catch (e) {
      throw ReceiptOcrException('Text recognition failed: $e');
    } finally {
      await recognizer.close();
    }
  }
}

/// Text recognition itself broke (as opposed to "photo had no usable text").
class ReceiptOcrException implements Exception {
  const ReceiptOcrException(this.message);
  final String message;

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Pure parsing helpers (unit-testable, no ML Kit involved).
// ---------------------------------------------------------------------------

/// Parses an Indonesian-formatted amount token into whole IDR:
/// "59.500" -> 59500, "1.250.000" -> 1250000, "59.500,00" -> 59500.
/// Returns null for non-amounts.
int? parseIdrAmount(String token) {
  var t = token.trim().replaceFirst(
    RegExp(r'^Rp\.?\s*', caseSensitive: false),
    '',
  );
  if (!RegExp(r'^[\d][\d.,]*$').hasMatch(t)) return null;
  if (t.contains(',')) {
    if (RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(t)) {
      // US-style thousands: "1,250,000".
      t = t.replaceAll(',', '');
    } else {
      // Indonesian decimals: "59.500,00" -> drop the fraction.
      t = t.split(',').first;
    }
  }
  t = t.replaceAll('.', '');
  final v = int.tryParse(t);
  if (v == null || v <= 0) return null;
  return v;
}

bool _looksLikeDateToken(String token) => token.contains('/');

bool _looksLikePhoneToken(String token) {
  final digits = token.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 10 &&
      (digits.startsWith('08') || digits.startsWith('628'));
}

/// All plausible amounts on one OCR line, excluding dates, phone numbers,
/// and tiny noise numbers (quantities, item codes).
List<int> amountsInLine(String line) {
  final out = <int>[];
  for (final m in RegExp(r'[\d][\d.,]*').allMatches(line)) {
    final token = m.group(0)!;
    if (_looksLikeDateToken(token)) continue;
    if (_looksLikePhoneToken(token)) continue;
    final v = parseIdrAmount(token);
    if (v == null) continue;
    if (v < 500) continue;
    if (v > 1000000000) continue;
    out.add(v);
  }
  return out;
}

/// Lines that mention money changing hands (cash tendered, change given)
/// — never the total. These must be excluded from the fallback so a
/// "TUNAI 100.000" doesn't beat the real "TOTAL 59.500".
bool _isPaymentLine(String line) {
  final low = line.toLowerCase();
  // NB: "total bayar"/"jumlah bayar" are total keywords, checked first —
  // only bare payment words count here.
  const words = [
    'tunai',
    'cash',
    'kembali',
    'kembalian',
    'change',
    'uang pas',
    'non tunai',
    'nontunai',
    'debit',
    'kredit',
    'qris',
    'e-money',
    'emoney',
  ];
  return words.any((w) => RegExp(r'(^|[\s:])' + w + r'($|[\s:])').hasMatch(low));
}

/// Finds the receipt total: prefers lines mentioning "total" (grand total
/// first), taking the last amount on the line; falls back to the largest
/// amount on a non-payment line (so TUNAI/KEMBALI never win).
int? parseReceiptTotal(List<String> lines) {
  const keywords = [
    'grand total',
    'total bayar',
    'jumlah bayar',
    'total belanja',
    'total pembelian',
    'jumlah',
    'tagihan',
    'total',
  ];
  for (final kw in keywords) {
    for (final line in lines) {
      if (!line.toLowerCase().contains(kw)) continue;
      final amounts = amountsInLine(line);
      if (amounts.isNotEmpty) return amounts.last;
    }
  }
  int? best;
  for (final line in lines) {
    if (_isPaymentLine(line)) continue;
    for (final a in amountsInLine(line)) {
      if (best == null || a > best) best = a;
    }
  }
  return best;
}

/// All plausible total candidates on the receipt, best first. Used by the
/// UI so the user can cycle through alternatives when the top pick is wrong.
List<int> receiptTotalCandidates(List<String> lines) {
  final seen = <int>[];
  void add(int v) {
    if (!seen.contains(v)) seen.add(v);
  }

  const keywords = [
    'grand total',
    'total bayar',
    'jumlah bayar',
    'total belanja',
    'total pembelian',
    'jumlah',
    'tagihan',
    'total',
  ];
  for (final kw in keywords) {
    for (final line in lines) {
      if (!line.toLowerCase().contains(kw)) continue;
      final amounts = amountsInLine(line);
      if (amounts.isNotEmpty) add(amounts.last);
    }
  }
  // Then every other non-payment amount, largest first.
  final rest = <int>[];
  for (final line in lines) {
    if (_isPaymentLine(line)) continue;
    for (final a in amountsInLine(line)) {
      if (!seen.contains(a) && !rest.contains(a)) rest.add(a);
    }
  }
  rest.sort((a, b) => b.compareTo(a));
  for (final a in rest) {
    add(a);
  }
  return seen;
}

bool _validDate(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1) return false;
  const daysIn = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  var dim = daysIn[m - 1];
  if (m == 2 && (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0))) dim = 29;
  return d <= dim;
}

const _monthNames = {
  'jan': 1,
  'januari': 1,
  'feb': 2,
  'februari': 2,
  'mar': 3,
  'maret': 3,
  'march': 3,
  'apr': 4,
  'april': 4,
  'mei': 5,
  'may': 5,
  'jun': 6,
  'juni': 6,
  'june': 6,
  'jul': 7,
  'juli': 7,
  'july': 7,
  'agu': 8,
  'agustus': 8,
  'aug': 8,
  'august': 8,
  'sep': 9,
  'september': 9,
  'okt': 10,
  'oktober': 10,
  'oct': 10,
  'october': 10,
  'nov': 11,
  'november': 11,
  'des': 12,
  'desember': 12,
  'dec': 12,
  'december': 12,
};

DateTime? _saneDate(int y, int m, int d) {
  if (!_validDate(y, m, d)) return null;
  final dt = DateTime(y, m, d);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // Receipts are never from the future nor older than 5 years.
  if (dt.isAfter(today)) return null;
  if (dt.isBefore(today.subtract(const Duration(days: 365 * 5)))) {
    return null;
  }
  return dt;
}

/// Finds a receipt date: numeric dd/mm/yyyy first, then "dd MMM yyyy"
/// with Indonesian/English month names.
DateTime? parseReceiptDate(List<String> lines) {
  for (final line in lines) {
    final m = RegExp(
      r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})',
    ).firstMatch(line);
    if (m != null) {
      var y = int.parse(m.group(3)!);
      if (y < 100) y += 2000;
      final dt = _saneDate(y, int.parse(m.group(2)!), int.parse(m.group(1)!));
      if (dt != null) return dt;
    }
    final m2 = RegExp(
      r'(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{4})',
    ).firstMatch(line);
    if (m2 != null) {
      final mo = _monthNames[m2.group(2)!.toLowerCase()];
      if (mo != null) {
        final dt = _saneDate(
          int.parse(m2.group(3)!),
          mo,
          int.parse(m2.group(1)!),
        );
        if (dt != null) return dt;
      }
    }
  }
  return null;
}

/// Common Indonesian merchants: matched (case-insensitive, substring)
/// against receipt lines so the name comes out clean even when the OCR'd
/// header line has extra junk around it.
const _knownMerchants = [
  'Indomaret',
  'Alfamart',
  'Alfamidi',
  'Lawson',
  'FamilyMart',
  'Circle K',
  'Super Indo',
  'Hypermart',
  'Carrefour',
  'Transmart',
  'Lottemart',
  'Giant',
  'Hero',
  'Ramayana',
  'Matahari',
  'Gramedia',
  'Ace Hardware',
  'Informa',
  'Chatime',
  'Kopi Kenangan',
  'Janji Jiwa',
  'Starbucks',
  'JCO',
  'BreadTalk',
  'Roti O',
  'KFC',
  'McDonald',
  "McDonald's",
  'Pizza Hut',
  'Domino',
  'Burger King',
  'HokBen',
  'Hoka Hoka Bento',
  'Sola ria',
  'Soloria',
  'Bakmi GM',
  'Sate Khas Senayan',
  'Warung Steak',
  'Gacoan',
  'Mie Gacoan',
  'Richeese',
  'Mixue',
  'GoFood',
  'GrabFood',
  'ShopeeFood',
  'Tokopedia',
  'Shopee',
  'Blibli',
  'Lazada',
  'Pertamina',
  'Shell',
  'BP-AKR',
  'Vivo',
  'Kimia Farma',
  'Apotek K-24',
  'Guardian',
  'Watsons',
  'Century',
  'XXI',
  'CGV',
  'Cinepolis',
];

/// Merchant is usually the first meaningful text line: alphabetic,
/// reasonably long, and not a receipt keyword (struk, kasir, npwp…).
/// Known merchants are matched first for a clean name.
String? parseReceiptMerchant(List<String> lines) {
  // Known merchant first: cleaner than whatever the header line says.
  for (final line in lines) {
    final low = line.toLowerCase();
    for (final m in _knownMerchants) {
      if (low.contains(m.toLowerCase())) return m;
    }
  }
  const skip = [
    'struk',
    'receipt',
    'nota',
    'invoice',
    'telp',
    'phone',
    'npwp',
    'alamat',
    'address',
    'kasir',
    'cashier',
    'terima kasih',
    'thank you',
  ];
  for (final line in lines) {
    final t = line.trim();
    if (t.length < 3) continue;
    if (!RegExp(r'[A-Za-z]{3,}').hasMatch(t)) continue;
    if (RegExp(r'^[\d\W]').hasMatch(t)) continue;
    final low = t.toLowerCase();
    if (skip.any(low.contains)) continue;
    return t.length > 40 ? t.substring(0, 40) : t;
  }
  return null;
}
