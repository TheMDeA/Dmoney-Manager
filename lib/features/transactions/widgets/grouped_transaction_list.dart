import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/entrance.dart';
import '../../../data/database/app_database.dart';
import 'date_group_header.dart';
import 'transaction_tile.dart';

/// Slices newest-first [items] into per-day groups: a sticky
/// [DateGroupHeader] with the day's net total that pins to the top while its
/// day scrolls by, then staggered [TransactionTile] rows.
/// Transfers stay neutral in the daily net. Shared by the transaction
/// history, wallet transactions, and wallet category screens.
///
/// Insertions animate in via [Entrance] (stable keys mean only newcomers
/// play it). Removals collapse out: rows deleted from [items] are kept
/// rendered for one [AppMotion.normal] beat inside [_CollapseOut], then
/// the list swaps to the new data. Wholesale changes (e.g. switching
/// months) swap immediately without the exit choreography.
class GroupedTransactionList extends StatefulWidget {
  const GroupedTransactionList({
    super.key,
    required this.items,
    this.controller,
    this.selectedIds = const {},
    this.onToggleSelected,
  });

  final List<TransactionWithDetails> items;

  /// Optional scroll controller, e.g. for a date scrubber overlay.
  final ScrollController? controller;

  /// Ids of selected transactions. A non-empty set puts the list in
  /// bulk-selection mode (checkboxes, tap toggles, swipes disabled).
  final Set<int> selectedIds;

  /// Called with a transaction id to toggle its selection. When null,
  /// selection is off entirely (long-press does nothing).
  final void Function(int id)? onToggleSelected;

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
    final slivers = <Widget>[];
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
      final tiles = <Widget>[];
      for (var k = i; k < j; k++) {
        final d = _shown[k];
        final tile = TransactionTile(
          details: d,
          selectionMode: widget.selectedIds.isNotEmpty,
          selected: widget.selectedIds.contains(d.transaction.id),
          onToggleSelected: widget.onToggleSelected == null
              ? null
              : () => widget.onToggleSelected!(d.transaction.id),
        );
        if (_exiting.contains(d.transaction.id)) {
          tiles.add(_CollapseOut(
            key: ValueKey('exit-${d.transaction.id}'),
            child: tile,
          ));
        } else {
          tiles.add(
            Entrance(
              key: ValueKey('tx-${d.transaction.id}'),
              delay:
                  Duration(milliseconds: (40 * (k - i)).clamp(0, 320)),
              child: tile,
            ),
          );
        }
      }
      slivers.add(
        SliverStickyHeader(
          header: Container(
            // Solid backdrop so rows slide under the pinned header.
            color: Theme.of(context).scaffoldBackgroundColor,
            child: DateGroupHeader(day: day, net: net),
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate(tiles),
          ),
        ),
      );
      i = j;
    }
    return CustomScrollView(
      controller: widget.controller,
      slivers: [
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
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
