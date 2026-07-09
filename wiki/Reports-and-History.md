# Reports & History

Since v1.4.0 every audit run (SPSCleanDependencies.ps1 without `-Clean`) produces three things next to the script:

```
Logs/
  <FileName>_<timestamp>.log        # transcript of the run
Results/
  <FileName>.json                   # current results (consumed by -Clean)
  <FileName>.html                   # human-readable report of this run
  history/
    <FileName>-yyyyMMdd-HHmm.json   # timestamped archive of each previous run
```

## HTML report

`Results\<FileName>.html` is a self-contained, dependency-free HTML file (no CDN — it opens offline on a SharePoint server). It contains:

- A **summary** with one card per dependency category showing how many items were found (green when a category is empty, red when it has items), plus a **Total items** card.
- For every **non-empty** category, a **filterable and sortable** table of the items with their identifying fields (database, IDs, page, login, …). See [Dependency Types](./Dependency-Types) for the meaning of each category and its fields.
- A clean **"No missing server side dependencies were found"** state when the farm is clean.

All values coming from the farm are HTML-encoded, so database names, messages and logins cannot break the report layout.

> [!TIP]
> The report is a convenience view of `Results\<FileName>.json`. The JSON remains the exact input consumed by the `-Clean` run — always review it (and back up your content databases) before cleaning.

## Results history

Before each audit overwrites `Results\<FileName>.json`, the previous file is copied into `Results\history\` with a `yyyyMMdd-HHmm` timestamp (e.g. `CONTOSO-PROD-SPSE-20260709-1615.json`). This keeps a trail of how the missing-dependency situation evolved over time, without changing the name of the current file.

Only the **history copies** are timestamped; the current `Results\<FileName>.json` and `Results\<FileName>.html` keep their stable names so `-Clean` and any downstream tooling always find the latest run.

## Retention

Old files are pruned automatically at the end of each audit run:

| What | Parameter | Default | Disable |
|---|---|---|---|
| History snapshots (`Results\history\*.json`) | `-HistoryRetentionDays` | 30 days | `0` |
| Transcript logs (`Logs\*.log`) | `-LogRetentionDays` | 180 days | `0` |

Example — keep 90 days of history and never prune logs:

```powershell
.\SPSCleanDependencies.ps1 -FileName 'CONTOSO-PROD-SPSE' -HistoryRetentionDays 90 -LogRetentionDays 0
```

## See also

- [Usage](./Usage)
- [Dependency Types](./Dependency-Types)
- [Troubleshooting](./Troubleshooting)
