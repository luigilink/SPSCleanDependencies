function Remove-SPSMissingAssembly {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter()]
        [System.String]
        $Database,

        [Parameter()]
        [System.String]
        $AssemblyID,

        [Parameter()]
        [System.String]
        $SiteID,

        [Parameter()]
        [System.String]
        $WebID,

        [Parameter()]
        [System.String]
        $HostType,

        [Parameter()]
        [System.String]
        $HostID
    )

    try {
        Write-Output '-----------------------------------------------'
        Write-Output 'Removing Missing Setup File Dependencies of:'
        Write-Output " * Database: $Database"
        Write-Output " * AssemblyID: $AssemblyID"
        Write-Output " * SiteID: $SiteID"
        Write-Output " * WebID: $WebID"
        Write-Output " * HostType: $HostType"
        Write-Output " * HostID: $HostID"
        Write-Output '-----------------------------------------------'

        switch ($HostType) {
            '0' {
                Write-Output ' * HostTypeValue: 0 => SPSite'
                $site = Get-SPSite -limit all -Identity $siteID
                if ($null -ne $site) {
                    $AssemblyToDelete = $site.EventReceivers | Where-Object -FilterScript {
                        $_.id -eq $AssemblyID
                    }
                    if ($null -ne $AssemblyToDelete) {
                        Write-Output "Removing AssemblyID $AssemblyID from SPSite object."
                        if ($PSCmdlet.ShouldProcess("SPSite $SiteID", "Delete AssemblyID $AssemblyID")) {
                            $AssemblyToDelete.delete()
                        }
                    }
                    else {
                        Write-Output "AssemblyID $AssemblyID does not exist in SPSite object."
                    }
                    $site.dispose()
                }
                else {
                    Write-Output "SiteID $SiteID does not exist.`nPlease check this siteID"
                }
            }
            '1' {
                Write-Output ' * HostTypeValue: 1 => SPWeb'
                $web = Get-SPWeb -Identity $webID -Site $siteID -Limit ALL
                if ($null -ne $web) {
                    $AssemblyToDelete = $web.EventReceivers | Where-Object -FilterScript {
                        $_.id -eq $AssemblyID
                    }
                    if ($null -ne $AssemblyToDelete) {
                        Write-Output "Removing AssemblyID $AssemblyID from SPWeb object."
                        if ($PSCmdlet.ShouldProcess("SPWeb $WebID", "Delete AssemblyID $AssemblyID")) {
                            $AssemblyToDelete.delete()
                        }
                    }
                    else {
                        Write-Output "AssemblyID $AssemblyID does not exist in SPWeb object."
                    }
                    $web.dispose()
                }
                else {
                    Write-Output "WebID $WebID does not exist.`nPlease check this WebID"
                }
            }
            '2' {
                Write-Output ' * HostTypeValue: 2 => SPList'
                $web = Get-SPWeb -Identity $webID -Site $siteID -Limit ALL
                if ($null -ne $web) {
                    $list = $web.lists | Where-Object -FilterScript { $_.id -eq $hostID }
                    if ($null -ne $list) {
                        $AssemblyToDelete = $list.EventReceivers | Where-Object -FilterScript {
                            $_.id -eq $AssemblyID
                        }
                        if ($null -ne $AssemblyToDelete) {
                            Write-Output "Removing AssemblyID $AssemblyID from SPList object."
                            if ($PSCmdlet.ShouldProcess("SPList $hostID", "Delete AssemblyID $AssemblyID")) {
                                $AssemblyToDelete.delete()
                            }
                        }
                        else {
                            Write-Output "AssemblyID $AssemblyID does not exist in SPList object."
                        }
                        $web.dispose()
                    }
                    else {
                        Write-Output "List with host $hostID does not exist.`nPlease check this hostID"
                    }
                }
                else {
                    Write-Output "WebID $WebID does not exist.`nPlease check this WebID"
                }
            }
        }
    }
    catch {
        return $_
    }
}
