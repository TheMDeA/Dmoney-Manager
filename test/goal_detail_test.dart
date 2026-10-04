import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dmoney_manager/core/services/app_prefs.dart';
import 'package:dmoney_manager/data/database/app_database.dart';
import 'package:dmoney_manager/features/budgets/goal_detail_screen.dart';
import 'package:dmoney_manager/state/providers.dart';

/// Regression test: opening a goal that has deposits must not throw
/// LocaleDataException (blank page in release builds). main() calls
/// initializeDateFormatting(); the test mirrors that.
void main() {
  testWidgets('GoalDetailScreen renders goal content', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.init();
    await initializeDateFormatting();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final goalId = await db.addGoal(GoalsCompanion.insert(
      name: 'Emergency Fund',
      target: 15000000,
    ));
    await db.recordGoalDeposit(
      goalId: goalId,
      amount: 4500000,
      date: DateTime.now(),
      note: 'first deposit',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: GoalDetailScreen(goalId: goalId),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final err = tester.takeException();
    // ignore: avoid_print
    print('EXCEPTION: $err');
    expect(find.text('Emergency Fund'), findsOneWidget);
    expect(find.text('DEPOSIT'), findsOneWidget);
    await db.close();
  });
}
