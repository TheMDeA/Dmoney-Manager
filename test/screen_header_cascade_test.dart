import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dmoney_manager/core/widgets/screen_header.dart';
import 'package:dmoney_manager/state/providers.dart';

/// Letter-cascade entrance: hidden while its tab is inactive, plays when
/// the tab becomes active, replays on every return.
void main() {
  testWidgets('cascade plays on tab activation and replays', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: Builder(builder: (context) {
          container = ProviderScope.containerOf(context);
          return const MaterialApp(
            home: Scaffold(
              body: ScreenHeader(title: 'Stats', tabIndex: 3),
            ),
          );
        }),
      ),
    );
    await tester.pump();

    List<double> opacities() => tester
        .widgetList<Opacity>(find.descendant(
            of: find.byType(ScreenHeader), matching: find.byType(Opacity)))
        .map((o) => o.opacity)
        .toList();

    Future<void> pumpMs(int ms) async {
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // Screen reader still gets the full title as one label.
    expect(find.bySemanticsLabel('Stats'), findsOneWidget);

    // Tab 3 inactive -> cascade hasn't played, letters hidden.
    expect(opacities(), isNotEmpty);
    expect(opacities().every((o) => o == 0), isTrue);

    // Activating the tab plays the cascade to full visibility.
    container.read(tabIndexProvider.notifier).go(3);
    await pumpMs(900);
    final shown = opacities();
    expect(shown, isNotEmpty);
    expect(shown.every((o) => o == 1), isTrue);

    // Leaving and returning replays: hidden again right after activation,
    // visible after the animation completes.
    container.read(tabIndexProvider.notifier).go(0);
    await tester.pump();
    container.read(tabIndexProvider.notifier).go(3);
    await tester.pump();
    expect(opacities().every((o) => o == 0), isTrue);
    await pumpMs(900);
    expect(opacities().every((o) => o == 1), isTrue);
  });
}
