## [2.7.8] - 2026-11-03

### Changed

- Transfers now count in a wallet's transaction totals: a transfer in adds to income and a transfer out adds to expenses for that wallet, in both the overview and the daily totals. The combined all-wallets history is unchanged.

### Fixed

- Some English texts showed doubled apostrophes (like "You''re"); they now display correctly.
- Adjust Balance now works correctly on paylater wallets: it asks for the amount you owe and updates the wallet to match, instead of using the signed balance.

