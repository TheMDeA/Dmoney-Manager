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
/// Insertions animate in via [Entrance] — only ids that appeared in a data
/// update play it, so scrolling never replays animations. Removals collapse
/// out: rows deleted from [items] are kept rendered for one
/// [AppMotion.normal] beat inside [_CollapseOut], then the list swaps to the
/// new data. Wholesale changes (e.g. switching months) swap immediately
/// without the exit choreography.
///
/// Rows build lazily via [SliverChildBuilderDelegate] from precomputed
/// per-day index ranges, so a 10k-row history only instantiates visible
/// tiles instead of building (and animating) every row up front.
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
  State<GroupedTransactionList> createState() => _GroupedTransactionListState();
}

/// One day's slice of the list: an index range plus the precomputed net
/// total. Metadata only — rows themselves build lazily.
class _DayGroup {
  const _DayGroup({
    required this.day,
    required this.start,
    required this.end,
    required this.net,
  });

  final DateTime day;

  /// Index into the item list, inclusive.
  final int start;

  /// Index into the item list, exclusive.
  final int end;
  final int net;
}

class _GroupedTransactionListState extends State<GroupedTransactionList> {
  late List<TransactionWithDetails> _shown = widget.items;
  final Set<int> _exiting = {};

  /// Ids that appeared in a data update and haven't been presented yet:
  /// these (and only these) play the [Entrance] animation. Everything else
  /// renders plain, so scrolling never replays animations and animation
  /// controllers stay bounded by real insertions, not list size.
  final Set<int> _entering = {};
  bool _exitScheduled = false;
  var _groups = const <_DayGroup>[];

  @override
  void initState() {
    super.initState();
    _regroup();
  }

  /// Slices [_shown] into per-day index ranges. O(n) over cheap date
  /// comparisons — no widgets are built here.
  void _regroup() {
    final items = _shown;
    final groups = <_DayGroup>[];
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
      groups.add(_DayGroup(day: day, start: i, end: j, net: net));
      i = j;
    }
    _groups = groups;
  }

  @override
  void didUpdateWidget(covariant GroupedTransactionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(widget.items, oldWidget.items)) return;
    final prevIds = {for (final d in _shown) d.transaction.id};
    final newIds = {for (final d in widget.items) d.transaction.id};
    // Rows that appeared: animate only these on next build.
    _entering.addAll(newIds.difference(prevIds));
    // Rows that vanished entirely: drop stale animation flags.
    _entering.removeWhere((id) => !newIds.contains(id));
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
      _regroup();
      return;
    }
    if (removedIds.length * 2 > _shown.length) {
      // Wholesale change — swap with no choreography at all.
      _shown = widget.items;
      _exiting.clear();
      _entering.clear();
      _regroup();
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
          _regroup();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: widget.controller,
      slivers: [
        for (final g in _groups)
          SliverStickyHeader(
            header: Container(
              // Solid backdrop so rows slide under the pinned header.
              color: Theme.of(context).scaffoldBackgroundColor,
              child: DateGroupHeader(day: g.day, net: g.net),
            ),
            sliver: SliverList(
              // Builder delegate: only visible rows are instantiated.
              // The old list delegate built (and animated) every tile up
              // front — that was the 10k-row All-view crash.
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildTile(g.start + index, index),
                childCount: g.end - g.start,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  /// Builds one row. Only ids in [_entering] play [Entrance]; everything
  /// else renders plain via a keyed subtree so tile state survives
  /// rebuilds and scrolls.
  Widget _buildTile(int k, int dayOffset) {
    final d = _shown[k];
    final id = d.transaction.id;
    final tile = TransactionTile(
      details: d,
      selectionMode: widget.selectedIds.isNotEmpty,
      selected: widget.selectedIds.contains(id),
      onToggleSelected: widget.onToggleSelected == null
          ? null
          : () => widget.onToggleSelected!(id),
    );
    if (_exiting.contains(id)) {
      return _CollapseOut(key: ValueKey('exit-$id'), child: tile);
    }
    if (_entering.contains(id)) {
      return Entrance(
        key: ValueKey('tx-$id'),
        delay: Duration(milliseconds: (40 * dayOffset).clamp(0, 320)),
        child: tile,
      );
    }
    return KeyedSubtree(key: ValueKey('tx-$id'), child: tile);
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
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(parent: _controller, curve: AppMotion.exit);
    return SizeTransition(
      sizeFactor: Tween(begin: 1.0, end: 0.0).animate(anim),
      child: FadeTransition(
        opacity: Tween(begin: 1.0, end: 0.0).animate(anim),
        child: widget.child,
      ),
    );
  }
}
