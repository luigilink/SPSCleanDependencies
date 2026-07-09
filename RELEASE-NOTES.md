# SPSCleanDependencies - Release Notes

## [1.4.0] - 2026-07-09

### Added

- **Results history** — the audit no longer overwrites its output blindly. Before each run the current `Results\<FileName>.json` is archived into `Results\history\` with a `yyyyMMdd-HHmm` timestamp:
  - `Backup-SPSJsonFile` (public) creates the timestamped copy.
  - `Clear-SPSLogFolder` (public) is the single retention/rotation implementation, reused for both transcript logs (`*.log`) and archived snapshots (`*.json`). `Retention = 0` disables pruning.
- **HTML report** — `Export-SPSCleanDependenciesReport` (public) renders the results JSON as a self-contained, dependency-free HTML file: one summary card per dependency category plus a filterable/sortable table per non-empty category, or a clean "nothing to clean" state. Backed by internal helpers `ConvertTo-SPSHtmlEncoded`, `Get-SPSReportHtmlHead`, `Get-SPSReportCardHtml`, `Get-SPSReportHtmlScript` (pattern from SPSUpdate.Common).
- **Entry script** — the audit run now archives the previous results, writes `Results\<FileName>.html`, and prunes old history/logs. The current `Results\<FileName>.json` stays stable (still the exact input consumed by `-Clean`); only the history copies are timestamped. New `-HistoryRetentionDays` (default 30) and `-LogRetentionDays` (default 180) parameters control retention; `0` disables pruning.
- Pester coverage for the new functions and the audit-branch wiring.

A full list of changes in each version can be found in the [change log](CHANGELOG.md)
