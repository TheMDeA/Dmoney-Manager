import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final NumberFormat _idrFormat =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

/// Formats whole rupiah, e.g. 12450000 -> "Rp 12.450.000".
String formatIDR(int amount) => _idrFormat.format(amount);

/// Signed amount with explicit +/- so meaning never relies on color alone.
String formatSignedIDR(int amount, {required bool isIncome}) =>
    '${isIncome ? '+' : '-'}${formatIDR(amount)}';

/// "yyyy-MM" key used by the budgets table.
String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

Color colorFromHex(String hex) {
  final clean = hex.replaceFirst('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}

String formatDateTime(DateTime d) => DateFormat('dd MMM yyyy, HH:mm').format(d);
String formatDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);
