# Changelog

All notable changes to Dmoney Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [1.1.3] - 2026-10-04

### Fixed
- Receipt photo viewer opened and instantly closed itself ("nothing
  happens" on tap): the body treated the stream's initial no-data
  state as "all photos deleted" and popped the route. It now shows a
  loading indicator until the photo list actually arrives.

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
