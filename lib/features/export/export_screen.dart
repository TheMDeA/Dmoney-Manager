import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// Export data to CSV / Excel for analysis, backup, or printing.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  String _format = 'csv';
  String _range = 'month';
  bool _includeTransactions = true;
  bool _includeBudgets = true;
  bool _includeDebts = true;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export data')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('Format', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'csv', label: Text('CSV')),
              ButtonSegment(value: 'excel', label: Text('Excel')),
            ],
            selected: {_format},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _format = s.first),
          ),
          const SizedBox(height: 20),
          Text('Date range', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'month', label: Text('This month')),
              ButtonSegment(value: 'quarter', label: Text('3 months')),
              ButtonSegment(value: 'all', label: Text('All time')),
            ],
            selected: {_range},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _range = s.first),
          ),
          const SizedBox(height: 20),
          Text('Include', style: Theme.of(context).textTheme.labelLarge),
          SwitchListTile(
            value: _includeTransactions,
            onChanged: (v) => setState(() => _includeTransactions = v),
            title: const Text('Transactions'),
          ),
          SwitchListTile(
            value: _includeBudgets,
            onChanged: (v) => setState(() => _includeBudgets = v),
            title: const Text('Budgets & goals'),
          ),
          SwitchListTile(
            value: _includeDebts,
            onChanged: (v) => setState(() => _includeDebts = v),
            title: const Text('Debts'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _exporting ? null : _export,
            icon: _exporting
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_download_outlined),
            label: Text(_exporting ? 'Exporting…' : 'Export'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.lime,
              foregroundColor: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'The file is saved to a temporary location and opened in the share sheet so you can save, print, or send it anywhere.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  (DateTime, DateTime) _bounds() {
    final now = DateTime.now();
    switch (_range) {
      case 'month':
        return (DateTime(now.year, now.month), now);
      case 'quarter':
        return (DateTime(now.year, now.month - 3, now.day), now);
      default:
        return (DateTime(2000), now);
    }
  }

  Future<void> _export() async {
    if (!_includeTransactions && !_includeBudgets && !_includeDebts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one dataset')),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final db = ref.read(databaseProvider);
      final (from, to) = _bounds();
      final ext = _format == 'csv' ? 'csv' : 'xlsx';

      late final List<int> bytes;
      if (_format == 'csv') {
        bytes = (await _buildCsv(db, from, to)).codeUnits;
      } else {
        bytes = await _buildExcel(db, from, to);
      }

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/money_manager_export_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(bytes);

      if (mounted) {
        await SharePlus.instance.share(
          ShareParams(
            text: 'Dmoney Manager export',
            files: [XFile(file.path)],
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export ready')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<String> _buildCsv(
      AppDatabase db, DateTime from, DateTime to) async {
    final rows = <List<dynamic>>[];
    if (_includeTransactions) {
      final txs = await db.getTransactionsInRange(from, to);
      rows.add(['TRANSACTIONS']);
      rows.add(['Date', 'Wallet', 'Category', 'Type', 'Amount (IDR)', 'Note']);
      for (final d in txs) {
        rows.add([
          formatDate(d.transaction.date),
          d.wallet.name,
          d.category.name,
          d.transaction.kind,
          d.transaction.amount,
          d.transaction.note,
        ]);
      }
      rows.add([]);
    }
    if (_includeBudgets) {
      final budgets = await db.select(db.budgets).get();
      final cats = {
        for (final c in await db.select(db.categories).get()) c.id: c.name
      };
      rows.add(['BUDGETS']);
      rows.add(['Month', 'Category', 'Limit (IDR)']);
      for (final b in budgets) {
        rows.add([b.month, cats[b.categoryId] ?? '', b.limit]);
      }
      rows.add([]);
      final goals = await db.select(db.goals).get();
      rows.add(['SAVINGS GOALS']);
      rows.add(['Goal', 'Target (IDR)', 'Saved (IDR)']);
      for (final g in goals) {
        rows.add([g.name, g.target, g.saved]);
      }
      rows.add([]);
    }
    if (_includeDebts) {
      final debts = await db.select(db.debts).get();
      rows.add(['DEBTS']);
      rows.add(['Person', 'Note', 'Direction', 'Amount (IDR)', 'Paid']);
      for (final d in debts) {
        rows.add(
            [d.person, d.note, d.direction, d.amount, d.isPaid ? 'yes' : 'no']);
      }
    }
    return Csv().encode(rows);
  }

  Future<List<int>> _buildExcel(AppDatabase db, DateTime from, DateTime to) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    if (_includeTransactions) {
      final txs = await db.getTransactionsInRange(from, to);
      final sheet = excel['Transactions'];
      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Wallet'),
        TextCellValue('Category'),
        TextCellValue('Type'),
        TextCellValue('Amount (IDR)'),
        TextCellValue('Note'),
      ]);
      for (final d in txs) {
        sheet.appendRow([
          TextCellValue(formatDate(d.transaction.date)),
          TextCellValue(d.wallet.name),
          TextCellValue(d.category.name),
          TextCellValue(d.transaction.kind),
          IntCellValue(d.transaction.amount),
          TextCellValue(d.transaction.note),
        ]);
      }
    }
    if (_includeBudgets) {
      final budgets = await db.select(db.budgets).get();
      final cats = {for (final c in await db.select(db.categories).get()) c.id: c.name};
      final sheet = excel['Budgets'];
      sheet.appendRow([TextCellValue('Month'), TextCellValue('Category'), TextCellValue('Limit (IDR)')]);
      for (final b in budgets) {
        sheet.appendRow([
          TextCellValue(b.month),
          TextCellValue(cats[b.categoryId] ?? ''),
          IntCellValue(b.limit),
        ]);
      }
      final goals = await db.select(db.goals).get();
      final gSheet = excel['Goals'];
      gSheet.appendRow([TextCellValue('Goal'), TextCellValue('Target (IDR)'), TextCellValue('Saved (IDR)')]);
      for (final g in goals) {
        gSheet.appendRow([
          TextCellValue(g.name),
          IntCellValue(g.target),
          IntCellValue(g.saved),
        ]);
      }
    }
    if (_includeDebts) {
      final debts = await db.select(db.debts).get();
      final sheet = excel['Debts'];
      sheet.appendRow([
        TextCellValue('Person'),
        TextCellValue('Note'),
        TextCellValue('Direction'),
        TextCellValue('Amount (IDR)'),
        TextCellValue('Paid'),
      ]);
      for (final d in debts) {
        sheet.appendRow([
          TextCellValue(d.person),
          TextCellValue(d.note),
          TextCellValue(d.direction),
          IntCellValue(d.amount),
          TextCellValue(d.isPaid ? 'yes' : 'no'),
        ]);
      }
    }
    return excel.save() ?? [];
  }
}
