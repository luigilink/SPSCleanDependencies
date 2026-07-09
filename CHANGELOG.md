# Change log for SPSCleanDependencies

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-07-09

### Added

- Results history:
  - New `Backup-SPSJsonFile` public function archives the current `Results\<FileName>.json` into `Results\history\` with a `yyyyMMdd-HHmm` timestamp before each audit overwrites it (pattern reused from SPSUserSync / SPSWeather).
  - New `Clear-SPSLogFolder` public function — a single retention/rotation implementation reused for both the transcript logs (`*.log`) and the archived snapshots (`*.json`). `Retention = 0` disables pruning.
- HTML report:
  - New `Export-SPSCleanDependenciesReport` public function renders the results JSON as a self-contained, dependency-free HTML report — one summary card per dependency category plus a filterable/sortable table per non-empty category, or a clean "nothing to clean" state. Uses an atomic write (temp file + `Move-Item`).
  - New internal helpers (Private, not exported): `ConvertTo-SPSHtmlEncoded`, `Get-SPSReportHtmlHead`, `Get-SPSReportCardHtml`, `Get-SPSReportHtmlScript` (pattern reused from SPSUpdate.Common).
- `SPSCleanDependencies.ps1`:
  - The audit run now archives the previous results, generates `Results\<FileName>.html`, and prunes old history/logs. The current `Results\<FileName>.json` stays stable (still the exact input consumed by `-Clean`); only the history copies are timestamped.
  - New `-HistoryRetentionDays` (default 30) and `-LogRetentionDays` (default 180) parameters control retention; `0` disables pruning. [issue #8](https://github.com/luigilink/SPSCleanDependencies/issues/8)
- Pester coverage for the new functions and the audit-branch wiring.

## [1.3.0] - 2026-07-09

### Changed

- Restructure the helper module into `src/Modules/SPSCleanDependencies.Common` following the `SPSUpdate` pattern:
  - One function per file under `Public/` (`Get-SPSInstalledProductVersion`, `Get-SPSMissingServerDependencies` and the six `Remove-SPS*` cleanups) and the internal SQL helpers under `Private/` (`Get-SQLMissing*`, no longer exported to callers).
  - Add a loader `SPSCleanDependencies.Common.psm1` that dot-sources `Private/` + `Public/` and exports only the public functions.
  - Add a clean `SPSCleanDependencies.Common.psd1` manifest (`ModuleVersion` `1.3.0`, correct `FunctionsToExport`) replacing the mis-named, never-imported `SPSCleanDependencies.util.util.psd1`.
  - Fold the former module-level classes, `ArrayList` collections and `jsonObject` into `Get-SPSMissingServerDependencies` (their only consumer) so the module holds no mutable state.
- Move the entry script to `src/SPSCleanDependencies.ps1` and import the module through its manifest. The script version is now sourced from `(Get-Module SPSCleanDependencies.Common).Version` instead of a hard-coded string.
- Relocate the import-time prelude (administrator check, High Performance power plan and SharePoint snap-in / `SharePointServer` module load) from the module into the entry script, making the module import-safe by design (the `SPSCD_SKIP_PRELUDE` gate is no longer needed).
- Behaviour on a real SharePoint farm is unchanged. [issue #6](https://github.com/luigilink/SPSCleanDependencies/issues/6)

- Tests:
  - Rename the module test file to `tests/Modules/SPSCleanDependencies.Common.Tests.ps1` and adapt it to the new layout (import via the `.psd1` manifest, resolve the internal SQL helpers through `InModuleScope`, assert `FunctionsToExport` matches the exported set, match the `SPMissing*` classes against `Public/Get-SPSMissingServerDependencies.ps1`).
  - Point the entry-script tests at `src/SPSCleanDependencies.ps1` and assert the manifest-based import and version sourcing.

- CI:
  - `pester.yml` / `release.yml` / `wiki.yml` adapted to the `src/` layout (workflow `paths`, PSScriptAnalyzer targets, release ZIP of `src/` contents).
  - Bump deprecated GitHub Actions (Node 20 runtime warnings): `actions/checkout@v4` -> `v7`, `actions/upload-artifact@v4` -> `v7`, `softprops/action-gh-release@v2` -> `v3`.

### Fixed

- Home wiki page: describe the WebParts and Orphaned Sites cleanups as implemented (they stopped being placeholders in 1.2.0).

## [1.2.0] - 2026-06-11

### Added

- SPSCleanDependencies.util.psm1:
  - Add `Get-SQLMissingWebPartInfo` helper to resolve missing WebPart class IDs to per-page locations (SiteID/WebID/ListID/DirName/LeafName).
  - Add `Remove-SPSMissingWebPart` cleanup function (uses `GetLimitedWebPartManager` and temporarily clears the site `ReadOnly` flag).
  - Extend `SPMissingWebPartInfo` class with `ClassName`, `StorageKey`, `SiteID`, `WebID`, `ListID`, `DirName`, `LeafName`.
  - All `Remove-SPS*` functions now declare `[CmdletBinding(SupportsShouldProcess = $true)]` and gate destructive calls with `$PSCmdlet.ShouldProcess`, enabling `-WhatIf` / `-Confirm` for every cleanup branch.
  - Import-time prelude (admin check, `powercfg`, SharePoint snap-in load) is now gated behind the `SPSCD_SKIP_PRELUDE` environment variable so the module can be imported on non-SharePoint hosts (CI, Pester) without elevation or SharePoint installed. Behaviour on a real SharePoint farm is unchanged.

- SPSCleanDependencies.ps1:
  - Implement the `MissingWebPart` cleanup branch (previously a no-op).
  - Implement the `SiteOrphan` cleanup branch by wiring up the existing `Remove-SPSOrphanedSite` function.

- Pester test suite under `tests/`:
  - `tests/SPSCleanDependencies.Tests.ps1` - script-level tests (metadata, parameters, module imports, Clean branch wiring).
  - `tests/Modules/SPSCleanDependencies.util.Tests.ps1` - module-level tests (public/SQL function contracts, class shapes, safety net for empty `StorageKey`, `SupportsShouldProcess` coverage on every `Remove-SPS*` function).

- CI:
  - `.github/workflows/pester.yml` - runs Pester 5.3+ on `windows-latest` for pull requests to `main`, plus a `PSScriptAnalyzer` code-quality job.

### Fixed

- SPSCleanDependencies.util.psm1:
  - Replace `Write-Host` in `Remove-SPSMissingSetupFile` with `Write-Output` (PSScriptAnalyzer `PSAvoidUsingWriteHost`).

- CI / repo configuration:
  - Add `PSScriptAnalyzerSettings.psd1` at the repo root, excluding `PSUseSingularNouns` so the public `Get-SPSMissingServerDependencies` function can keep its current (plural) name for backward compatibility. The CI workflow now invokes `Invoke-ScriptAnalyzer` with `-Settings ./PSScriptAnalyzerSettings.psd1`.

- tests/Modules/SPSCleanDependencies.util.Tests.ps1:
  - Surface real `Import-Module` failures instead of silently swallowing them with `-ErrorAction SilentlyContinue`, which had been hiding the actual cause of cascading test failures on CI.

## [1.1.0] - 2025-10-21

### Changed

- SPSCleanDependencies.ps1:
  - Resolve Invoke-Sqlcmd does not work because sqlserver is not present [issue #2](https://github.com/luigilink/SPSCleanDependencies/issues/2)
  - Resolve Performing the operation "Set-SPSite" on target "*sitemaster-*" [issue #3](https://github.com/luigilink/SPSCleanDependencies/issues/3)

- Wiki Documentation in repository - Update :
  - wiki/Home.md
  - wiki/Getting-Started.md
  - wiki/Usage.md

- Issue Templates files:
  - 1_bug_report.yml Update version

- README.md
  - Add Requirements for PowerShell 5 and SqlServer PowerShell Module

## [1.0.0] - 2025-04-04

### Added

- Add RELEASE-NOTES.md file
- Add CHANGELOG.md file
- Add CONTRIBUTING.md file
- Add release.yml file
- Add scripts folder with first version of SPSCleanDependencies
- README.md
  - Add code_of_conduct.md badge
- Add CODE_OF_CONDUCT.md file
- Add Issue Templates files:
  - 1_bug_report.yml
  - 2_feature_request.yml
  - 3_documentation_request.yml
  - 4_improvement_request.yml
  - config.yml
- Wiki Documentation in repository - Add :
  - wiki/Home.md
  - wiki/Getting-Started.md
  - wiki/Configuration.md
  - wiki/Usage.md
  - .github/workflows/wiki.yml

### Changed

- SPSCleanDependencies.ps1:
  - Update parameter description
  - Add missing comments
