# SPSCleanDependencies - Release Notes

## [1.3.0] - 2026-07-09

### Changed

- Restructure the helper module into `src/Modules/SPSCleanDependencies.Common` (aligned on the `SPSUpdate` pattern):
  - One function per file under `Public/`, internal SQL helpers under `Private/` (`Get-SQLMissing*`, no longer exported).
  - A loader `.psm1` dot-sourcing `Private/` + `Public/`, and a clean `.psd1` manifest (`ModuleVersion` 1.3.0, correct `FunctionsToExport`) replacing the mis-named, never-imported `SPSCleanDependencies.util.util.psd1`.
  - The former module-level classes / `ArrayList` collections / `jsonObject` are folded into `Get-SPSMissingServerDependencies`, so the module holds no mutable state.
- The entry script moves to `src/SPSCleanDependencies.ps1`, imports the module through its manifest, and sources its version from `(Get-Module SPSCleanDependencies.Common).Version`.
- The import-time prelude (administrator check, High Performance power plan, SharePoint snap-in load) moves from the module into the entry script, making the module import-safe by design.
- Behaviour on a real SharePoint farm is unchanged.

### CI

- Workflows adapted to the `src/` layout (`paths`, PSScriptAnalyzer targets, release ZIP of `src/` contents).
- Deprecated GitHub Actions bumped: `actions/checkout@v4` -> `v7`, `actions/upload-artifact@v4` -> `v7`, `softprops/action-gh-release@v2` -> `v3`.

A full list of changes in each version can be found in the [change log](CHANGELOG.md)
