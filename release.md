## [2.5.3] - 2026-10-10

### Added
- Receipt scanning now also fills in the transaction time when the receipt shows it (e.g. "08/10/2026 14:30").
- New installs start with a full set of default categories (9 income, 14 expense) with matching icons, like popular money manager apps.
- The app now checks for updates automatically once a day on start (toggle in Settings); new versions show a dismissible banner instead of needing a manual check.

### Changed
- Wallet card stack now cascades when focusing: the tapped card leads and neighbors follow rippling outward, and the card content crossfades instead of popping.
- Stats page now replays its section cascade (overview, insights, charts) when switching months instead of only animating the overview numbers.

### Fixed
- Receipt scanning no longer mistakes a SUBTOTAL line for the total when a receipt prints both — the grand total wins.
- Fixed the selected pill in segmented controls (Day/Week/Month) having its corners clipped on the last option.
