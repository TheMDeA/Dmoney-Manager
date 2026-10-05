import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/data/database/app_database.dart';
import 'package:dmoney_manager/features/home/widgets/ai_insight_card.dart';
import 'package:dmoney_manager/state/providers.dart';

/// Insight sessions: 3 random insights per session from the eligible set,
/// tappable dots, pause while expanded. Verified via the selected dot
/// (width 16) rather than headline text, because AnimatedSwitcher
/// transitions don't settle under single large test pumps.
void main() {
  testWidgets('session picks 3, dots jump, cycle pauses while expanded',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
    await initializeDateFormatting();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final accountId = await db.addAccount(
        AccountsCompanion.insert(name: 'Personal', kind: 'personal'));
    final cash = await db.createWallet(
        accountId: accountId, name: 'Cash', kind: 'cash', initialAmount: 0);
    final bank = await db.createWallet(
        accountId: accountId, name: 'Bank', kind: 'bank', initialAmount: 0);
    final food = await db.addCategory(
        CategoriesCompanion.insert(name: 'Food', kind: 'expense'));
    final transport = await db.addCategory(
        CategoriesCompanion.insert(name: 'Transport', kind: 'expense'));
    final salary = await db.addCategory(
        CategoriesCompanion.insert(name: 'Salary', kind: 'income'));

    final now = DateTime.now();
    Future<void> tx({
      required int cat,
      required int wallet,
      required String kind,
      required int amount,
      required DateTime date,
      String note = '',
    }) =>
        db.addTransaction(TransactionsCompanion.insert(
          walletId: wallet,
          categoryId: cat,
          kind: kind,
          amount: amount,
          date: date,
          note: Value(note),
        ));

    await tx(cat: food, wallet: cash, kind: 'expense', amount: 200000,
        date: now.subtract(const Duration(days: 2)), note: 'Indomaret');
    await tx(cat: food, wallet: cash, kind: 'expense', amount: 20000,
        date: now.subtract(const Duration(days: 10)), note: 'Indomaret');
    await tx(cat: food, wallet: cash, kind: 'expense', amount: 100000,
        date: now.subtract(const Duration(days: 40)), note: 'Indomaret');
    await tx(cat: transport, wallet: bank, kind: 'expense', amount: 50000,
        date: now.subtract(const Duration(days: 1)), note: 'WSS');
    await tx(cat: salary, wallet: bank, kind: 'income', amount: 1000000,
        date: now.subtract(const Duration(days: 5)), note: 'Salary');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: AiInsightCard())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Session picked exactly 3 insights -> 3 tappable dots.
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('insight_dot_$i')), findsOneWidget);
    }

    double dotWidth(int i) {
      final f = find.descendant(
        of: find.byKey(ValueKey('insight_dot_$i')),
        matching: find.byType(AnimatedContainer),
      );
      return tester.getSize(f).width;
    }

    Future<void> pumpMs(int ms) async {
      for (var t = 0; t < ms; t += 100) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    int selectedDot() {
      for (var i = 0; i < 3; i++) {
        if (dotWidth(i) > 10) return i;
      }
      return -1;
    }

    // Headlines are real insight copy, not placeholders.
    final headlines = tester
        .widgetList<Text>(find.descendant(
            of: find.byType(AiInsightCard),
            matching: find.byType(Text)))
        .map((t) => t.data ?? '')
        .where((s) => s.isNotEmpty && s != '—')
        .toList();
    expect(headlines, isNotEmpty);
    expect(headlines.first, isNot(contains('insight')));

    expect(selectedDot(), 0);

    // Tapping the second dot jumps straight to it.
    await tester.tap(find.byKey(const ValueKey('insight_dot_1')));
    await pumpMs(500);
    expect(selectedDot(), 1);

    // Expanding pauses the cycle: 7s pass, selection doesn't move.
    await tester.tap(find.byType(InkWell).first);
    await pumpMs(500);
    expect(selectedDot(), 1);
    await pumpMs(7000);
    expect(selectedDot(), 1);

    // Collapsing resumes: the 6s cycle advances to the next insight.
    await tester.tap(find.byType(InkWell).first);
    await pumpMs(7000);
    expect(selectedDot(), 2);

    await db.close();
  });
}
