import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import '../transactions/widgets/transaction_tile.dart';

/// Search records by keyword, amount, or date.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  String _filter = 'all';
  final _recent = <String>[];

  /// Debounced query actually used for filtering. The field updates
  /// immediately for responsive typing, but the (potentially large)
  /// in-memory filter only re-runs 300ms after the user stops typing.
  String _query = '';
  bool _hasText = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String v) {
    final hasText = v.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = v.trim().toLowerCase());
    });
  }

  void _clearQuery() {
    _debounce?.cancel();
    _ctrl.clear();
    setState(() {
      _hasText = false;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final accountId = ref.watch(selectedAccountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Keyword, amount, or date…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _hasText
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearQuery,
                      )
                    : null,
              ),
              onChanged: _onQueryChanged,
              onSubmitted: (v) {
                final q = v.trim();
                _debounce?.cancel();
                setState(() => _query = q.toLowerCase());
                if (q.isNotEmpty && !_recent.contains(q)) {
                  setState(() => _recent.insert(0, q));
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final f in ['all', 'income', 'expense'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f[0].toUpperCase() + f.substring(1)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<TransactionWithDetails>>(
              stream: db.watchTransactions(accountId: accountId),
              builder: (context, snap) {
                final all = snap.data ?? const <TransactionWithDetails>[];
                final q = _query;

                if (q.isEmpty) {
                  if (_recent.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search,
                      message: 'Search by keyword, amount (e.g. 45000), or date.',
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Recent searches'),
                      ),
                      for (final r in _recent)
                        ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(r),
                          onTap: () {
                            _debounce?.cancel();
                            _ctrl.text = r;
                            setState(() {
                              _hasText = true;
                              _query = r.toLowerCase();
                            });
                          },
                        ),
                    ],
                  );
                }

                final results = all.where((d) {
                  final t = d.transaction;
                  if (_filter != 'all' && t.kind != _filter) return false;
                  return t.note.toLowerCase().contains(q) ||
                      t.memo.toLowerCase().contains(q) ||
                      d.category.name.toLowerCase().contains(q) ||
                      d.wallet.name.toLowerCase().contains(q) ||
                      t.amount.toString().contains(q) ||
                      formatDate(t.date).toLowerCase().contains(q);
                }).toList();

                if (results.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_outlined,
                    message: 'No records match your search.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: results.length,
                  itemBuilder: (_, i) => TransactionTile(details: results[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
