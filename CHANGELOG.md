# Changelog

All notable changes to Dmoney Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- Wallet-to-wallet transfers (quick action): moves balances between wallets,
  shown as neutral "From → To" records excluded from income/expense stats.
- Quick actions fully wired: Transfer, Top up (income shortcut), Scan receipt
  (camera → new record with photo attached), More (jumps to the More tab).
- Edit any income/expense record from the detail screen.
- Savings-goal spotlight card on Home with progress ring; tap any goal to add
  savings.
- Category rename in edit mode (was delete-only).
- Real local notifications: budget threshold alerts (80%/100%) and debt
  due-date reminders, with a Notifications settings screen.
- Real 4-digit passcode: set/confirm/change flow, SHA-256 hashed storage,
  verified on the lock screen (replaces "any PIN unlocks").
- Preferences now persist across restarts: theme, lock, passcode, profile name,
  notification toggles.
- Last transaction shown on each wallet card.
- Data-driven AI insight card (biggest weekly spending increase per category).
- CSV export now honors the budgets/goals/debts include toggles.
- Profile display name editing, About dialog, currency info.

### Fixed
- Recording income/expense now updates wallet balances (and reverses correctly
  on edit/delete) — balances previously never changed after seeding.

## [1.0.0] - 2026-10-03

First release — Flutter starter scaffold with the full feature set from the
app mockup.

### Added
- Home dashboard: total balance hero card (glass), Day/Week/Month switcher,
  income/expense stat cards with sparkline micro-graphs, quick actions,
  AI insight card, recent transactions, balance privacy toggle.
- Fast expense/income recording via bottom sheet (amount, category grid,
  wallet picker, date, note).
- Transaction detail ("Record") screen with duplicate/edit/delete actions
  and attachable receipt photos.
- Multiple wallets (cash, bank, e-wallet, credit card) with a
  Personal/Work/Family account switcher and combined balance.
- Stats: expense donut with category breakdown, 6-month income/expense bars,
  net-savings trend line (fl_chart).
- Budgets: per-category monthly limits with threshold alerts (amber at 80%,
  red when over), savings goals with progress tracking.
- Debt tracking: Payable/Receivable tabs, outstanding vs paid sections,
  due-date reminder chips, swipe to mark paid.
- Flexible categories with subcategories: create, edit, delete.
- Search across records by keyword, amount, or date.
- Export to CSV/Excel (transactions, budgets/goals, debts) with date-range
  picker and share sheet.
- Password protection: passcode + biometric lock screen.
- Dark-first 2026 design language (near-black surfaces, lime accent, liquid
  glass, Space Grotesk display type, tabular numerals) with light theme
  and System/Light/Dark appearance setting.
- Local persistence with drift (SQLite), seeded with Indonesian sample data.
