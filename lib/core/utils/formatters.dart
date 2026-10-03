import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/app_prefs.dart';

/// A currency the user can pick during onboarding (and later in settings).
class AppCurrency {
  const AppCurrency(this.code, this.name, this.symbol, this.locale, this.decimals);
  final String code; // ISO code, e.g. IDR
  final String name; // English display name
  final String symbol; // prefix symbol, e.g. "Rp "
  final String locale; // for grouping separators
  final int decimals; // digits after the decimal point

  String get label => '$code - $name (${symbol.trim()})';
}

const List<AppCurrency> supportedCurrencies = [
  AppCurrency('IDR', 'Indonesian Rupiah', 'Rp ', 'id_ID', 0),
  AppCurrency('USD', 'US Dollar', '\$', 'en_US', 2),
  AppCurrency('EUR', 'Euro', '€', 'de_DE', 2),
  AppCurrency('SGD', 'Singapore Dollar', 'S\$', 'en_SG', 2),
  AppCurrency('MYR', 'Malaysian Ringgit', 'RM', 'ms_MY', 2),
  AppCurrency('THB', 'Thai Baht', '฿', 'th_TH', 2),
  AppCurrency('PHP', 'Philippine Peso', '₱', 'fil_PH', 2),
  AppCurrency('JPY', 'Japanese Yen', '¥', 'ja_JP', 0),
  AppCurrency('GBP', 'British Pound', '£', 'en_GB', 2),
  AppCurrency('AUD', 'Australian Dollar', 'A\$', 'en_AU', 2),
  AppCurrency('INR', 'Indian Rupee', '₹', 'en_IN', 2),
  AppCurrency('CNY', 'Chinese Yuan', '¥', 'zh_CN', 2),
  AppCurrency('KRW', 'South Korean Won', '₩', 'ko_KR', 0),
  AppCurrency('VND', 'Vietnamese Dong', '₫', 'vi_VN', 0),
];

AppCurrency currencyByCode(String code) => supportedCurrencies.firstWhere(
      (c) => c.code == code,
      orElse: () => supportedCurrencies.first,
    );

/// Formats a whole-unit amount in the user's currency, e.g. 12450000 ->
/// "Rp 12.450.000" for IDR or "$12,450,000.00" for USD.
String formatMoney(int amount) =>
    formatMoneyWith(AppPrefs.currencyCode, amount);

/// Same as [formatMoney] but with an explicit currency code (used during
/// onboarding, before the choice is saved).
String formatMoneyWith(String code, int amount) {
  final c = currencyByCode(code);
  return NumberFormat.currency(
    locale: c.locale,
    symbol: c.symbol,
    decimalDigits: c.decimals,
  ).format(amount);
}

/// Signed amount with explicit +/- so meaning never relies on color alone.
String formatSignedMoney(int amount, {required bool isIncome}) =>
    '${isIncome ? '+' : '-'}${formatMoney(amount)}';

/// The user's currency, as a convenience.
AppCurrency get currentCurrency => currencyByCode(AppPrefs.currencyCode);

/// Symbol prefix for amount TextFields, e.g. "Rp " or "$ ".
String get currencyFieldPrefix => '${currentCurrency.symbol.trim()} ';

/// Live thousand-separator formatting for amount TextFields, following the
/// user's currency locale: typing 18088808 with IDR shows "18.088.808",
/// with USD it shows "18,088,808". Replaces digitsOnly formatters.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  ThousandsSeparatorInputFormatter({String? locale})
      : _fmt = NumberFormat('#,##0', locale ?? currentCurrency.locale);

  final NumberFormat _fmt;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    if (digits.length > 15) digits = digits.substring(0, 15);
    final formatted = _fmt.format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Parses an amount TextField value that may contain group separators
/// (and a symbol prefix); returns 0 when unparseable.
int parseAmountInput(String text) =>
    int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

/// Formats a raw integer for display inside an amount TextField.
String formatAmountInput(int amount) =>
    NumberFormat('#,##0', currentCurrency.locale).format(amount);

/// "yyyy-MM" key used by the budgets table.
String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

Color colorFromHex(String hex) {
  final clean = hex.replaceFirst('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}

String formatDateTime(DateTime d) => DateFormat('dd MMM yyyy, HH:mm').format(d);
String formatDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);
