# Usage

## Parameters

| Parameter   | Description                                        |
| ----------- | -------------------------------------------------- |
| `FileName` | Specifies the name of the configuration json file. |
| `Clean`    | Remove missing server side dependencies            |
| `HistoryRetentionDays` | Days of archived result snapshots to keep in `Results\history` (default 30; `0` disables pruning). |
| `LogRetentionDays` | Days of transcript logs to keep in `Logs` (default 180; `0` disables pruning). |

### Basic Usage Example

Run the script with a specified configuration:

```powershell
.\SPSCleanDependencies.ps1 -FileName 'CONTOSO-PROD-SPSE'
```

### Clean Usage Example

> [!IMPORTANT]
> Backup content database first​ and test script on testing environment

Remove missing server side dependencies on SharePoint farm:

```powershell
.\SPSCleanDependencies.ps1 -FileName 'CONTOSO-PROD-SPSE' -Clean
```

## Next Steps

- [Reports & History](./Reports-and-History) — the generated HTML report and the timestamped results history.
- [Dependency Types](./Dependency-Types) — the categories detected and cleaned, and the results JSON shape.
- [Troubleshooting](./Troubleshooting) — common issues and how to resolve them.
