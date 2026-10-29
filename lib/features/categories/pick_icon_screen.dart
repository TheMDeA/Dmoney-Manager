import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/category_icons.dart';

/// Full-screen icon picker: grouped grids with a DONE action.
/// Returns the selected icon key, or null if cancelled.
class PickIconScreen extends StatefulWidget {
  const PickIconScreen({super.key, required this.initialKey});

  final String initialKey;

  @override
  State<PickIconScreen> createState() => _PickIconScreenState();
}

class _PickIconScreenState extends State<PickIconScreen> {
  late String _selected;

  /// The section titles live in the const [iconPickerSections] list
  /// (lib/core/utils/category_icons.dart, outside this batch), so they
  /// are translated at the display site. An unknown title falls back to
  /// itself so a future section still renders instead of breaking.
  String _sectionTitle(AppLocalizations l10n, String title) {
    switch (title) {
      case 'General':
        return l10n.categoryIconGeneral;
      case 'Food & Drinks':
        return l10n.categoryIconFoodDrinks;
      case 'Home & Living':
        return l10n.categoryIconHomeLiving;
      case 'Transport':
        return l10n.categoryIconTransport;
      case 'Shopping':
        return l10n.categoryIconShopping;
      case 'Money & Work':
        return l10n.categoryIconMoneyWork;
      case 'Health & Fitness':
        return l10n.categoryIconHealthFitness;
      case 'Fun & Hobbies':
        return l10n.categoryIconFunHobbies;
      default:
        return title;
    }
  }

  @override
  void initState() {
    super.initState();
    _selected = widget.initialKey;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.categoryPickIconTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: Text(l10n.categoryDoneAction),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final section in iconPickerSections) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _sectionTitle(l10n, section.title),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 12,
                ),
                itemCount: section.entries.length,
                itemBuilder: (context, i) {
                  final entry = section.entries[i];
                  final selected = entry.key == _selected;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = entry.key),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? context.accent
                            : context.raised,
                      ),
                      child: Icon(
                        entry.icon,
                        size: 28,
                        color: selected
                            ? onAccent(context.accent)
                            : context.textMuted,
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
