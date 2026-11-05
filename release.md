## [2.8.2] - 2026-11-06

### Fixed

- The Paylater Next due card now adds up the installments that actually fall due on the next due date when a wallet has several plans, and paying it settles exactly those — it previously showed the full outstanding amount as due and paid all of it.
- Installment plans on paylater wallets with a monthly fee now run to completion — they previously stalled before the last payments, leaving the Pay button dead. Small rounding leftovers (like Rp 1) no longer linger after the final installment either.
- Paylater due reminders now stay in sync: they refresh after installment payments, plan changes, new purchases, transfers, and balance adjustments, and they are cancelled when a wallet is deleted or paid off — no more reminders quoting old amounts. Each provider card on the Paylater screen also shows the same due date as the rest of the screen.
- A paylater purchase recorded late (with its date set back) now schedules its installments from the purchase date, and raising a plan's total now respects the paylater freeze.
- Restoring a backup now brings back installment plans, recurring transactions, templates, and learned categories — these were silently lost before. Damaged, empty, or foreign backup files are now rejected instead of wiping your data, receipt photos survive a failed restore, and a backup from a newer app version asks you to update first.
- CSV exports containing accented or emoji text no longer come out corrupted in Excel.
