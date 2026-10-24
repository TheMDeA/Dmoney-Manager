## [2.6.6] - 2026-10-24

### Changed
- The Structure donut card no longer animates in — it appears instantly; the category rows still cascade in as before.
- On the Stats screen, Spending by category now comes before Insights.
- Stats and Home are lighter on the database: the Stats screen no longer re-runs all of its queries on every tap or change, and the Home insight card now only looks at the last two months instead of your entire history.

### Fixed
- A single broken recurring rule could stop all recurring transactions from posting, silently. Rules are now processed independently, and failures are logged instead of swallowed.
