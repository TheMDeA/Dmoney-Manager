## [2.5.1] - 2026-10-08

### Added
- Receipt scanning can now use a photo from your gallery, not just the camera.

### Fixed
- The Wallets card stack now animates smoothly when you tap a card, and every card shows a clean header instead of cut-off text.
- Receipt scanning now tells you when text recognition fails instead of silently opening an empty form.
- Receipt scanning no longer mistakes the cash tendered (TUNAI) or change (KEMBALI) for the total — those lines are now ignored when finding the total.
- Receipt scanning recognizes more total labels (tagihan, jumlah, total belanja) and cleans up merchant names using a list of common Indonesian stores.
- When the scanned amount looks wrong, the receipt section now offers other amounts found on the receipt to pick from, plus a "what I read" view of the raw text.
