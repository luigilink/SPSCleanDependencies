# SPSCleanDependencies - Release Notes

## [2.0.0] - 2026-09-01

### Removed

- **BREAKING** — dropped support for SharePoint Server 2016 and 2019 (both reached end of support on 14 July 2026). SPSCleanDependencies now targets **SharePoint Server Subscription Edition only**.
- Removed the installed-build detection and the legacy `Microsoft.SharePoint.PowerShell` PSSnapin loading path (`Get-PSSnapin` / `Add-PSSnapin`) from `SPSCleanDependencies.ps1`.

### Changed

- `SPSCleanDependencies.ps1` now loads the `SharePointServer` module only (idempotent), guarded by a clear "SharePoint installed" check via `Get-SPSInstalledProductVersion`.
- Neutralized the version-specific help examples (`CONTOSO-PROD-SP2019` → `CONTOSO-PROD-SPSE`).
- Documentation (README, wiki) now states Subscription Edition as the only supported version.

### Migration

- Users still running SharePoint Server 2016 or 2019 should stay on the previous major release (v1.4.0).

A full list of changes in each version can be found in the [change log](CHANGELOG.md)
