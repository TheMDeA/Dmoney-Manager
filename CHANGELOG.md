## [Unreleased]

### Added
- Transaction history now has a Month / All view toggle. The All view shows the full transaction list with a fast date scrubber — a drag strip on the right edge that proportionally scrolls the list with a floating date bubble and haptic ticks. The scrubber no longer appears in the Month view, where the month pager already handles navigation.

## [2.1.0] - 2026-10-04

### Added
- Goal celebration: pushing a savings goal to 100% triggers a trophy pop-in with ripple ring, haptic, and a "Goal complete!" dialog.
- Wallet peek: long-press a wallet card for a springy popup with its balance, initial amount, and last transaction — no need to open the detail screen.
- Fast-scroll date scrubber: a drag strip on the right edge of the history (and wallet transactions) scrubs through months with a floating month bubble and haptic ticks.

### Changed
- Wallet detail: the blue ADJUST BALANCE button below the balance is now the single entry point for balance adjustments — it opens the new reconciliation dialog (adjust by transaction or change initial amount). The top-right shortcut icon is gone, and the old direct-set behavior is retired in favor of the "Change initial amount" mode, which keeps the wallet's initial amount consistent.
- Balance privacy toggle now counts the digits down to the dot mask when hiding and counts them back up when revealing (fast micro-interaction), replacing the fade-and-rise swap. Balance changes while visible keep the slow count-up.
- Swipe actions on transaction rows are now two-step: swiping reveals the Edit/Delete button but nothing fires until it's tapped (new `flutter_slidable` dependency) — a stray swipe can no longer open the edit sheet or the delete flow. Open panes close on scroll.
- Transfer sheet: pressing the swap button now plays a visible animation — the button spins a full 360° (the old half-turn was invisible on the symmetric swap icon) and the From/To fields cross-fade with a directional slide, like the values trading places.
- Save success animation: the checkmark pop now has an overshoot bounce plus an expanding ripple ring.
- Wrong passcode now shakes the PIN dots side-to-side (with haptic) instead of just clearing them.
- AI insight card auto-cycles through up to three insights (rising category, biggest monthly category, daily pace) every 6 seconds with cross-fade and dot indicators.
- Pull-to-refresh on the transaction history and wallets screens.
- Date group headers now stick to the top while their day scrolls by (history, wallet transactions, category screens).
- Budget and goal progress bars tween to new values instead of jumping (new shared `AnimatedProgressBar`).
- Net-worth chart draws itself left-to-right on load and replays when switching 3M/6M/12M ranges.
- The + FAB now morphs into the add-transaction sheet via a container transform (new `animations` dependency); tapping the scrim or saving reverses it back into the FAB.

### Fixed
- Theme accents are now uniform: the color scheme's secondary colors are derived from the chosen theme color instead of a hardcoded violet, so Material components (e.g. the System/Light/Dark segmented control's selected segment) follow the accent — no more stray purple when Lime is selected. An explicit `SegmentedButtonTheme` guarantees the selected segment is a solid accent fill.

### Added
- Haptic feedback toggle in Settings (More → Appearance): vibrations on taps and actions can now be turned off; all `Haptics` call sites respect it. Turning it back on plays a confirming buzz.
- Home income/expense cards are now tappable: they drill into the Stats structure screen on the matching INCOME/EXPENSE tab for the current month.
- Full account feature: the home avatar opens an account switcher — All accounts plus per-account balances and wallet counts, new accounts (name + color), and long-press to rename, recolor, move wallets between accounts, or delete (wallets are reassigned, never orphaned; the last account can't be deleted). The selection is a persisted global scope: home balance, income/expense cards, insights, stats, budgets, history, calendar and search all follow it, with a color ring on the avatar and a name chip in the header while scoped. New wallets default to the active account and the add-transaction wallet picker follows the scope (transfers stay unscoped so money can move between accounts). (DB v9: `accounts.colorHex`.)

## [2.0.0] - 2026-10-04

### Added
- Swipe actions on transaction rows: swipe right to edit, swipe left to delete (with the 5-second undo), on the history, wallet transactions, wallet category, and calendar day lists. Transfers and debt-linked entries show their usual guidance instead.
- Shimmer skeleton placeholders while lists and cards load (history, wallet screens, stats), replacing blank frames and spinners.
- Haptic feedback: light/medium vibrations on save, delete/undo, swipe actions, balance toggle, tab switches, and the Day/Week/Month switcher.
- Empty states with guidance and action buttons (add transaction / wallet / budget) across history, wallets, budgets, and debts.
- Hero transitions on drill-downs: the wallet color bar morphs into the detail header, and the category icon flies into the category screen's app bar.
- Transaction detail: the category icon now flies in from the tapped row (hero transition); the header renders instantly and stays in sync after edits.
- Wallet detail: new "Adjust balance" action (tune icon) — enter the true balance and either record an adjustment transaction for the difference (hidden "Adjustment" category, deletable with undo) or shift the wallet's initial amount; live difference preview, DONE disabled on no change.

### Changed
- One motion spec (`AppMotion`): fast/normal/slow durations and enter/exit curves now shared by every animation in the app.
- Tabular figures applied theme-wide so amounts never jitter when digits change.
- Total balance counts up/down to its new value instead of jumping.
- Stats: income/expense/total, opening/ending balances, and total net worth now count up/down when the month or range changes.
- Transaction lists animate insertions (slide + fade) and removals (collapse); the grouped list is now one shared stateful widget.

## [1.1.7] - 2026-10-04

### Added
- Wallet detail: tapping a category in the Transaction list now opens a dedicated category screen — an overview total plus that category's transactions grouped by date (same rows and animations as the history). "View all" still opens the full month-paged wallet transactions.

### Fixed
- Balance privacy toggle no longer jumps sideways: the hide/show animation keeps the amount left-aligned throughout instead of shifting to the center and snapping back.

## [1.1.6] - 2026-10-04

### Added
- Stats: new Overview section — Balance card (opening/ending balance) plus an income/expense/total summary, with a "Show more" drill-down into the new Structure screen.
- Stats: new Structure screen — income and expense by category for the month, with INCOME/EXPENSE tabs, a large donut with percentage callouts, and per-category rows showing share, amount and transaction count.
- Add-transaction sheet: attach a receipt photo (camera or gallery) with a thumbnail preview — tap for full-screen, X to remove. The scan flow now shows the captured photo as a preview in the sheet before saving.
- Wallet transactions screen now mirrors the main history: month pager with a month/year picker, income/expense/total overview, and date groups with daily totals. The month selector, overview, date headers, and grouped list are shared widgets so both screens stay consistent.
- Sparkline graphs animate (700ms eased tween) when switching ranges or when new transactions arrive.
- Total-balance privacy toggle animates with a fade + rise when hiding/revealing.

### Fixed
- Fixed a misplaced `CategoryStat` typedef that sat between the `@DriftDatabase` annotation and the database class, which made drift's code generator silently skip emitting `app_database.g.dart` (CI release builds failed with hundreds of "not found" errors even though `flutter analyze` was clean).
- Home sparklines now match their figures: graph buckets follow the selected Day/Week/Month range (24 hourly buckets for Day, 7/30 daily buckets for Week/Month) instead of always showing the last 7 days. Range starts are midnight-aligned so amounts and graphs cover identical periods. New `watchHourlyKindTotals` DAO.
- Goal screens use consistent accent colors instead of hardcoded blue: the progress bar uses the goal's own color, Deposit/Withdraw labels follow the theme accent, and deposit amounts/icons use semantic income green (withdrawals stay red) — matching the Budget screens.

## [1.1.5] - 2026-10-04

### Added
- Calendar view (bottom-nav tab next to Wallets): month grid with per-day income/expense/net totals, income/expense/total summary, Sunday-first layout with dimmed adjacent-month days, today highlighted. Tapping a day opens its transactions in a bottom sheet.
- Transaction history redesign: month pager with a month/year picker, an income/expense/total overview per month, and transactions grouped by date with daily totals. Rows now show a circular category icon with the entry time (HH.mm) under the amount.
- Custom launcher icon: the lime-green D + gold coin mark, with full
  adaptive-icon support (background/foreground/monochrome layers, so
  it also follows Android 13+ themed icons).

### Fixed
- Goal detail screen showed a blank page when the goal had deposits: `DateFormat` with an explicit locale threw `LocaleDataException` because date symbols were never initialized. `main()` now calls `initializeDateFormatting()`. Added a regression widget test (`test/goal_detail_test.dart`) plus a `@visibleForTesting` database constructor to support it.
- Status bar icons are now visible in light mode (dark icons on light backgrounds, light icons on dark) — applied per theme and on screens without an AppBar.
- Transaction detail screen no longer scans the entire transaction table (3-table join over all history) just to load one record — new `getTransactionDetailById` DAO used by open, duplicate, and delete.
- Receipt thumbnails now decode a 240px downscaled copy instead of the full multi-megapixel camera photo, cutting memory use in the photo grid.

## [1.1.4] - 2026-10-04

### Added
- Transfer sheet: swap button between From/To wallets with a flip rotation animation.
- Amount fields: built-in calculator keypad — type expressions like `12000+3500` with a live result preview, `=` writes the result back.
- Transaction delete: 5-second Undo snackbar restores the record with its wallet balances and receipt photos.
- Stats: Insights card comparing the selected month vs the previous one — biggest category, largest movers, and daily spending pace.
- Recurring transactions (DB v8): subscriptions, salary, rent —
  daily/weekly/monthly/yearly rules with optional end date, managed
  in Settings → Recurring transactions. Due occurrences are recorded
  automatically when you open the app (with a notification), linked
  to their rule, and pauseable via toggle or long-press delete.
- One-tap templates: a template row in the add-transaction sheet —
  tap to fill the whole form, "Save current" to capture it (with a
  name), long-press to delete. Most-used templates sort first.
- Net worth chart in Stats: total balance over time with 3M/6M/12M
  ranges, headline total, and period gain/loss pill.

## [1.1.3] - 2026-10-04

### Added
- Animations across the app: swipe left/right between the 5 main tabs
  (`PageView` with eased transitions; tapping a nav item or jumping
  from a quick action animates the same way), active nav icons pop
  with a spring scale, every pushed screen now uses a shared
  fade+slide route (`AppPageRoute`, with a subtle parallax on the
  outgoing page), and list items stagger in (Home transactions,
  wallets, budgets, goals, debts, recurring rules) — new items animate
  on insert, existing ones stay put on rebuilds.
- Time picker in the add-transaction sheet: date and time sit
  side-by-side (like the add-debt form, `HH.mm` format) and the note
  field moves to its own full-width row. Editing a transaction now
  also loads its saved time.

### Fixed
- Receipt photo viewer opened and instantly closed itself ("nothing
  happens" on tap): the body treated the stream's initial no-data
  state as "all photos deleted" and popped the route. It now shows a
  loading indicator until the photo list actually arrives.
- Picking a date in the add-transaction sheet silently reset the time
  to midnight; the chosen time is now preserved.

## [1.1.2] - 2026-10-04

### Added
- Theme colors: Settings → Appearance now has 6 accents — Lime
  (default), Sky, Violet, Tangerine, Rose, and Material You (follows
  the phone's wallpaper colors on Android 12+). The accent flows
  through `colorScheme.primary`, so every button, FAB, checkmark, and
  highlight updates instantly and persists across restarts.

### Fixed
- Light-mode visibility pass: hardcoded dark colors are gone from
  widget code. New `AdaptiveColors` extension on `BuildContext`
  (`context.textPrimary`, `textMuted`, `surface`, `raised`, `hairline`,
  `base`) resolves through the theme, so text, icon tiles, chart
  tooltips, dropdowns, and dividers stay readable in both themes.
  Also fixed: invisible icon-picker circles, invisible total balance,
  white fingerprint icon on bright accents, color-picker selection
  rings/checkmarks, and white icons/text on bright wallet, category,
  and debt colors (now use luminance-aware `onAccent`).

## [1.1.1] - 2026-10-03

### Added
- Currency can now be changed after the initial setup: the Settings
  "Currency" tile opens a picker with all 14 currencies instead of an
  informational dialog. Switching only changes the symbol and number
  formatting — a confirmation dialog makes clear that existing amounts
  are not converted (e.g. Rp100.000 becomes $100.000).
- Backup & restore (the promised future update is here): Settings has a
  new "Backup & restore" screen, and the onboarding "Restore data"
  button works for real. A backup is a single zip containing a
  consistent database snapshot (`VACUUM INTO`), receipt photos, and app
  preferences — share it to your cloud drive, then restore it on any
  device. Restore copies rows into the live database (column-matched,
  so minor schema drift doesn't break it) and refreshes every screen
  automatically.
- Debts can now appear in the transaction history: the add/edit debt
  forms have a "Show in transaction history" toggle (on by default).
  When enabled, the debt's creation and each repayment are recorded as
  linked transactions (DB v6: `transactions.debtId`/`debtPaymentId`,
  `debts.recordAsTransaction`, hidden "Debt" category), so they show up
  in history, stats, and wallet views. Debt entries carry a debt badge;
  tapping one opens the debt detail, and they can't be edited, duplicated,
  or deleted from the transaction side — the debt stays the source of
  truth and wallet balances stay in sync on every edit/delete.
- New full-screen "add debt" form (replacing the dialog): "I borrowed" /
  "I lent" switcher in the app bar, name/organization, amount, date +
  time pickers, color choices, description, optional due date, wallet
  picker with a "Don't use wallet" toggle, transaction-history toggle,
  and inline validation. The chosen date/time is stored as the debt's
  creation date and used for the linked history entry.
- Redesigned category management (Settings → Categories) matching the
  classic tracker UX: "Manage Category" screen with INCOME / EXPENSE
  tabs, drag-to-reorder rows (persisted via DB v7 `categories.sortOrder`),
  subcategory counts, and edit/delete actions. New full-screen category
  form (name, color picker, icon picker, subcategories section) and a
  "Pick Icon" screen with icons grouped by theme (General, Food & Drinks,
  Home & Living, Transport, Shopping, Money & Work, Health & Fitness,
  Fun & Hobbies).

### Fixed
- The currency symbol is now always visible when entering an amount
  (new AmountField widget): the old `prefixText` didn't render while
  the field was empty and unfocused, so the add-transaction, transfer,
  and add-debt sheets showed a bare "0". The symbol is now a permanent
  label next to the field.
- Restore rewritten for reliability: the backup is now read through a
  separate read-only connection instead of `ATTACH DATABASE`, which
  could fail on `DETACH` ("database is locked") and leave the app unable
  to restore until restarted. Restore failures also show a friendly
  message instead of raw SQL errors.
- Receipt photos are now reliable: picked images are copied into the
  app's documents folder (`receipts/`) instead of referencing the
  image_picker cache path, which the OS can wipe at any time. Deleting
  an attachment also removes the stored copy (the user's gallery
  original is always kept). Photo/camera failures now show an error
  message instead of failing silently.

### Added
- Android permissions for photos: `CAMERA` (scan receipt),
  `READ_MEDIA_IMAGES`, and `READ_EXTERNAL_STORAGE` (API ≤ 32).

### Changed
- README refreshed: debt history, the new add-debt form, the category
  manager redesign, and backup & restore are now documented.

## [1.1.0] - 2026-10-03

### Added
- Release signing: `android/app/build.gradle.kts` now signs release
  builds with the release keystore when the `ANDROID_KEYSTORE_PATH`,
  `ANDROID_KEYSTORE_PASSWORD`, and `ANDROID_KEY_ALIAS` env vars are set
  (GitHub Actions), falling back to debug keys otherwise. The keystore
  itself lives outside the repo (`your_files/keystore/dmoney-manager/`).

### Fixed
- Database hardening (DB v5): all multi-step debt and goal writes
  (`createDebt`, `updateDebt`, `deleteDebt`, `recordDebtPayment`,
  `deleteDebtPayment`, `recordGoalDeposit`, `deleteGoalDeposit`,
  `deleteGoal`) are now wrapped in transactions so wallet balances and
  saved totals can never drift on a mid-write crash.

### Changed
- Database performance: SQL-side aggregation replaces full-table scans
  (`watchCategoryExpenseTotals`, `watchMonthlyKindTotals`,
  `watchKindTotals`, `watchDailyKindTotals`) and filtered streams
  (`watchTransactionsForWallet`, `watchTransactionsForCategory`) power
  the stats, home, balance card, budgets, wallet detail, and budget
  detail screens; `debtPaidTotal` now uses `SUM()` instead of a Dart
  fold; indexes added on hot filter columns
  (transactions date/wallet/category, budgets month, debts direction,
  debt/goal/photo FKs, wallets account).

## [1.0.1] - 2026-10-03

### Added
- First-launch onboarding: welcome carousel (financial monitoring, smart
  budgets, saving goals), account naming, currency selection (14 currencies,
  IDR default), and initial cash balance entry with a numeric keypad.
  Fresh installs now start with a clean database — sample accounts and
  transactions are no longer seeded; the setup creates your first account
  and cash wallet.

### Fixed
- Black screen on launch: the notification plugin referenced a launcher icon
  that isn't in the repo, crashing the app before the first frame. The app now
  ships a bundled notification icon, and a notification failure can no longer
  prevent startup.
- Amount fields now format thousand separators live while typing, following
  the selected currency (e.g. `18.088.808` for IDR, `18,088,808` for USD).
- Stats charts are now interactive: tap a donut slice to spotlight its
  category (legend rows are tappable too), tap bars and trend points for
  value tooltips. Transfers no longer drag the net-savings trend down,
  and spending beyond the top 5 categories is aggregated into "Other".
- Receipt photos: tap a thumbnail to open a full-screen viewer (swipe
  between photos, pinch to zoom) with a delete action and confirmation.
- Budget detail screen: tap any budget row to open Spent/Left with a
  percentage progress bar, period info with days left, a daily cumulative
  spending chart against the dashed budget limit, Recommended/Average
  daily pace stats, and its transaction list (tappable to the record).
  Edit icon changes the monthly limit; trash icon deletes the budget.
- Debt detail screen: tap any debt to open Received/Paid vs Left with a
  percentage progress bar, amount/date/wallet info, and a payment history.
  The + button records partial repayments (amount, date, wallet, note);
  wallet balances move with each payment and the debt auto-marks paid
  when fully covered. Edit changes the debt details; trash deletes it
  and reverses all wallet movements. New debts can link a wallet —
  lending takes money out, borrowing brings it in. Payments are stored
  in a new `debt_payments` table (DB v3).
- Wallet detail screen (DB v4): tap any wallet card to open its balance,
  an ADJUST BALANCE action, Initial Amount, Income/Expense/Transfer
  transaction counts (tappable to a filtered list), and its transactions
  grouped by category with a "View all" screen. The wallet name switches
  between wallets; edit renames/retypes; delete is blocked while the
  wallet still has transactions. New wallets can set an initial amount.
- Goal detail screen (DB v4): tap any savings goal to open Saved/Remain
  with a percentage bar, target amount, goal date with days left,
  DEPOSIT/WITHDRAW actions, and a full deposit/withdrawal history
  grouped by day (swipe to delete an entry). Edit changes name/target/
  date; trash deletes the goal and its history. History is stored in a
  new `goal_deposits` table.

### Changed
- App icon currently falls back to the system default (custom launcher icons
  not yet generated — planned via flutter_launcher_icons).

## [1.0.0] - 2026-10-03

First release — Flutter app with the full feature set from the app mockup.

### Added
- Home dashboard: total balance hero card (glass), Day/Week/Month switcher,
  income/expense stat cards with sparkline micro-graphs, quick actions
  (Transfer, Top up, Scan receipt, More), data-driven AI insight card,
  savings-goal spotlight card with progress ring, recent transactions,
  balance privacy toggle.
- Fast expense/income recording via bottom sheet (amount, category grid,
  wallet chips, date, note) with animated success state and haptic feedback.
- Transaction detail ("Record") screen with duplicate/edit/delete actions
  and attachable receipt photos.
- Wallet-to-wallet transfers: balances move between wallets, shown as neutral
  "From → To" records excluded from income/expense stats.
- Multiple wallets (cash, bank, e-wallet, credit card) with a
  Personal/Work/Family account switcher, combined balance, and last
  transaction per wallet.
- Stats: expense donut with category breakdown, 6-month income/expense bars,
  net-savings trend line (fl_chart) — all animated on load.
- Budgets: per-category monthly limits with threshold alerts (amber at 80%,
  red when over), savings goals with progress tracking and tap-to-add savings.
- Debt tracking: Payable/Receivable tabs, outstanding vs paid sections,
  due-date reminder chips, swipe to mark paid, local due-date reminders.
- Flexible categories with subcategories: create, edit (rename), delete.
- Search across records by keyword, amount, or date, with recent searches.
- Export to CSV/Excel (transactions, budgets/goals, debts) with date-range
  picker, include toggles, and share sheet.
- Password protection: 4-digit passcode (set/confirm/change, hashed storage)
  + biometric lock screen.
- Local notifications: budget threshold alerts (80%/100%) and debt reminders,
  with a Notifications settings screen.
- Preferences persist across restarts: theme, lock, passcode, profile name,
  notification toggles.
- Profile display name editing, About dialog, app currency info (IDR).
- Dark-first 2026 design language (near-black surfaces, lime accent, liquid
  glass, Space Grotesk display type, tabular numerals) with light theme
  and System/Light/Dark appearance setting; animated tab transitions.
- Local persistence with drift (SQLite), seeded with Indonesian sample data.

### Fixed
- Recording income/expense now updates wallet balances (and reverses correctly
  on edit/delete) — balances previously never changed after seeding.
