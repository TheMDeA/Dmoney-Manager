import 'package:dmoney_manager/core/widgets/sliding_segmented.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test: the sliding pill must align exactly with its segment.
/// The LayoutBuilder used to sit outside the container padding, making the
/// pill 2px too wide per segment — on the last segment it overflowed 6px
/// and the Stack clipped its rounded corners (visible as squared corners).
void main() {
  Future<void> pump(
    WidgetTester tester,
    String selected, {
    double width = 1000,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: SlidingSegmented<String>(
                values: const ['day', 'week', 'month'],
                labels: const ['Day', 'Week', 'Month'],
                selected: selected,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect pillRect(WidgetTester tester) {
    final finder = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).borderRadius ==
              BorderRadius.circular(100),
    );
    expect(finder, findsOneWidget);
    return tester.getRect(finder);
  }

  Rect stackRect(WidgetTester tester) =>
      tester.getRect(find.byType(Stack).first);

  for (final selected in ['day', 'week', 'month']) {
    testWidgets('pill aligns on "$selected"', (tester) async {
      await pump(tester, selected);
      final pill = pillRect(tester);
      final stack = stackRect(tester);
      final segWidth = stack.width / 3;
      final index = ['day', 'week', 'month'].indexOf(selected);

      // Pill sits exactly on its segment.
      expect(pill.left - stack.left, moreOrLessEquals(index * segWidth));
      expect(pill.width, moreOrLessEquals(segWidth));
      // Never overflows the stack (would clip the rounded corners).
      expect(pill.right, lessThanOrEqualTo(stack.right + 0.5));
      expect(pill.left, greaterThanOrEqualTo(stack.left - 0.5));
    });
  }

  testWidgets('pill aligns at odd widths', (tester) async {
    await pump(tester, 'month', width: 1000 - 7);
    final pill = pillRect(tester);
    final stack = stackRect(tester);
    expect(pill.right, lessThanOrEqualTo(stack.right + 0.5));
  });
}
