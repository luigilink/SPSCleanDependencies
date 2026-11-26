# SPSCleanDependencies - Release Notes

## [2.0.1] - 2026-11-26

### Changed

- Clean runs now report explicit `Completed` / `Skipped` / `Failed` outcomes and return a non-zero exit code when at least one cleanup operation fails.
- MissingAssembly diagnostics now include lookup status/details in both JSON output and HTML report, making support triage clearer (`Found`, `NotFound`, `LookupError`, `ParseError`).
- MissingAssembly cleanup validation is now HostType-aware and explicitly skips diagnostic-only entries instead of attempting a no-op cleanup path.
