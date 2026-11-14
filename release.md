## [2.8.3] - 2026-11-13

### Fixed
- Restoring a backup no longer changes your app-lock PIN — the PIN now stays as the one on this device.
- Paylater and debt reminders can now actually appear: the app was missing the system registration that lets scheduled reminders show, and reminder times were calculated in the wrong timezone, so a 9 AM reminder would have fired in the evening.
- There is now a paylater reminders switch in Settings → Notifications, so you can turn those reminders off.
- Deleting a wallet is now refused when it still has installment plans, recurring rules, templates, or debts attached — deleting one before could leave rules posting transactions no screen could show.
- Changing a paylater wallet's type is now blocked while it still has installment plans, so plans can't be stranded.
- The Wallets screen's "Next due" line now shows the installments actually due next, matching the Paylater screen — it previously showed the full outstanding amount.
- Budget detail now respects the selected account, so its list matches the Budgets screen.
- The Debts screen now shows what's actually left to pay after partial payments, instead of the full amount.
- Home insights no longer miscalculate around the 29th–31st of the month.
- Restoring a backup now refreshes paylater and debt reminders to match the restored data, and a backup, a restore, and an automatic backup can no longer run over each other.
- Restoring a backup made before version 2.7.2 now reconnects installment plans to their purchases and payments — they previously came back unlinked, with empty plan history and purchases left behind when a plan was deleted.
- If a restore is interrupted while swapping receipt photos, your existing photos are now kept instead of lost.
- Drive backups now give up after 30 seconds on a stalled connection instead of silently disabling automatic backup until restart.

