import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_accents.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/glass_card.dart';

/// Change the display currency after the initial setup.
///
/// Amounts are stored as plain numbers, so switching currency only
/// changes the symbol and number formatting — existing amounts are
/// NOT converted. The user confirms this explicitly before saving.
class CurrencyScreen extends ConsumerStatefulWidget {
  const CurrencyScreen({super.key});

  @override
  ConsumerState<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends ConsumerState<CurrencyScreen> {
  late String _code = AppPrefs.currencyCode;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsCurrency)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          GlassCard(
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: AppColors.violet, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.settingsCurrencyInfo,
                    style: TextStyle(
                        color: context.textMuted, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final c in supportedCurrencies)
            _currencyTile(c),
        ],
      ),
    );
  }

  Widget _currencyTile(AppCurrency c) {
    final isSelected = c.code == _code;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      title: Text(
        c.label,
        style: TextStyle(
          color: isSelected ? context.accent : context.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: context.accent)
          : null,
      onTap: _saving || isSelected ? null : () => _confirmSwitch(c),
    );
  }

  Future<void> _confirmSwitch(AppCurrency c) async {
    final l10n = AppLocalizations.of(context)!;
    final current = currencyByCode(AppPrefs.currencyCode);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.settingsCurrencySwitchTitle),
        content: Text(
          l10n.settingsCurrencySwitchBody(
            c.code,
            c.name,
            formatMoneyWith(c.code, 100000),
            formatMoneyWith(current.code, 100000),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settingsCurrencySwitch),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await AppPrefs.setCurrencyCode(c.code);
      if (!mounted) return;
      setState(() => _code = c.code);
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
