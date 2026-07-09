# Dependency Types

SPSCleanDependencies runs `Test-SPContentDatabase -ExtendedCheck` against every content database and groups the reported issues into categories. In **audit** mode each category is written to the results JSON file; with the `-Clean` switch each category is remediated by a dedicated function.

This page documents every category, what it means, how the tool remediates it, and how it is represented in the results JSON.

## Overview

| Category (JSON key) | Detected by | Cleanup function | SharePoint object acted on |
|---|---|---|---|
| `MissingFeature` | `Test-SPContentDatabase` | `Remove-SPSMissingFeature` | Site collection + all webs |
| `MissingWebPart` | `Test-SPContentDatabase` + SQL lookup | `Remove-SPSMissingWebPart` | Web part on a specific page |
| `MissingSetupFile` | `Test-SPContentDatabase` + SQL lookup | `Remove-SPSMissingSetupFile` | Ghosted file in a web |
| `MissingAssembly` | `Test-SPContentDatabase` + SQL lookup | `Remove-SPSMissingAssembly` | Event receiver on site/web/list |
| `Configuration` | `Test-SPContentDatabase` + SQL lookup | `Remove-SPSMissingConfiguration` | Classic-auth site administrators |
| `MissingSiteDefinition` | `Test-SPContentDatabase` | _(audit only — reported, not removed)_ | — |
| `SiteOrphan` | `Test-SPContentDatabase` | `Remove-SPSOrphanedSite` | Orphaned site collection |

> [!NOTE]
> The SQL lookups query the content database directly (read-only, `WITH (NOLOCK)`) to resolve the exact locations that `Test-SPContentDatabase` does not return, so the cleanup can target a precise object rather than scanning the whole farm.

## MissingFeature

A feature is activated on a site collection or web, but its definition is no longer installed on the farm (the feature folder was removed with the solution).

- **Remediation:** `Remove-SPSMissingFeature` walks the site collection and every web and calls `Features.Remove($featureID, $true)` wherever the orphaned feature is found.
- **JSON fields:** `Database`, `Category`, `FeatureID`, `Message`, `Remedy`, `SiteID`, `Path`.

## MissingWebPart

A page references a web part class that is no longer deployed on the farm.

- **Remediation:** `Remove-SPSMissingWebPart` resolves the web part class ID to its per-page location via SQL (`AllDocs` + `AllWebParts`), opens the page with `GetLimitedWebPartManager`, and deletes the specific instance identified by its `StorageKey`. The site `ReadOnly` flag is temporarily cleared and restored around the deletion.
- **Safety net:** if `StorageKey` is empty (no specific instance to remove) the function returns without changing anything.
- **JSON fields:** `Database`, `Category`, `WebPartID`, `Message`, `Remedy`, `ClassName`, `StorageKey`, `SiteID`, `WebID`, `ListID`, `DirName`, `LeafName`.

## MissingSetupFile

A content item points at a setup (template) file on disk (`SetupPath`) that no longer exists on the servers — a "ghosted" file left behind by a removed solution.

- **Remediation:** `Remove-SPSMissingSetupFile` resolves the file via SQL (`AllDocs` on `SetupPath`), opens it with `SPWeb.GetFile()` and calls `Delete()` (which bypasses the recycle bin).
- **JSON fields:** `Database`, `Category`, `Message`, `Remedy`, `SetupPath`, `FileID`, `SiteID`, `WebID`.

## MissingAssembly

An event receiver references an assembly that is no longer present in the GAC / bin.

- **Remediation:** `Remove-SPSMissingAssembly` resolves the receiver via SQL (`EventReceivers`) and removes it from the correct host, dispatched on `HostType`:
  - `0` → `SPSite`
  - `1` → `SPWeb`
  - `2` → `SPList`
- **JSON fields:** `Database`, `Category`, `Message`, `Remedy`, `AssemblyInfo`, `AssemblyID`, `HostID`, `HostType`, `SiteID`, `WebID`.

## Configuration

Reported when a site administrator entry uses classic (non-claims) authentication.

- **Remediation:** `Remove-SPSMissingConfiguration` removes the offending login from the `SiteAdministrators` collection of each web. In addition, the entry script rewrites the owner of any site collection whose `Owner` is still a classic account (`Owner -notlike 'i:0#.w|*'`, excluding `sitemaster-*`) to the farm default service account before the configuration entries are cleaned.
- **JSON fields:** `Database`, `Category`, `Message`, `Remedy`, `SiteID`, `Login`.

## MissingSiteDefinition

A site collection references a site definition (webtemp) that is no longer installed.

- **Remediation:** **audit only.** The category is detected and written to the JSON for visibility, but there is no automatic removal — a missing site definition usually requires re-installing the template or migrating the affected sites, which must be decided by an administrator.
- **JSON fields:** `Database`, `Category`, `Message`, `Remedy`.

## SiteOrphan

A site collection exists in the content database but is not registered in the configuration database (or vice versa).

- **Remediation:** `Remove-SPSOrphanedSite` calls `SPContentDatabase.ForceDeleteSite($siteID, $false, $false)` to remove the orphaned site from the database.
- **JSON fields:** `Database`, `Category`, `Message`, `Remedy`, `SiteID`.

## Results JSON shape

In audit mode the results file (`Results\<FileName>.json`) is a single object whose properties are the categories that were found. Each property is an array of the objects described above:

```json
{
  "MissingFeature":       [ { "Database": "...", "FeatureID": "...", "SiteID": "..." } ],
  "MissingWebPart":       [ { "Database": "...", "WebPartID": "...", "StorageKey": "...", "DirName": "...", "LeafName": "..." } ],
  "MissingSetupFile":     [ { "Database": "...", "FileID": "...", "SiteID": "...", "WebID": "..." } ],
  "MissingAssembly":      [ { "Database": "...", "AssemblyID": "...", "HostType": "0", "HostID": "..." } ],
  "Configuration":        [ { "Database": "...", "SiteID": "...", "Login": "..." } ],
  "MissingSiteDefinition":[ { "Database": "...", "Message": "...", "Remedy": "..." } ],
  "SiteOrphan":           [ { "Database": "...", "SiteID": "..." } ]
}
```

> [!IMPORTANT]
> The results file is the exact input consumed by the `-Clean` run. Always review it (and back up your content databases) before cleaning. See [Usage](Usage).

## See also

- [Usage](Usage)
- [Troubleshooting](Troubleshooting)
