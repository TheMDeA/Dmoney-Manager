import 'package:flutter_test/flutter_test.dart';

import 'package:dmoney_manager/core/utils/app_locale.dart';
import 'package:dmoney_manager/core/utils/formatters.dart';

/// Percentages and bare decimals follow the app language's decimal
/// separator — a dot in English, a comma in Bahasa Indonesia. (Money
/// figures are exempt by design: they follow the currency.)
void main() {
  tearDown(() => appLocaleCode = 'en');

  test('english: dot separator', () {
    appLocaleCode = 'en';
    expect(formatPercent(12.5), '12.5%');
    expect(formatPercent(-0.898), '-0.9%');
    expect(formatDecimal(1.8), '1.8');
    expect(formatPercent(40), '40.0%');
  });

  test('indonesian: comma separator', () {
    appLocaleCode = 'id';
    expect(formatPercent(12.5), '12,5%');
    expect(formatPercent(-0.898), '-0,9%');
    expect(formatDecimal(1.8), '1,8');
  });
}
