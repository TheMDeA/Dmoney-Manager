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

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
                suffixIcon: _ctrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(_ctrl.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (v) {
                final q = v.trim();
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
                final q = _ctrl.text.trim().toLowerCase();

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
                          onTap: () => setState(() => _ctrl.text = r),
                        ),
                    ],
                  );
                }

                final results = all.where((d) {
                  final t = d.transaction;
                  if (_filter != 'all' && t.kind != _filter) return false;
                  return t.note.toLowerCase().contains(q) ||
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
