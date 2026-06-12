# SPSCleanDependencies - Release Notes

## [1.2.0] - 2026-06-11

### Added

- SPSCleanDependencies.util.psm1:
  - Add `Get-SQLMissingWebPartInfo` helper to resolve missing WebPart class IDs to per-page locations.
  - Add `Remove-SPSMissingWebPart` cleanup function (uses `GetLimitedWebPartManager` and temporarily clears the site `ReadOnly` flag).
  - Extend `SPMissingWebPartInfo` class with location fields (`StorageKey`, `SiteID`, `WebID`, `ListID`, `DirName`, `LeafName`).

- SPSCleanDependencies.ps1:
  - Implement the `MissingWebPart` cleanup branch (previously a no-op).
  - Implement the `SiteOrphan` cleanup branch by wiring up the existing `Remove-SPSOrphanedSite` function.

- Pester test suite under `tests/` covering the script and helper module.

- `.github/workflows/pester.yml` CI workflow running Pester 5.3+ and `PSScriptAnalyzer` on `windows-latest`.

A full list of changes in each version can be found in the [change log](CHANGELOG.md)
