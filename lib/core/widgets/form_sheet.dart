import 'package:flutter/material.dart';

import '../theme/app_accents.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/category_icons.dart';
import '../utils/formatters.dart';
import '../utils/haptics.dart';
import 'amount_field.dart';

/// Shared bottom-sheet language for every add/edit form in the app
/// (wallet, budget, savings goal, transaction, transfer).
///
/// Every sheet gets the same anatomy: a grabber, a bold title, section
/// labels, rounded fields, a large money entry where it applies, and a
/// pinned full-width primary action that follows the theme accent.
Future<T?> showFormSheet<T>(
  BuildContext context,
  Widget Function(BuildContext) builder,
) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: builder,
  );
}

/// Shows a bottom sheet that can present snackbars on the front layer.
///
/// A bare nested ScaffoldMessenger can't present — it needs a [Scaffold]
/// to present through. [SheetScaffold] provides one, full-screen and
/// transparent, so the root messenger has something to present through
/// while the visible sheet stays content-sized.
Future<T?> showSnackSheet<T>(
  BuildContext context,
  Widget Function(BuildContext) builder, {
  Color? backgroundColor,
  double borderRadius = 24,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SheetScaffold(
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
      borderRadius: borderRadius,
      child: builder(context),
    ),
  );
}

/// Sheet wrapper for sheets that need snackbars on the front layer.
///
/// A bare nested ScaffoldMessenger can't present — it needs a [Scaffold]
/// to present through — but a Scaffold expands to fill the screen, which
/// would stretch the sheet's own background full screen too. This keeps
/// the Scaffold full-screen and transparent (snackbars present at the
/// screen bottom, above the sheet) while the visible sheet is a separate
/// content-sized [Material], bottom-aligned inside it and capped at 75%
/// of the screen height like [FormSheet].
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderRadius = 24,
  });

  final Widget child;
  final Color? backgroundColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Material(
            color: backgroundColor ?? theme.bottomSheetTheme.backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(borderRadius),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The sheet scaffold: grabber, title, scrollable content and a pinned
/// primary action at the bottom.
class FormSheet extends StatelessWidget {
  const FormSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    required this.actionLabel,
    required this.onAction,
    this.actionEnabled = true,
    this.busy = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool actionEnabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // Never cover the whole screen: cap the sheet at three-quarters
    // of the display height.
    final maxHeight = MediaQuery.of(context).size.height * 0.75;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(color: context.textMuted, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: FilledButton(
                  onPressed: (actionEnabled && !busy) ? onAction : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: context.accent,
                    foregroundColor: onAccent(context.accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: busy
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: onAccent(context.accent),
                          ),
                        )
                      : Text(
                          actionLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section label used above every field group.
class FormSectionLabel extends StatelessWidget {
  const FormSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Pill button that opens a date picker — the standard "date tile" of the
/// form language. Shows [placeholder] when [date] is null; an optional
/// clear button appears once a date is set.
class FormDatePill extends StatelessWidget {
  const FormDatePill({
    super.key,
    required this.date,
    required this.placeholder,
    required this.onTap,
    this.onClear,
    this.icon = Icons.calendar_today_outlined,
    this.text,
  });

  final DateTime? date;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final IconData icon;

  /// When non-null, shown instead of the formatted [date] — e.g. a time
  /// pill reusing the same styling.
  final String? text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Haptics.light();
              onTap();
            },
            icon: Icon(icon, size: 18),
            label: Text(
              text ?? (date == null ? placeholder : formatDate(date!)),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        if (date != null && onClear != null) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Clear date',
            icon: const Icon(Icons.close),
            onPressed: () {
              Haptics.light();
              onClear!();
            },
          ),
        ],
      ],
    );
  }
}

/// Row of selectable color dots, as used by the category form.
class ColorDots extends StatelessWidget {
  const ColorDots({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final hex in availableColors)
          GestureDetector(
            onTap: () {
              Haptics.light();
              onSelected(hex);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorFromHex(hex),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == hex
                      ? context.textPrimary
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: selected == hex
                  ? Icon(
                      Icons.check,
                      color: onAccent(colorFromHex(hex)),
                      size: 20,
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

/// A single-select chip row used for small fixed option sets
/// (wallet type, account, …).
class FormChoiceChips<T> extends StatelessWidget {
  const FormChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  final List<T> options;
  final T selected;
  final String Function(T) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(labelFor(o)),
            selected: selected == o,
            selectedColor: accent,
            showCheckmark: false,
            labelStyle: TextStyle(
              color: selected == o
                  ? onAccent(accent)
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            onSelected: (_) {
              Haptics.light();
              onSelected(o);
            },
          ),
      ],
    );
  }
}

/// Large money entry shared by the amount-first sheets.
class FormAmountEntry extends StatelessWidget {
  const FormAmountEntry({
    super.key,
    required this.controller,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return AmountField(
      controller: controller,
      autofocus: autofocus,
      style: AppTextStyles.displayBalance.copyWith(fontSize: 36),
    );
  }
}
