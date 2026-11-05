import 'package:flutter_test/flutter_test.dart';

import 'package:dmoney_manager/core/utils/paylater.dart';
import 'package:dmoney_manager/data/database/app_database.dart';

/// Billing-cycle due dates, modelled on how the real providers bill
/// (GoPay Later: statement on the 15th, due the 1st; SPayLater:
/// statement on the 1st/15th/21st/25th with its published due dates;
/// the generic statement-10th/due-25th example). A purchase belongs
/// to the statement whose cycle contains it; installments ride the
/// same cycles. Wallets without a statement day keep the legacy
/// month-after-creation anchoring.
void main() {
  InstallmentPlan plan({
    required DateTime created,
    required int paid,
    int count = 3,
  }) =>
      InstallmentPlan(
        id: 1,
        walletId: 7,
        name: 'Plan',
        totalAmount: 300000,
        installmentAmount: 100000,
        totalCount: count,
        paidCount: paid,
        createdAt: created,
      );

  Wallet wallet({int? statementDay, int? dueDay, int balance = -500000}) =>
      Wallet(
        id: 7,
        accountId: 1,
        name: 'Paylater',
        kind: 'paylater',
        balance: balance,
        initialAmount: 0,
        colorHex: '#000000',
        sortOrder: 0,
        statementDay: statementDay,
        dueDay: dueDay,
      );

  group('statementDateFor', () {
    test('purchase before the statement day bills on it', () {
      expect(
        statementDateFor(
            purchaseDate: DateTime(2026, 1, 7), statementDay: 15),
        DateTime(2026, 1, 15),
      );
      expect(
        statementDateFor(
            purchaseDate: DateTime(2026, 1, 14), statementDay: 15),
        DateTime(2026, 1, 15),
      );
    });

    test('purchase on or after the statement day rolls to next month',
        () {
      expect(
        statementDateFor(
            purchaseDate: DateTime(2026, 1, 15), statementDay: 15),
        DateTime(2026, 2, 15),
      );
      expect(
        statementDateFor(
            purchaseDate: DateTime(2026, 1, 31), statementDay: 15),
        DateTime(2026, 2, 15),
      );
      // Statement day 1: a purchase on the 1st itself opens a cycle.
      expect(
        statementDateFor(
            purchaseDate: DateTime(2026, 1, 1), statementDay: 1),
        DateTime(2026, 2, 1),
      );
      expect(
        statementDateFor(
            purchaseDate: DateTime(2026, 12, 31), statementDay: 1),
        DateTime(2027, 1, 1),
      );
    });

    test('statement day clamps to short months', () {
      expect(
        statementDateFor(
            purchaseDate: DateTime(2026, 2, 10), statementDay: 31),
        DateTime(2026, 2, 28),
      );
      // Feb 28 IS the clamped statement day — the next cycle opens.
      expect(
        statementDateFor(
            purchaseDate: DateTime(2026, 2, 28), statementDay: 31),
        DateTime(2026, 3, 31),
      );
    });
  });

  group('dueDateForStatement', () {
    test('published provider mappings', () {
      // Generic example: statement 10th → due 25th, same month.
      expect(
        dueDateForStatement(statementDate: DateTime(2026, 8, 10), dueDay: 25),
        DateTime(2026, 8, 25),
      );
      // SPayLater's table: 1st → 11th, 15th → 25th (same month);
      // 21st → Sep 1st, 25th → Sep 5th (next month).
      expect(
        dueDateForStatement(statementDate: DateTime(2026, 8, 1), dueDay: 11),
        DateTime(2026, 8, 11),
      );
      expect(
        dueDateForStatement(statementDate: DateTime(2026, 8, 15), dueDay: 25),
        DateTime(2026, 8, 25),
      );
      expect(
        dueDateForStatement(statementDate: DateTime(2026, 8, 21), dueDay: 1),
        DateTime(2026, 9, 1),
      );
      expect(
        dueDateForStatement(statementDate: DateTime(2026, 8, 25), dueDay: 5),
        DateTime(2026, 9, 5),
      );
    });
  });

  group('nextInstallmentDueDate — billing cycle', () {
    // GoPay Later's own worked example: statement 15th, due 1st.
    test('purchase before statement day: due Feb/Mar/Apr 1', () {
      final created = DateTime(2026, 1, 7);
      expect(
        nextInstallmentDueDate(plan(created: created, paid: 0), 1,
            walletStatementDay: 15),
        DateTime(2026, 2, 1),
      );
      expect(
        nextInstallmentDueDate(plan(created: created, paid: 1), 1,
            walletStatementDay: 15),
        DateTime(2026, 3, 1),
      );
      expect(
        nextInstallmentDueDate(plan(created: created, paid: 2), 1,
            walletStatementDay: 15),
        DateTime(2026, 4, 1),
      );
    });

    test('purchase after statement day waits a full extra cycle', () {
      // GoPay's second example: buy on the 17th → billed Feb 15 →
      // payments start Mar 1 (the legacy math said Feb 1).
      final created = DateTime(2026, 1, 17);
      expect(
        nextInstallmentDueDate(plan(created: created, paid: 0), 1,
            walletStatementDay: 15),
        DateTime(2026, 3, 1),
      );
      expect(
        nextInstallmentDueDate(plan(created: created, paid: 1), 1,
            walletStatementDay: 15),
        DateTime(2026, 4, 1),
      );
    });

    test('SPayLater config: statement 1st, due 11th', () {
      final created = DateTime(2026, 7, 20);
      expect(
        nextInstallmentDueDate(plan(created: created, paid: 0), 11,
            walletStatementDay: 1),
        DateTime(2026, 8, 11),
      );
      expect(
        nextInstallmentDueDate(plan(created: created, paid: 1), 11,
            walletStatementDay: 1),
        DateTime(2026, 9, 11),
      );
    });

    test('complete plan has no due date', () {
      expect(
        nextInstallmentDueDate(
            plan(created: DateTime(2026, 1, 7), paid: 3), 1,
            walletStatementDay: 15),
        isNull,
      );
    });
  });

  group('nextInstallmentDueDate — legacy fallback (no statement day)',
      () {
    test('month after creation, unchanged', () {
      expect(
        nextInstallmentDueDate(
            plan(created: DateTime(2026, 1, 17), paid: 0), 1),
        DateTime(2026, 2, 1),
      );
    });

    test('statement day without a due day stays legacy', () {
      expect(
        nextInstallmentDueDate(
            plan(created: DateTime(2026, 1, 17), paid: 0), null,
            walletStatementDay: 15),
        DateTime(2026, 2, 17),
      );
    });
  });

  group('walletNextDueDate', () {
    test('cycle mode follows statement due dates', () {
      final w = wallet(statementDay: 15, dueDay: 1);
      expect(walletNextDueDate(w, DateTime(2026, 1, 20)),
          DateTime(2026, 2, 1));
      expect(walletNextDueDate(w, DateTime(2026, 2, 1)),
          DateTime(2026, 2, 1));
      expect(walletNextDueDate(w, DateTime(2026, 2, 2)),
          DateTime(2026, 3, 1));
    });

    test('cycle mode with same-month due day', () {
      final w = wallet(statementDay: 10, dueDay: 25);
      expect(walletNextDueDate(w, DateTime(2026, 8, 5)),
          DateTime(2026, 8, 25));
      expect(walletNextDueDate(w, DateTime(2026, 8, 26)),
          DateTime(2026, 9, 25));
    });

    test('legacy mode without a statement day', () {
      final w = wallet(dueDay: 11);
      expect(walletNextDueDate(w, DateTime(2026, 11, 5)),
          DateTime(2026, 11, 11));
      expect(walletNextDueDate(w, DateTime(2026, 11, 12)),
          DateTime(2026, 12, 11));
    });

    test('no due day → null', () {
      expect(walletNextDueDate(wallet(statementDay: 15), DateTime(2026, 1, 1)),
          isNull);
    });
  });
}
