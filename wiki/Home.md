# SPSCleanDependencies - SharePoint Trust Farm Tool

SPSCleanDependencies is a PowerShell script tool to configure trust Farm in your SharePoint environment.

## Key Features

- Dependency Detection (default): Detects missing server-side dependencies and outputs them to a JSON file.
- Dependency Cleanup (-Clean switch):
  - Reads a JSON configuration file (if it exists) to identify missing dependencies.
  - Handles the following types of missing dependencies:
  - Features: Removes missing feature references.
  - WebParts: Placeholder for removing missing WebPart references.
  - Setup Files: Removes missing setup file references.
  - Assemblies: Removes missing assembly references.
  - Configuration: Updates SPSite owners with classic authentication and removes missing configuration references.
- Logging:
  - Creates a log file in the Logs folder with a timestamped filename.
  - Outputs script metadata, including version, start time, and PowerShell version.

For details on usage, configuration, and parameters, explore the links below:

- [Getting Started](./Getting-Started)
- [Usage](./Usage)
