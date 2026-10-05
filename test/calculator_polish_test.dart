import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/core/widgets/calculator_sheet.dart';

/// Calculator polish: grouped expression display, long-press shortcuts,
/// invalid "=" feedback.
void main() {
  testWidgets('expression groups thousands and long-press works',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init(); // default currency IDR -> '.' grouping

    int? applied;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                applied = await showCalculatorSheet(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Type 5000000 -> expression shows grouped.
    for (final d in '5000000'.split('')) {
      await tester.tap(find.text(d).first);
      await tester.pump();
    }
    expect(find.text('5.000.000'), findsOneWidget);

    // Long-press 0 appends "00".
    await tester.longPress(find.text('0').first);
    await tester.pump();
    expect(find.text('500.000.000'), findsOneWidget);

    // Long-press backspace clears everything (grouped text gone).
    await tester.longPress(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(find.text('500.000.000'), findsNothing);

    // Invalid "=" (empty expression) does not pop the sheet.
    await tester.tap(find.text('=').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('5.000.000'), findsNothing);
    expect(applied, isNull);

    // Valid expression applies the rounded result.
    for (final d in '250000'.split('')) {
      await tester.tap(find.text(d).first);
      await tester.pump();
    }
    await tester.tap(find.text('=').first);
    await tester.pumpAndSettle();
    expect(applied, 250000);
  });
}
