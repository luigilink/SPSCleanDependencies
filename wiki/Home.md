# SPSCleanDependencies - SharePoint SPSCleanDependencies Farm Tool

SPSCleanDependencies is a PowerShell script tool to clean Missing Server Dependencies in your SharePoint Farm.

## Key Features

- Dependency Detection (default): Detects missing server-side dependencies and outputs them to a JSON file.
- Dependency Cleanup (-Clean switch):
  - Reads a JSON configuration file (if it exists) to identify missing dependencies.
  - Handles the following types of missing dependencies:
  - Features: Removes missing feature references.
  - WebParts: Removes missing WebPart references (resolves each WebPart class to its per-page location and removes the instance via `GetLimitedWebPartManager`).
  - Setup Files: Removes missing setup file references.
  - Assemblies: Removes missing assembly references.
  - Configuration: Updates SPSite owners with classic authentication and removes missing configuration references.
  - Orphaned Sites: Removes orphaned site references via `ForceDeleteSite`.
- Logging:
  - Creates a log file in the Logs folder with a timestamped filename.
  - Outputs script metadata, including version, start time, and PowerShell version.

For details on usage, configuration, and parameters, explore the links below:

- [Getting Started](./Getting-Started)
- [Usage](./Usage)
