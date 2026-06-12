# SPSCleanDependencies - Release Notes

## [1.2.0] - 2026-06-11

### Added

- SPSCleanDependencies.util.psm1:
  - Add `Get-SQLMissingWebPartInfo` helper to resolve missing WebPart class IDs to per-page locations.
  - Add `Remove-SPSMissingWebPart` cleanup function (uses `GetLimitedWebPartManager` and temporarily clears the site `ReadOnly` flag).
  - Extend `SPMissingWebPartInfo` class with location fields (`StorageKey`, `SiteID`, `WebID`, `ListID`, `DirName`, `LeafName`).
  - All `Remove-SPS*` functions now support `-WhatIf` / `-Confirm` via `SupportsShouldProcess`.
  - Import-time prelude (admin check, `powercfg`, SharePoint snap-in load) is now gated behind the `SPSCD_SKIP_PRELUDE` environment variable so the module can be imported on CI / non-SharePoint hosts.

- SPSCleanDependencies.ps1:
  - Implement the `MissingWebPart` cleanup branch (previously a no-op).
  - Implement the `SiteOrphan` cleanup branch by wiring up the existing `Remove-SPSOrphanedSite` function.

- Pester test suite under `tests/` covering the script and helper module, including `SupportsShouldProcess` coverage on every `Remove-SPS*` function.

- `.github/workflows/pester.yml` CI workflow running Pester 5.3+ and `PSScriptAnalyzer` on `windows-latest`.

### Fixed

- Replace `Write-Host` with `Write-Output` in `Remove-SPSMissingSetupFile` and clear remaining `PSScriptAnalyzer` warnings.
- Stop hiding real `Import-Module` failures in the module Pester tests so future regressions surface immediately.

A full list of changes in each version can be found in the [change log](CHANGELOG.md)
