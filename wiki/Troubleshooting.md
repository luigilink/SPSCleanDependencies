# Troubleshooting

Common issues when running SPSCleanDependencies and how to resolve them.

## `Invoke-Sqlcmd is not recognized` / SQL lookups fail

The tool resolves web part, setup file, assembly and configuration locations by querying the content database with `Invoke-Sqlcmd`, which ships with the **SqlServer** PowerShell module.

- Install it from the PowerShell Gallery:

  ```powershell
  Install-Module -Name SqlServer -Scope AllUsers
  ```

- The entry script imports it at startup and exits early if it is missing. See [Getting Started → Prerequisites](Getting-Started).

## `Administrator rights are required`

The script must run in an **elevated** PowerShell session (it loads the SharePoint Server module, reads content databases and, in `-Clean` mode, modifies farm objects). Re-run PowerShell as Administrator.

## SharePoint cmdlets are not available

The entry script loads the SharePoint Server management module (`SharePointServer`) for you. Run the script **on a SharePoint Server Subscription Edition server** with the management tools installed, using a farm account (or an account that is a member of the Farm Administrators group and has the `SharePoint_Shell_Access` role on the content databases).

> [!NOTE]
> SharePoint Server 2016 and 2019 (which exposed cmdlets through the legacy `Microsoft.SharePoint.PowerShell` snap-in) reached end of support on 14 July 2026 and are no longer supported. Use the previous major release (v1.4.0) for those versions.

## Nothing happens / `Missing <FileName>.json`

`-Clean` consumes the results file produced by a prior audit run. If it is missing you will get:

```
Missing <path>\Results\<FileName>.json
Please re-run this script without the switch parameter Clean
```

Run the audit first (no `-Clean`), review the JSON, then run `-Clean` with the **same** `-FileName`. See [Usage](Usage).

## Preview a cleanup without changing anything

Every `Remove-SPS*` function supports `ShouldProcess`, so you can dry-run the module functions with `-WhatIf` (or force a prompt with `-Confirm`) before committing to a change:

```powershell
Import-Module .\src\Modules\SPSCleanDependencies.Common\SPSCleanDependencies.Common.psd1
Remove-SPSMissingFeature -Database 'WSS_Content' -FeatureID '...' -SiteID '...' -WhatIf
```

## A missing site definition was reported but not removed

This is expected — `MissingSiteDefinition` is **audit only**. See [Dependency Types → MissingSiteDefinition](Dependency-Types#missingsitedefinition). A missing site definition normally requires re-installing the template or migrating the affected sites, which is an administrator decision, not an automatic deletion.

## Where are the logs?

Each run starts a transcript under `Logs\<FileName>_<timestamp>.log` next to the script, and the results are written to `Results\<FileName>.json`. Both folders are created automatically on first run.

> [!IMPORTANT]
> Back up your content databases and test on a non-production farm before running `-Clean`. The cleanup functions delete farm objects and, for setup files, bypass the recycle bin.

## See also

- [Getting Started](Getting-Started)
- [Usage](Usage)
- [Dependency Types](Dependency-Types)
