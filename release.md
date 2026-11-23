## [3.0.5] - 2026-11-24

### Fixed
- Deleting a transaction no longer gets stuck syncing when the server copy of it disappears while the delete is in flight — the delete is dropped instead of retrying forever.
