# Money Manager — Flutter Starter

A starter scaffold for a simple, modern money manager Android (and iOS) app,
built from the interactive UI mockup. Dark-first 2026 design language:
near-black surfaces, lime accent, liquid-glass cards, expressive tabular
numerals, animated charts.

## Feature map (mockup → code)

| Mockup screen              | Implementation                              |
|----------------------------|---------------------------------------------|
| Home / total balance       | `features/home/` (balance card, sparklines, AI insight, recent list) |
| Add transaction bottom sheet | `features/transactions/add_transaction_sheet.dart` |
| Transaction detail + Save Photos | `features/transactions/transaction_detail_screen.dart` |
| Wallets + Personal/Work/Family accounts | `features/wallets/wallets_screen.dart` |
| Stats (donut, bars, trend) | `features/stats/stats_screen.dart` (fl_chart) |
| Budgets + savings goals    | `features/budgets/budgets_screen.dart`       |
| Debt tracking              | `features/debts/debts_screen.dart`           |
| Categories + subcategories | `features/categories/categories_screen.dart` |
| Search                     | `features/search/search_screen.dart`        |
| Export CSV / Excel         | `features/export/export_screen.dart`        |
| Passcode + biometric lock  | `features/lock/lock_screen.dart`            |
| More / settings            | `features/settings/settings_screen.dart`    |

State is managed with **Riverpod** (`state/providers.dart`), persistence with
**drift (SQLite)** (`data/database/app_database.dart`, seeded with Indonesian
sample data on first launch).

## Getting started

Prerequisites: the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(stable channel) and an Android emulator or device.

```bash
cd money_manager
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates drift code
flutter run
```

> `build_runner` must be re-run whenever you change the tables in
> `lib/data/database/app_database.dart`.

## Project structure

```
lib/
  main.dart                 # entry point, injects the database
  app.dart                  # MaterialApp, themes, lock gate
  core/
    theme/                  # AppColors, AppTheme, AppTextStyles (design tokens)
    utils/                  # IDR formatting, category icon map
    widgets/                # GlassCard, AmountText, SectionHeader, EmptyState
  data/database/            # drift tables, queries, seed data
  state/                    # Riverpod providers
  features/                 # one folder per screen (screen + widgets)
```

## Suggested next steps

1. Rename the Android applicationId (`com.example.money_manager`) to your own.
2. Add a real onboarding + passcode setup flow (the lock screen currently
   accepts any 4-digit PIN as a demo).
3. Add recurring transactions and budget rollover.
4. Add a home-screen widget showing total balance.
5. Wire crash reporting / analytics before a Play Store release.
