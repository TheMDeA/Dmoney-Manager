## [2.2.1] - 2026-10-05

### Added
- Transaction memos: every transaction now has a required Description (just below the amount) plus an optional Memo for extra context. Both show in the detail view, search results, and CSV/Excel exports.
- Double-press back to exit: on the Home tab, a single back press no longer closes the app — press again within 2 seconds to exit.

### Fixed
- Check for updates no longer fails with a connection error when you're online.

## [2.2.0] - 2026-10-05

### Added
- Subscription detector: the Recurring screen can scan your history for repeating charges and turn each into a recurring rule with one tap.
- Launcher shortcuts + Quick Settings tile: long-press the app icon or use the QS tile to jump straight to adding an expense or income.
- Smart category suggestions: the app learns from your past transactions and suggests a category as you type the description.
- Check for updates: the More tab can check for a new version, download the APK inside the app, and hand it to the installer — no browser needed.
- Smoother touch feedback: cards now press down slightly when tapped.

### Changed
- Settings is now grouped into sections instead of one long list.
- Nicer charts: gradient fills on the net-worth line, sparklines, and income/expense bars.
- Category picking in the form sheets is now a compact grid.

### Fixed
- All animations now follow one consistent timing spec.
- The + button opens the same add-transaction sheet as everywhere else, with swipe-to-dismiss working properly.
- Home income/expense amounts no longer wrap onto two lines.

## [2.1.1] - 2026-10-04

### Added
- Haptic tick when typing the passcode.
- Goal date picker in the Add savings goal dialog.
- Transaction history: Month / All view toggle, with a fast date scrubber in the All view.

### Changed
- The home goal spotlight now only shows goals you haven't reached yet.
- Home income/expense cards moved into the balance card with mini sparkline graphs.
- Unified design for all add/edit forms (wallets, budgets, goals, transactions, transfers).
- Color pickers for wallets and savings goals.

## [2.1.0] - 2026-10-04

### Added
- Goal celebration when a savings goal reaches 100%.
- Wallet peek: long-press a wallet card for a quick balance preview.
- Date scrubber for fast scrolling through history.
- Haptic feedback toggle in Settings.
- Multiple accounts: create accounts, switch between them, and the whole app follows the active one.

### Changed
- Single Adjust Balance dialog for wallet balance corrections.
- Two-step swipe actions on transactions (swipe reveals, tap confirms) to prevent accidents.
- More polish animations: count-up balances, spinning transfer swap, auto-cycling insights, pull-to-refresh, sticky date headers.
- Theme accent now applies consistently everywhere.

## [2.0.0] - 2026-10-04

### Added
- Swipe actions on transaction rows (edit / delete with undo).
- Loading placeholders, haptic feedback, and helpful empty states throughout.
- Smooth transitions when drilling into wallets and categories.
- Adjust balance action on the wallet detail screen.

### Changed
- Consistent animation timing across the app; balances and stats animate instead of jumping.

## [1.1.7] - 2026-10-04

### Added
- Wallet detail: tap a category to see its transactions.

### Fixed
- Balance hide/show animation no longer jumps sideways.

## [1.1.6] - 2026-10-04

### Added
- Stats Overview and Structure screens: balance summary and income/expense by category with a donut chart.
- Receipt photos on transactions.
- Wallet transactions screen with month navigation.

### Fixed
- Home sparklines now match the selected Day/Week/Month range.
- Goal screens follow the theme accent.

## [1.1.5] - 2026-10-04

### Added
- Calendar view with per-day income/expense totals.
- Redesigned transaction history with month navigation and daily totals.
- Custom launcher icon.

### Fixed
- Faster transaction detail loading and lighter receipt thumbnails.

## [1.1.4] - 2026-10-04

### Added
- Wallet-to-wallet transfers with a swap button.
- Calculator built into amount fields.
- Undo after deleting a transaction.
- Monthly insights comparing against the previous month.
- Recurring transactions (subscriptions, salary, rent).
- One-tap transaction templates.
- Net worth chart.

## [1.1.3] - 2026-10-04

### Added
- App-wide animations: swipe between tabs, springy nav icons, smooth screen transitions, staggered lists.
- Time picker in the transaction form.

### Fixed
- Receipt photo viewer no longer closes instantly.
- Picking a date no longer resets the time.

## [1.1.2] - 2026-10-04

### Added
- 6 theme colors, including Material You.

### Fixed
- Light mode readability pass across the whole app.

## [1.1.1] - 2026-10-03

### Added
- Change currency after setup (amounts are not converted).
- Backup & restore via a single zip file.
- Debts can appear in the transaction history.
- New full-screen add-debt form.
- Redesigned category management with drag-to-reorder.

### Fixed
- Currency symbol always visible in amount fields.
- More reliable restore and receipt photo storage.

## [1.1.0] - 2026-10-03

### Added
- Release signing for CI builds.

### Fixed
- Database writes are now crash-safe.

### Changed
- Faster stats and lists with database-side aggregation.

## [1.0.1] - 2026-10-03

### Added
- First-launch onboarding (welcome, account, currency, initial balance).
- Interactive stats charts, receipt photo viewer, and detail screens for budgets, debts, wallets, and goals.

### Fixed
- Black screen on launch.
- Live thousand separators while typing amounts.

## [1.0.0] - 2026-10-03

First release: home dashboard, quick expense/income entry, transaction records with receipt photos, wallet transfers, multiple wallets, stats charts, budgets, savings goals, debt tracking, categories, search, CSV/Excel export, passcode + biometric lock, notifications, and a dark-first design with a light theme.

### Fixed
- Wallet balances now update when recording transactions.
