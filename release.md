## [2.8.0] - 2026-11-05

### Added

- Paylater due dates now follow real billing cycles. Set a statement day on a paylater wallet and purchases bill the way the providers do it (GoPay Later, SPayLater): bought after the statement day, they land on next month's bill — so installment first payments, the next-due card, and payment reminders show the true due date instead of one a month early. Wallets without a statement day are unchanged.
- Installment plans can now be edited — tap the pencil on a plan to change its name, total, installment count, or start date. Changing the total also corrects the linked purchase and the wallet balance, and fixing a wrong start date re-anchors the whole payment schedule. If a plan's paid counter ever disagrees with its recorded payments, the edit screen offers to sync it.

### Fixed

- Stats net worth: the change pill (e.g. "-Rp 1.389.067 (-1.5%) · vs Jun") no longer runs off the edge of the card when the amounts are large — it moves below the total instead.
- Section titles with a button next to them (like "Spending by category" / "Show more") can no longer overflow on narrow screens — the title shortens instead of pushing the button off-screen. This also affected the longer Indonesian labels.
- Paylater installments now work the same in both places: adding a transaction and adding a plan from the Paylater menu both offer 1x / 3x / 6x / 12x buttons — or a Custom count — with the monthly quote shown as you type. The Paylater menu previously made you type the number of months blind and demanded at least 2, so one-month plans are possible there now too.
- Popup messages inside the add-transaction sheet now actually appear — "Filled from receipt", template confirmations, and photo pick errors were silently never shown before.
- The "Record deleted" message no longer stays on screen until swiped away — it now disappears on its own when its undo window ends, as it was supposed to. Same fix for the delete-multiple and update-available messages.
