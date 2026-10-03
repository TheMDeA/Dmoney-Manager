# Changelog

All notable changes to Dmoney Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

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
