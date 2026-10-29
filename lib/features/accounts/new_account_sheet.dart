import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/form_sheet.dart';
import '../../core/widgets/shaker.dart';

/// Result of the new-account sheet.
class NewAccountResult {
  NewAccountResult(this.name, this.colorHex);

  final String name;
  final String colorHex;
}

/// "New account" as a bottom sheet, matching the other form sheets:
/// name field with inline validation and a color picker.
class NewAccountSheet extends ConsumerStatefulWidget {
  const NewAccountSheet({super.key, required this.palette});

  final List<String> palette;

  @override
  ConsumerState<NewAccountSheet> createState() => _NewAccountSheetState();
}

class _NewAccountSheetState extends ConsumerState<NewAccountSheet> {
  final _ctrl = TextEditingController();
  late var _colorHex = widget.palette.first;
  bool _saving = false;

  String? _nameError;
  final _nameShake = ShakeController();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_clearError);
  }

  void _clearError() {
    if (_nameError != null) setState(() => _nameError = null);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_clearError);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FormSheet(
      title: l10n.accountNewTitle,
      actionLabel: l10n.accountCreateAction,
      onAction: _save,
      busy: _saving,
      children: [
        FormSectionLabel(l10n.accountNameLabel),
        const SizedBox(height: 8),
        Shaker(
          controller: _nameShake,
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: l10n.accountNameHint,
              errorText: _nameError,
            ),
          ),
        ),
        const SizedBox(height: 16),
        FormSectionLabel(l10n.accountColorLabel),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final hex in widget.palette)
              GestureDetector(
                onTap: () => setState(() => _colorHex = hex),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorFromHex(hex),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _colorHex == hex
                          ? context.textPrimary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: _colorHex == hex
                      ? Icon(Icons.check,
                          size: 20, color: onAccent(colorFromHex(hex)))
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      setState(() => _nameError = l10n.accountEnterName);
      _nameShake.shake();
      return;
    }
    setState(() => _saving = true);
    if (mounted) {
      Navigator.pop(context, NewAccountResult(name, _colorHex));
    }
  }
}
