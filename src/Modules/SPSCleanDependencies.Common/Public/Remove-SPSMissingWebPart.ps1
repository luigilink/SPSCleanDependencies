function Remove-SPSMissingWebPart {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter()]
        [System.String]
        $Database,

        [Parameter()]
        [System.String]
        $WebPartID,

        [Parameter()]
        [System.String]
        $StorageKey,

        [Parameter()]
        [System.String]
        $SiteID,

        [Parameter()]
        [System.String]
        $WebID,

        [Parameter()]
        [System.String]
        $DirName,

        [Parameter()]
        [System.String]
        $LeafName
    )

    try {
        Write-Output '-----------------------------------------------'
        Write-Output 'Removing Missing WebPart Dependencies of:'
        Write-Output " * Database: $Database"
        Write-Output " * WebPartID (class): $WebPartID"
        Write-Output " * StorageKey: $StorageKey"
        Write-Output " * SiteID: $SiteID"
        Write-Output " * WebID: $WebID"
        Write-Output " * Page: $DirName/$LeafName"
        Write-Output '-----------------------------------------------'

        if ([string]::IsNullOrEmpty($StorageKey)) {
            Write-Output 'StorageKey is empty - no specific WebPart instance to remove. Re-run the audit to collect per-page locations.'
            return
        }

        $site = Get-SPSite -Limit All -Identity $SiteID -ErrorAction SilentlyContinue
        if ($null -ne $site) {
            $isSiteReadOnly = $site.ReadOnly
            $web = Get-SPWeb -Identity $WebID -Site $site -Limit ALL -ErrorAction SilentlyContinue
            if ($null -ne $web) {
                $webAppUrl = ($site.WebApplication.Url).TrimEnd('/')
                $pageUrl = "{0}/{1}/{2}" -f $webAppUrl, $DirName, $LeafName
                Write-Output "Page URL: $pageUrl"

                if ($isSiteReadOnly) {
                    Write-Output 'ReadOnly flag temporarily removed from site'
                    $site.ReadOnly = $false
                }

                try {
                    $spWebPartManager = $web.GetLimitedWebPartManager($pageUrl, [System.Web.UI.WebControls.WebParts.PersonalizationScope]::Shared)
                    $webPartToDelete = $spWebPartManager.WebParts | Where-Object -FilterScript { $_.StorageKey -eq $StorageKey }
                    if ($null -ne $webPartToDelete) {
                        Write-Output "Removing WebPart with StorageKey $StorageKey from page"
                        if ($PSCmdlet.ShouldProcess($pageUrl, "Delete WebPart with StorageKey $StorageKey")) {
                            $spWebPartManager.DeleteWebPart($spWebPartManager.WebParts[$webPartToDelete.Id])
                        }
                    }
                    else {
                        Write-Output "WebPart with StorageKey $StorageKey not found on page"
                    }
                }
                finally {
                    if ($isSiteReadOnly) {
                        Write-Output 'ReadOnly flag re-applied to site'
                        $site.ReadOnly = $true
                    }
                    $web.Dispose()
                }
            }
            else {
                Write-Output "WebID $WebID does not exist.`nPlease check this WebID"
            }
            $site.Dispose()
        }
        else {
            Write-Output "SiteID $SiteID does not exist.`nPlease check this SiteID"
        }
    }
    catch {
        return $_
    }
}
