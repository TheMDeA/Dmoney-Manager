import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/empty_state.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';
import 'widgets/transaction_tile.dart';

/// Full transaction history list.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: StreamBuilder<List<TransactionWithDetails>>(
        stream: db.watchTransactions(),
        builder: (context, snap) {
          final items = snap.data ?? const <TransactionWithDetails>[];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'No transactions yet. Tap + to record your first one.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            itemCount: items.length,
            itemBuilder: (_, i) => TransactionTile(details: items[i]),
          );
        },
      ),
    );
  }
}
