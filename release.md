## [2.8.5] - 2026-11-16

### Fixed
- Opening a deleted transaction no longer spins forever — it now says the record is gone and lets you go back.
- Recurring income can no longer be set on a PayLater wallet, where it would have posted money as if nothing were owed. An existing rule like that is skipped when it comes due.
- The calendar day view now updates right after you edit a transaction, and days outside the shown weeks no longer come up empty.
- Restoring a backup no longer leaves the app looking empty when the backup was made with a different account selected.
- Large Drive backups no longer fail on slow connections — uploads now pick up where they left off instead of timing out.
- A restore no longer reports failure after your data was already restored — a bad backup setting can't make a good restore look failed.
