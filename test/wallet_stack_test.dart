import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/data/database/app_database.dart';
import 'package:dmoney_manager/features/wallets/wallets_screen.dart';
import 'package:dmoney_manager/state/providers.dart';

/// Regression test for the wallet card stack redesign.
///
/// Covers the three defects Miko reported from screenshots:
/// 1. Focus switches must animate (stable ValueKeys directly on the
///    AnimatedPositioned, no keyless Builder in between that would destroy
///    and recreate the positioned widgets on reorder).
/// 2. The fan's visible strip must be each card's TOP (compact header), not
///    a slice through the middle of the card content.
/// 3. Tucked cards must stay fully opaque (dimmed overlapping cards blend
///    their text into an unreadable jumble).
void main() {
  testWidgets('wallet stack fans, focuses, and animates cleanly',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
    await initializeDateFormatting();
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    final ids = <int>[];
    for (final (name, kind, balance, color) in [
      ('Cash', 'cash', 30832739, '#00E5A0'),
      ('BCA', 'bank', 195774928, '#1E5EFF'),
      ('GoPay', 'ewallet', 18877420, '#00AED6'),
      ('Jago', 'bank', 0, '#FFB300'),
    ]) {
      ids.add(
        await db.addWallet(
          WalletsCompanion.insert(
            accountId: 1,
            name: name,
            kind: kind,
            balance: Value(balance),
            initialAmount: Value(balance),
            colorHex: Value(color),
          ),
        ),
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: WalletsScreen()),
      ),
    );
    await tester.pump();
    // Let streams emit and the entrance animation finish.
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);

    // Rendered geometry (the widget's top/height are animation targets).
    // Measured as card-to-card differences so the stack's screen offset
    // cancels out.
    double renderedTop(int id) => tester.getTopLeft(find.byKey(ValueKey(id))).dy;
    double renderedHeight(int id) => tester.getSize(find.byKey(ValueKey(id))).height;

    // Fan geometry: card i sits 104px below card 0, all 188 tall.
    expect(renderedTop(ids[1]) - renderedTop(ids[0]), 104);
    expect(renderedTop(ids[2]) - renderedTop(ids[0]), 208);
    expect(renderedTop(ids[3]) - renderedTop(ids[0]), 312);
    for (final id in ids) {
      expect(renderedHeight(id), 188);
    }

    // No dimming anywhere in the stack: cards must stay opaque.
    expect(find.byType(AnimatedOpacity), findsNothing);

    // Tap the second card's header (visible strip is the card top).
    await tester.tap(find.text('BCA'));
    await tester.pump();
    // Mid-animation the card must be BETWEEN fan and focused geometry:
    // animating, not jumping.
    await tester.pump(const Duration(milliseconds: 300));
    // BCA travels from +104 (fan) to -496 (focused, above Cash): mid-flight
    // it must be strictly between, proving it animates instead of jumping.
    final midTop = renderedTop(ids[1]) - renderedTop(ids[0]);
    expect(midTop, lessThan(104));
    expect(midTop, greaterThan(-496));
    final midHeight = renderedHeight(ids[1]);
    expect(midHeight, greaterThan(188));
    expect(midHeight, lessThan(480));

    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    // Focused card expanded at the top; others tucked below as compact
    // 120px headers with 8px gaps, in fan order.
    expect(renderedTop(ids[1]) - renderedTop(ids[0]), lessThan(0));
    expect(renderedHeight(ids[1]), 480);
    expect(renderedTop(ids[0]) - renderedTop(ids[1]), 480 + 16);
    expect(renderedTop(ids[2]) - renderedTop(ids[1]), 480 + 16 + 128);
    expect(renderedTop(ids[3]) - renderedTop(ids[1]), 480 + 16 + 256);
    expect(renderedHeight(ids[0]), 120);
    expect(renderedHeight(ids[2]), 120);
    expect(renderedHeight(ids[3]), 120);

    // Switching focus to another card animates too (keys stay stable
    // across the reorder): GoPay's height must be mid-flight, not jumped.
    await tester.ensureVisible(find.text('GoPay'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('GoPay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final midHeight2 = renderedHeight(ids[2]);
    expect(midHeight2, greaterThan(120));
    expect(midHeight2, lessThan(480));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(renderedHeight(ids[2]), 480);
    expect(renderedHeight(ids[1]), 120);

    await db.close();
  });
}
