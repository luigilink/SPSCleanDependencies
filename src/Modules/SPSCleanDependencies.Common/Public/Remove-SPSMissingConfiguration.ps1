function Remove-SPSMissingConfiguration {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter()]
        [System.String]
        $Database,

        [Parameter()]
        [System.String]
        $SiteID,

        [Parameter()]
        [System.String]
        $Login
    )

    try {
        Write-Output '-----------------------------------------------'
        Write-Output 'Removing Missing Configuration Dependencies of:'
        Write-Output " * Database: $Database"
        Write-Output " * SiteID: $SiteID"
        Write-Output " * Login: $Login"
        Write-Output '-----------------------------------------------'

        $site = Get-SPSite -limit all -Identity $siteID
        if ($null -ne $site) {
            Write-Output "Checking SPSite: $($site.Url)"
            $webs = Get-SPWeb -Site $siteID -Limit ALL
            if ($null -ne $webs) {
                foreach ($web in $webs) {
                    if ($web.SiteAdministrators.UserLogin -contains $Login) {
                        Write-Output "$Login exists in SiteAdministrators"
                        Write-Output "Removing login: $Login"
                        Write-Output "of SiteAdministrator Property of SPWeb:"
                        Write-Output "$($web.Url)"
                        if ($PSCmdlet.ShouldProcess($web.Url, "Remove SiteAdministrator $Login")) {
                            $web.SiteAdministrators.Remove($Login)
                        }
                    }
                    else {
                        Write-Output "$Login does not exist in SiteAdministrators Property"
                    }
                    $web.Dispose()
                }
                $site.Dispose()
            }
            else {
                Write-Output "No SPWeb Object for this SiteID $SiteID"
            }
        }
        else {
            Write-Output "SiteID $SiteID does not exist.`nPlease check this siteID"
        }
    }
    catch {
        return $_
    }
}
