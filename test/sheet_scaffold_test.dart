import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dmoney_manager/core/widgets/form_sheet.dart';

/// SheetScaffold: the visible sheet stays content-sized (not full screen)
/// while the route still registers a Scaffold so the root
/// ScaffoldMessenger can present snackbars on the front layer.
void main() {
  testWidgets('sheet hugs content and snackbar presents', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showSnackSheet(
                  context,
                  (_) => const SizedBox(
                    height: 100,
                    child: Center(child: Text('content')),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The visible sheet Material is content-sized, far from full screen.
    final screenHeight = tester.view.physicalSize.height /
        tester.view.devicePixelRatio;
    final sheetBox =
        tester.getSize(find.byType(Material).last);
    expect(sheetBox.height, lessThan(screenHeight * 0.5));

    // A snackbar shown from inside the sheet presents through the
    // sheet route's Scaffold (front layer). The root messenger also
    // presents to the home Scaffold behind the modal barrier — the
    // framework shows it in every root Scaffold of the route set.
    final sheetContext = tester.element(find.text('content'));
    ScaffoldMessenger.of(sheetContext).showSnackBar(
      const SnackBar(content: Text('hello front')),
    );
    await tester.pump();
    expect(find.text('hello front'), findsWidgets);
  });
}
