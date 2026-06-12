# Change log for SPSCleanDependencies

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
  - Suppress `PSUseSingularNouns` on the public `Get-SPSMissingServerDependencies` function (name preserved for backward compatibility).

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
