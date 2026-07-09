function Remove-SPSOrphanedSite {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter()]
        [System.String]
        $Database,

        [Parameter()]
        [System.String]
        $SiteID
    )

    try {
        Write-Output '-----------------------------------------------'
        Write-Output 'Removing Orphaned Site Dependencies of:'
        Write-Output " * Database: $Database"
        Write-Output " * SiteID: $SiteID"
        Write-Output '-----------------------------------------------'

        $spContentDb = Get-SPContentDatabase $Database
        if ($null -ne $spContentDb) {
            Write-Output "Removing SPSite object $SiteID with the method ForceDeleteSite"
            if ($PSCmdlet.ShouldProcess("SiteID $SiteID in database $Database", 'ForceDeleteSite')) {
                $spContentDb.ForceDeleteSite($siteID, $false, $false)
            }
        }
        else {
            Write-Output "SPContentDatabse $Database does not exist.`nPlease check this Database"
        }
    }
    catch {
        return $_
    }
}
