## [2.3.0] - 2026-10-05

### Added
- Bulk select in transaction history: long-press a record to select multiple, then delete them together (with undo) or move them to another category at once.

### Changed
- Search now waits until you stop typing before filtering, so it stays smooth with large histories.
- Receipt photos are downscaled at capture, so they take far less storage.
- The "More" tab is now called "Settings" (bottom nav, home shortcut, and screen title).
- Transaction history is now titled "Transactions".
- The home balance card label now reads "Expense", matching the history overview.
- The fourth home quick action is now Debt (opens the add-debt form) instead of duplicating the Settings tab.
- Tapping the total balance on the home card jumps to the Stats tab.
- "See all" on the home screen now reads "View all", matching the wallet and budget screens.

### Fixed
- The date scrubber bubble is more compact so it hides less of the row amounts while scrubbing.
- The fastest-rising insight now says "Debt repayments are …" instead of "Debt spending is …" for the debt category.
- Delete snackbars no longer pile up when deleting several records quickly — any existing snackbar is cleared first, so the 5-second undo timer is always predictable.
