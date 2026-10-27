import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/utils/interest_projection.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// Wallet interest projection: monthly-compounding growth math, the
/// section-visibility predicate (bank/ewallet + a set rate, never an
/// unset rate read as zero), and the annual-rate round-trip.
/// The annual growth rate is deliberately separate from paylater's
/// monthly cost rate — the two are never mixed.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
  });

  tearDown(() => db.close());

  Future<int> makeAccount() => db.addAccount(
        AccountsCompanion.insert(
          name: 'Personal',
          kind: 'personal',
          colorHex: const Value('#FF0000'),
        ),
      );

  Future<Wallet> makeWallet(
    int accountId,
    String name,
    String kind, {
    int initialAmount = 0,
    double? annualRate,
    double? monthlyRate,
  }) async {
    final id = await db.createWallet(
      accountId: accountId,
      name: name,
      kind: kind,
      initialAmount: initialAmount,
      interestRateAnnual: annualRate,
      interestRateMonthly: monthlyRate,
    );
    return (await db.getWalletById(id))!;
  }

  group('projection math', () {
    test('monthly compounding at 12%/year matches FV', () {
      // (1.01)^6 = 1.061520…, (1.01)^12 = 1.126825…
      expect(
        projectedBalance(balance: 1000000, annualRatePct: 12, months: 6),
        1061520,
      );
      expect(
        projectedBalance(balance: 1000000, annualRatePct: 12, months: 12),
        1126825,
      );
    });

    test('zero rate is flat, and year interest is zero', () {
      expect(
        projectedBalance(balance: 500000, annualRatePct: 0, months: 12),
        500000,
      );
      expect(
        projectedYearInterest(balance: 500000, annualRatePct: 0),
        0,
      );
    });

    test('curve has 13 points from now to month 12, rising', () {
      final curve = projectionCurve(balance: 1000000, annualRatePct: 12);
      expect(curve.length, 13);
      expect(curve.first, 1000000);
      expect(curve.last, 1126825);
      for (var i = 1; i < curve.length; i++) {
        expect(curve[i] >= curve[i - 1], isTrue);
      }
    });

    test('year interest is the 12-month gain, not balance * rate', () {
      // Compounding beats simple interest: 1.126825x, not 1.12x.
      expect(
        projectedYearInterest(balance: 1000000, annualRatePct: 12),
        126825,
      );
    });
  });

  group('rate formatting', () {
    test('trims trailing zeros', () {
      expect(formatAnnualRate(4.0), '4%');
      expect(formatAnnualRate(4.5), '4.5%');
      expect(formatAnnualRate(4.25), '4.25%');
    });
  });

  group('section visibility', () {
    test('bank and ewallet with a rate show; unset rate never shows',
        () async {
      final account = await makeAccount();
      final bank = await makeWallet(account, 'Seabank', 'bank',
          initialAmount: 1000000, annualRate: 4.0);
      final bankNoRate =
          await makeWallet(account, 'Plain', 'bank', initialAmount: 1000000);
      final ewallet = await makeWallet(account, 'GoPay', 'ewallet',
          initialAmount: 500000, annualRate: 2.0);
      expect(showGrowthProjection(bank), isTrue);
      expect(showGrowthProjection(bankNoRate), isFalse);
      expect(showGrowthProjection(ewallet), isTrue);
    });

    test('cash, credit, paylater never show even with a rate set',
        () async {
      final account = await makeAccount();
      final cash = await makeWallet(account, 'Cash', 'cash',
          initialAmount: 100000, annualRate: 4.0);
      final credit = await makeWallet(account, 'Card', 'credit',
          initialAmount: -50000, annualRate: 4.0);
      final paylater = await makeWallet(account, 'Later', 'paylater',
          initialAmount: -50000, monthlyRate: 2.5);
      expect(showGrowthProjection(cash), isFalse);
      expect(showGrowthProjection(credit), isFalse);
      expect(showGrowthProjection(paylater), isFalse);
    });

    test('explicit 0% rate shows a flat projection, not a hidden section',
        () async {
      final account = await makeAccount();
      final zero = await makeWallet(account, 'Zero', 'bank',
          initialAmount: 100000, annualRate: 0);
      expect(showGrowthProjection(zero), isTrue);
      expect(
        projectedBalance(balance: 100000, annualRatePct: 0, months: 12),
        100000,
      );
    });
  });

  group('annual rate round-trip', () {
    test('survives create, edit, and clear', () async {
      final account = await makeAccount();
      final w = await makeWallet(account, 'Seabank', 'bank',
          initialAmount: 1000000, annualRate: 4.0);
      expect(w.interestRateAnnual, 4.0);
      await db.updateWallet(
        id: w.id,
        name: w.name,
        kind: w.kind,
        interestRateAnnual: const Value(4.5),
      );
      expect((await db.getWalletById(w.id))!.interestRateAnnual, 4.5);
      await db.updateWallet(
        id: w.id,
        name: w.name,
        kind: w.kind,
        interestRateAnnual: const Value(null),
      );
      expect((await db.getWalletById(w.id))!.interestRateAnnual, null);
    });
  });

  group('interest income category', () {
    test('seed has an Interest income category', () async {
      final cats = await db.watchCategories().first;
      expect(cats, isNotEmpty);
      final interest = cats.where((c) => c.name == 'Interest');
      expect(interest, hasLength(1));
      expect(interest.single.kind, 'income');
    });
  });
}
