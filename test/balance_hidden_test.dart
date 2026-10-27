import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/utils/formatters.dart';
import 'package:dmoney_manager/core/widgets/amount_text.dart';
import 'package:dmoney_manager/state/providers.dart';

/// Privacy mode: the Home eye hides balance and total figures
/// app-wide, while individual transaction amounts stay visible.
/// The mask keeps the currency/sign prefix and dots the digits,
/// identically for every masked figure.
void main() {
  group('maskMoneyText', () {
    test('dots the digits, keeps the prefix', () {
      expect(maskMoneyText('Rp 12.450.000'), 'Rp ••••••••');
      expect(maskMoneyText('+Rp 500'), '+Rp ••••••••');
      expect(maskMoneyText('-Rp 500'), '-Rp ••••••••');
      expect(maskMoneyText('Rp 0'), 'Rp ••••••••');
      expect(maskMoneyText('\$12,450,000.00'), '\$••••••••');
    });
  });

  group('AmountText hidden flag', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      await AppPrefs.init();
    });

    Future<void> pumpAmount(WidgetTester tester, bool hidden) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmountText(
              1250000,
              isIncome: true,
              hidden: hidden,
            ),
          ),
        ),
      );
    }

    testWidgets('shows the figure when visible', (tester) async {
      await pumpAmount(tester, false);
      expect(find.text('+Rp 1.250.000'), findsOneWidget);
    });

    testWidgets('shows the dot mask when hidden', (tester) async {
      await pumpAmount(tester, true);
      expect(find.text('+Rp ••••••••'), findsOneWidget);
      expect(find.text('+Rp 1.250.000'), findsNothing);
    });
  });

  group('balanceHiddenProvider', () {
    test('seeds from prefs and persists the toggle', () async {
      SharedPreferences.setMockInitialValues({});
      await AppPrefs.init();

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(balanceHiddenProvider), isFalse);

      await container.read(balanceHiddenProvider.notifier).toggle();
      expect(container.read(balanceHiddenProvider), isTrue);
      expect(AppPrefs.balanceHidden, isTrue);

      await container.read(balanceHiddenProvider.notifier).toggle();
      expect(container.read(balanceHiddenProvider), isFalse);
      expect(AppPrefs.balanceHidden, isFalse);
    });

    test('seeds true when prefs already hide', () async {
      SharedPreferences.setMockInitialValues({'balanceHidden': true});
      await AppPrefs.init();

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(balanceHiddenProvider), isTrue);
    });
  });
}
