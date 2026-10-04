import 'package:flutter/material.dart';

import '../../../core/widgets/entrance.dart';
import '../../../data/database/app_database.dart';
import 'date_group_header.dart';
import 'transaction_tile.dart';

/// Slices newest-first [items] into per-day groups: a [DateGroupHeader]
/// with the day's net total, then staggered [TransactionTile] rows.
/// Transfers stay neutral in the daily net. Shared by the transaction
/// history and wallet transactions screens.
Widget groupedTransactionList(List<TransactionWithDetails> items) {
  final children = <Widget>[];
  var i = 0;
  while (i < items.length) {
    final d0 = items[i].transaction.date;
    final day = DateTime(d0.year, d0.month, d0.day);
    var j = i;
    var net = 0;
    while (j < items.length) {
      final t = items[j].transaction;
      if (t.date.year != day.year ||
          t.date.month != day.month ||
          t.date.day != day.day) {
        break;
      }
      net += t.kind == 'income'
          ? t.amount
          : (t.kind == 'expense' ? -t.amount : 0);
      j++;
    }
    children.add(DateGroupHeader(day: day, net: net));
    for (var k = i; k < j; k++) {
      children.add(
        Entrance(
          key: ValueKey('tx-${items[k].transaction.id}'),
          delay: Duration(milliseconds: (40 * (k - i)).clamp(0, 320)),
          child: TransactionTile(details: items[k]),
        ),
      );
    }
    i = j;
  }
  return ListView(
    padding: const EdgeInsets.only(bottom: 96),
    children: children,
  );
}
