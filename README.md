# Dmoney Manager

A modern money manager for Android, built with Flutter. Dark-first 2026
design language: near-black surfaces, lime accent, liquid-glass cards,
expressive tabular numerals, animated charts.

- **Home** — total balance card, sparklines, data-driven AI insight, recent
  transactions, savings-goal spotlight
- **Transactions** — month pager with a month/year picker, grouped by date
  with daily totals, add/edit/duplicate/delete, wallet-to-wallet transfers,
  receipt photos (full-screen viewer with zoom + delete), search,
  one-tap templates (save the current form, tap a chip to refill it),
  calculator keypad in amount fields, 5-second undo after delete
- **Calendar** — month grid with per-day income/expense/net totals,
  income/expense/total summary, tap any day for its transactions
- **Wallets** — Personal/Work/Family accounts, per-wallet detail (balance,
  adjust balance, income/expense/transfer stats, category-grouped history),
  initial amounts
- **Stats** — interactive donut, 6-month bars, net-savings trend,
  net-worth-over-time chart (3M/6M/12M ranges), and an insights card
  comparing the selected month vs the previous one
  (tap slices, bars, and points)
- **Budgets** — monthly limits per category with a detail view (spent/left,
  daily burn chart vs. limit, pace stats), 80%/100% notifications
- **Savings goals** — deposit/withdraw history grouped by day, deadlines
- **Debts** — payable/receivable, partial repayments with wallet sync,
  due-date reminders, per-debt detail view; debts can appear in the
  transaction history ("Show in transaction history" toggle, on by
  default) with a debt badge on linked entries; full-screen add-debt
  form (I borrowed / I lent switcher, date + time, colors, due date,
  optional wallet)
- **More** — category manager (INCOME/EXPENSE tabs, drag-to-reorder,
  icon picker, subcategories), recurring transactions (subscriptions,
  salary, rent — auto-added on app start), CSV/Excel export, backup &
  restore (full backup zip: database snapshot + receipt photos +
  preferences), settings (theme mode, 6 theme colors incl. Material You,
  currency), 4-digit PIN + biometric lock

State is managed with **Riverpod** (`lib/state/providers.dart`), persistence
with **drift (SQLite)** (`lib/data/database/app_database.dart`). Amounts
follow the currency chosen during onboarding (14 supported, IDR default)
with live thousand separators in every amount field.

## Getting started

Prerequisites: the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(stable channel) and an Android emulator or device.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates drift code
flutter run
```

> `build_runner` must be re-run whenever you change the tables in
> `lib/data/database/app_database.dart`.

First launch shows the onboarding flow (welcome carousel → account name →
currency → initial cash amount). If the app data already contains accounts,
onboarding is skipped.

## Project structure

```
lib/
  main.dart                 # entry point, injects the database
  app.dart                  # MaterialApp, themes, lock gate, onboarding gate
  core/
    theme/                  # AppColors, AppTheme, AppTextStyles (design tokens)
    utils/                  # currency-aware formatting, category icon map
    widgets/                # GlassCard, AmountText, SectionHeader, EmptyState
    services/               # notifications, preferences, backup & restore
  data/database/            # drift tables, queries, migrations, seed data
  state/                    # Riverpod providers
  features/                 # one folder per screen (screen + widgets)
    onboarding/             # first-launch setup flow
    home/ transactions/ wallets/ calendar/ stats/ budgets/ goals/ debts/
    categories/ search/ export/ backup/ lock/ recurring/ settings/
```

## Building a release APK

Releases are built with the **Build APK** GitHub Actions workflow
(`.github/workflows/build-apk.yml`): manual dispatch for release/debug, or
push a `v*` tag to build and publish a GitHub Release automatically.

Release signing: `android/app/build.gradle.kts` signs with the release
keystore when the `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, and
`ANDROID_KEY_ALIAS` env vars are set (the workflow decodes them from the
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`
repository secrets), and falls back to debug keys otherwise. The keystore
itself is kept outside the repo — back it up permanently; losing it means
no future update can share the same signature.

Release checklist:

1. Bump `version` in `pubspec.yaml` (e.g. `2.0.0+21`).
2. Move the `[Unreleased]` changelog entries into a dated version section
   in `CHANGELOG.md`.
3. Commit, then `git tag v2.0.0 && git push origin v2.0.0`.

## App identity

- Name: **Dmoney Manager**
- Package: `dmoney_manager`
- Android applicationId / namespace: `com.dmda.dmoneymanager`
- Android only.
