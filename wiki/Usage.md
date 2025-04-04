# Usage

## Parameters

| Parameter   | Description                                        |
| ----------- | -------------------------------------------------- |
| `-FileName` | Specifies the name of the configuration json file. |
| `-Clean`    | Remove missing server side dependencies            |

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
