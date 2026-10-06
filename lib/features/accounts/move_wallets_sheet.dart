import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/form_sheet.dart';
import '../../data/database/app_database.dart';

/// Result of the move-wallets sheet.
class MoveWalletsResult {
  MoveWalletsResult(this.walletIds, this.destinationId);

  final List<int> walletIds;
  final int destinationId;
}

/// "Move wallets" as a bottom sheet, matching the other form sheets:
/// wallet checkboxes and a destination picker rendered as chips.
class MoveWalletsSheet extends ConsumerStatefulWidget {
  const MoveWalletsSheet({
    super.key,
    required this.source,
    required this.wallets,
    required this.destinations,
  });

  final Account source;
  final List<Wallet> wallets;
  final List<Account> destinations;

  @override
  ConsumerState<MoveWalletsSheet> createState() => _MoveWalletsSheetState();
}

class _MoveWalletsSheetState extends ConsumerState<MoveWalletsSheet> {
  final _picked = <int>{};
  late int _destinationId = widget.destinations.first.id;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: 'Move wallets',
      subtitle: 'From ${widget.source.name}',
      actionLabel: 'Move',
      onAction: _save,
      busy: _saving,
      actionEnabled: _picked.isNotEmpty && !_saving,
      children: [
        const FormSectionLabel('Wallets'),
        for (final w in widget.wallets)
          CheckboxListTile(
            value: _picked.contains(w.id),
            onChanged: (v) => setState(() {
              if (v == true) {
                _picked.add(w.id);
              } else {
                _picked.remove(w.id);
              }
            }),
            title: Text(w.name),
            subtitle: Text(formatMoney(w.balance),
                style: TextStyle(color: context.textMuted, fontSize: 12)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        const SizedBox(height: 8),
        const FormSectionLabel('Move to'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in widget.destinations)
              ChoiceChip(
                label: Text(a.name),
                selected: _destinationId == a.id,
                selectedColor: context.accent,
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: _destinationId == a.id
                      ? onAccent(context.accent)
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) =>
                    setState(() => _destinationId = a.id),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_picked.isEmpty) return;
    setState(() => _saving = true);
    if (mounted) {
      Navigator.pop(
          context, MoveWalletsResult(_picked.toList(), _destinationId));
    }
  }
}
