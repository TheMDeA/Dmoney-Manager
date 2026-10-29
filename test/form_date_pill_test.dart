import 'package:flutter/material.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/widgets/form_sheet.dart';

/// FormDatePill must drop text-field focus before opening its picker:
/// otherwise the field keeps focus behind the dialog and the keyboard
/// pops back up when the dialog closes.
void main() {
  testWidgets('tapping the pill unfocuses the text field', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();

    final fieldFocus = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextField(focusNode: fieldFocus),
                FormDatePill(
                  date: DateTime(2026, 10, 19),
                  placeholder: 'Pick a date',
                  onTap: () async {
                    // Mimics showDatePicker: dialog opens and closes.
                    await showDialog(
                      context: context,
                      builder: (_) =>
                          const AlertDialog(content: Text('picker')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    fieldFocus.requestFocus();
    await tester.pump();
    expect(fieldFocus.hasFocus, isTrue);

    await tester.tap(find.byType(FormDatePill));
    await tester.pump();
    // Dialog opened...
    expect(find.text('picker'), findsOneWidget);
    // ...and the field lost focus before it did.
    expect(fieldFocus.hasFocus, isFalse);

    // Close the dialog: focus must not return to the field.
    Navigator.of(tester.element(find.text('picker'))).pop();
    await tester.pumpAndSettle();
    expect(fieldFocus.hasFocus, isFalse);
  });
}
