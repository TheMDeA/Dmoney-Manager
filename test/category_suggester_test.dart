import 'package:dmoney_manager/core/services/category_suggester.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tokenizeNote', () {
    test('lowercases and splits on non-alphanumerics', () {
      expect(
        tokenizeNote('Koppa Mart - Weekly!!'),
        {'koppa', 'mart', 'weekly'},
      );
    });

    test('drops short tokens and pure numbers', () {
      expect(tokenizeNote('di koppa 123'), {'koppa'});
    });

    test('dedupes repeated words', () {
      expect(tokenizeNote('mart mart mart'), {'mart'});
    });

    test('empty note yields no tokens', () {
      expect(tokenizeNote(''), isEmpty);
      expect(tokenizeNote('!!'), isEmpty);
    });
  });

  group('scoreKeywords', () {
    // Two top-level categories: 1 = Groceries (expense), 2 = Salary (income).
    const kinds = {1: 'expense', 2: 'income'};
    const topLevel = {1: true, 2: true};

    test('unanimous keyword wins with full confidence', () {
      final s = scoreKeywords(
        hits: {
          'koppa': {1: 20},
          'mart': {1: 20},
        },
        kinds: kinds,
        topLevel: topLevel,
        kind: 'expense',
      );
      expect(s, isNotNull);
      expect(s!.categoryId, 1);
      expect(s.confidence, 1.0);
      expect(s.autoSelect, isTrue);
    });

    test('mixed keyword averages confidences', () {
      final s = scoreKeywords(
        hits: {
          // 75% groceries...
          'mart': {1: 15, 2: 5},
          // ...but unanimous for groceries
          'koppa': {1: 20},
        },
        kinds: kinds,
        topLevel: topLevel,
        kind: 'expense',
      );
      expect(s, isNotNull);
      expect(s!.categoryId, 1);
      // (0.75 + 1.0) / 2 = 0.875 -> suggests, but no auto-select
      expect(s.confidence, closeTo(0.875, 0.001));
      expect(s.autoSelect, isFalse);
    });

    test('ignores keywords with too few samples', () {
      final s = scoreKeywords(
        hits: {
          'koppa': {1: 2}, // below minSamples (3)
        },
        kinds: kinds,
        topLevel: topLevel,
        kind: 'expense',
      );
      expect(s, isNull);
    });

    test('stays quiet below the confidence threshold', () {
      final s = scoreKeywords(
        hits: {
          'mart': {1: 5, 2: 5}, // 50/50
        },
        kinds: kinds,
        topLevel: topLevel,
        kind: 'expense',
      );
      expect(s, isNull);
    });

    test('only considers categories of the requested kind', () {
      final s = scoreKeywords(
        hits: {
          'gaji': {2: 20}, // unanimous, but income
        },
        kinds: kinds,
        topLevel: topLevel,
        kind: 'expense',
      );
      expect(s, isNull);
    });

    test('skips subcategories', () {
      final s = scoreKeywords(
        hits: {
          'koppa': {1: 20},
        },
        kinds: kinds,
        topLevel: {1: false, 2: true},
        kind: 'expense',
      );
      expect(s, isNull);
    });
  });
}
