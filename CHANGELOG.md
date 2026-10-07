## [2.4.5] - 2026-10-07

### Added
- Pull-to-refresh now shows a coin dropping in.

### Changed
- Option pills (Expense/Income, Day/Week/Month, etc.) now slide instead of jumping.
- Budget and debt progress bars now animate smoothly.

### Fixed
- Account messages (created, moved, deleted) now appear above the account sheet instead of hiding behind it.
- Validation messages in the budget, goal, wallet, and transfer forms now appear correctly.
- Bottom sheets (edit goal, accounts, transfer, etc.) now size to their content instead of filling the screen.
- Invalid form fields now shake when you try to save.
- Search results now cascade in like the other lists.
- Editing your profile name no longer leaks a text controller.

## [2.4.4] - 2026-10-06

### Changed
- Record payment, goal deposit/withdraw, adjust balance, new account, and move wallets now use the same bottom-sheet style as the other forms, with inline validation.

### Fixed
- Transfers no longer trigger a double haptic buzz.

## [2.4.3] - 2026-10-06

### Changed
- The debt edit form now uses the same bottom-sheet style as the add-debt form, with inline validation errors.

### Fixed
- Chart tooltips in Stats no longer get cut off at the card edges, and the trend chart's value labels no longer wrap onto two lines.
- The "create another account first" message when moving wallets now appears immediately instead of hiding behind the account sheet.

## [2.4.2] - 2026-10-06

### Changed
- The bar chart in Stats now labels months with three letters (Jun, Jul) instead of single letters.
- The net savings trend in Stats now shows month labels and min/max values so the chart is readable.

### Fixed
- Debts listed on the Budgets tab can now be tapped to open their details.
- The transaction detail screen no longer repeats the description below the title.

## [2.4.1] - 2026-10-05

### Changed
- Tab headers now animate in letter by letter each time you switch tabs, with the lime dot popping in at the end.
- The "Today" button in the calendar header now hides itself while you're already viewing the current month.
- Light mode now uses a deeper shade of the theme color for text, icons, and highlights so they stay readable on white. Dark mode is unchanged.
- If an update download is interrupted (e.g. the update window is closed), it now resumes from where it stopped instead of starting over.
- The update downloader now shows the current download speed (KB/s or MB/s) next to the progress.

## [2.4.0] - 2026-10-05

### Changed
- Main tab headers redesigned: a bold title with a lime full stop, and a "Today" shortcut pill on the Calendar header.
- Tapping the month label in the calendar now opens the month/year picker, like in the transaction history.
- The month/year picker gained a "Current month" shortcut for one-tap jumps back to today, and stepping through months now gives subtle haptic feedback.
- Haptic feedback pass across the app: quick actions, the calculator keypad, photo handling, save buttons, and delete confirmations now respond with subtle taps.
- Calculator polish: thousand separators now appear live in the expression as you type, long-press backspace clears everything, long-press 0 types "00", keys press with a subtle scale, and tapping = with nothing to calculate wiggles the display instead of silently doing nothing.
- The home insight card now draws from 13 insight types (top merchant, spending vs last month, no-spend streaks, weekend habits, savings rate, and more), showing 3 fresh ones each session, refreshed periodically. The auto-cycle pauses while you read, and the dots are tappable.

### Fixed
- The balance card sparkline no longer sits glued to the edge of its box when a flow has no data yet.

## [2.3.3] - 2026-10-05

### Fixed
- Bottom nav icons now track the page continuously while swiping or switching tabs, instead of popping with a delayed bounce after the page settled.
- The add/edit transaction sheet now shows a red hint under each missing field (amount, category, wallet) instead of a single popup message.

### Changed
- Home screen polish: a soft accent glow behind the content and on the balance card, calmer sparklines that stay readable when one day spikes, and the insight card now follows your theme color.
- The soft accent background glow now extends to the Wallets, Calendar, Stats, Budgets, and Settings pages.
- The debt form is now a bottom sheet like the other forms, with the same sections and inline validation, instead of a separate full-screen page.
- Form sheets now cap at three-quarters of the screen height instead of covering the whole display.

## [2.3.2] - 2026-10-05

### Added
- Feature tour: new users now get a short guided tour of the app's headline features right after setup (with Skip always available), and it can be replayed anytime from Settings → Feature tour.

### Fixed
- The in-app updater no longer re-downloads the APK when the Android install prompt is dismissed — the downloaded file is kept in the cache and the update sheet offers "Install update" directly.
- Validation messages in the add, transfer, wallet, budget, and savings goal sheets now appear inside the sheet itself — they used to render behind it and only became visible after closing the sheet.

## [2.3.1] - 2026-10-05

### Added
- Calendar month transitions: the grid now slides in the direction you tap, and the Income / Expense / Total summary counts up to the new month's values instead of jumping.
- Count-up animations on the Wallets page (combined balance and each wallet's balance) and the Budgets page (spent amounts, remaining/over-budget amounts, and savings goal progress), so balances roll to their new values instead of jumping when transactions change.

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

## [2.2.2] - 2026-10-05

### Fixed
- Date scrubber thumb now follows the list as you scroll (it used to stay stuck in the middle), and the date bubble rides on the thumb while scrubbing.

## [2.2.1] - 2026-10-05

### Added
- Transaction memos: every transaction now has a required Description (just below the amount) plus an optional Memo for extra context. Both show in the detail view, search results, and CSV/Excel exports.
- Double-press back to exit: on the Home tab, a single back press no longer closes the app — press again within 2 seconds to exit.

### Fixed
- Check for updates works again (the app was missing the internet permission, and GitHub requires a request header the app wasn't sending).

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
