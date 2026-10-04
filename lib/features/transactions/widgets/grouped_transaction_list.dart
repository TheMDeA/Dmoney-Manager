import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/entrance.dart';
import '../../../data/database/app_database.dart';
import 'date_group_header.dart';
import 'transaction_tile.dart';

/// Slices newest-first [items] into per-day groups: a [DateGroupHeader]
/// with the day's net total, then staggered [TransactionTile] rows.
/// Transfers stay neutral in the daily net. Shared by the transaction
/// history, wallet transactions, and wallet category screens.
///
/// Insertions animate in via [Entrance] (stable keys mean only newcomers
/// play it). Removals collapse out: rows deleted from [items] are kept
/// rendered for one [AppMotion.normal] beat inside [_CollapseOut], then
/// the list swaps to the new data. Wholesale changes (e.g. switching
/// months) swap immediately without the exit choreography.
class GroupedTransactionList extends StatefulWidget {
  const GroupedTransactionList({super.key, required this.items});

  final List<TransactionWithDetails> items;

  @override
  State<GroupedTransactionList> createState() =>
      _GroupedTransactionListState();
}

class _GroupedTransactionListState extends State<GroupedTransactionList> {
  late List<TransactionWithDetails> _shown = widget.items;
  final Set<int> _exiting = {};
  bool _exitScheduled = false;

  @override
  void didUpdateWidget(covariant GroupedTransactionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(widget.items, oldWidget.items)) return;
    final newIds = {
      for (final d in widget.items) d.transaction.id,
    };
    // Undo brings rows back: stop their exit immediately.
    _exiting.removeWhere(newIds.contains);
    final removedIds = {
      for (final d in _shown)
        if (!newIds.contains(d.transaction.id) &&
            !_exiting.contains(d.transaction.id))
          d.transaction.id,
    };
    if (removedIds.isEmpty) {
      _shown = widget.items;
      return;
    }
    if (removedIds.length * 2 > _shown.length) {
      // Wholesale change — swap without exit choreography.
      _shown = widget.items;
      _exiting.clear();
      return;
    }
    _exiting.addAll(removedIds);
    if (!_exitScheduled) {
      _exitScheduled = true;
      Future.delayed(AppMotion.normal, () {
        if (!mounted) return;
        _exitScheduled = false;
        setState(() {
          _shown = widget.items;
          _exiting.clear();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    var i = 0;
    while (i < _shown.length) {
      final d0 = _shown[i].transaction.date;
      final day = DateTime(d0.year, d0.month, d0.day);
      var j = i;
      var net = 0;
      while (j < _shown.length) {
        final t = _shown[j].transaction;
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
        final d = _shown[k];
        final tile = TransactionTile(details: d);
        if (_exiting.contains(d.transaction.id)) {
          children.add(_CollapseOut(
            key: ValueKey('exit-${d.transaction.id}'),
            child: tile,
          ));
        } else {
          children.add(
            Entrance(
              key: ValueKey('tx-${d.transaction.id}'),
              delay:
                  Duration(milliseconds: (40 * (k - i)).clamp(0, 320)),
              child: tile,
            ),
          );
        }
      }
      i = j;
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: children,
    );
  }
}

/// Plays a collapse + fade once when inserted; the parent drops the row
/// after [AppMotion.normal].
class _CollapseOut extends StatefulWidget {
  const _CollapseOut({super.key, required this.child});

  final Widget child;

  @override
  State<_CollapseOut> createState() => _CollapseOutState();
}

class _CollapseOutState extends State<_CollapseOut>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: AppMotion.normal)
        ..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim =
        CurvedAnimation(parent: _controller, curve: AppMotion.exit);
    return SizeTransition(
      sizeFactor: Tween(begin: 1.0, end: 0.0).animate(anim),
      child: FadeTransition(
        opacity: Tween(begin: 1.0, end: 0.0).animate(anim),
        child: widget.child,
      ),
    );
  }
}
