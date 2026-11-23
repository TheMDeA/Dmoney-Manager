## [3.0.4] - 2026-11-24

### Fixed
- Deleting a transaction no longer fails to sync when the server copy of it is already gone — the delete is dropped instead of retrying forever.
