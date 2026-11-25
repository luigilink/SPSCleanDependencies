function Remove-SPSMissingAssembly {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Database,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $AssemblyID,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $SiteID,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $WebID,

        [Parameter(Mandatory = $true)]
        [ValidateSet('0', '1', '2')]
        [System.String]
        $HostType,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $HostID
    )

    try {
        Write-Output '-----------------------------------------------'
        Write-Output 'Removing Missing Assembly Dependencies of:'
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
                $site = Get-SPSite -Limit ALL -Identity $SiteID -ErrorAction SilentlyContinue
                if ($null -ne $site) {
                    try {
                        $assemblyToDelete = $site.EventReceivers | Where-Object -FilterScript {
                            $_.Id -eq $AssemblyID
                        }
                        if ($null -ne $assemblyToDelete) {
                            if ($PSCmdlet.ShouldProcess("SPSite $SiteID", "Delete AssemblyID $AssemblyID")) {
                                $assemblyToDelete.Delete()
                                Write-Output "AssemblyID $AssemblyID removed from SPSite object."
                            }
                        }
                        else {
                            Write-Output "AssemblyID $AssemblyID does not exist in SPSite object."
                        }
                    }
                    finally {
                        $site.Dispose()
                    }
                }
                else {
                    Write-Output "SiteID $SiteID does not exist.`nPlease check this siteID"
                }
            }
            '1' {
                Write-Output ' * HostTypeValue: 1 => SPWeb'
                $web = Get-SPWeb -Identity $WebID -Site $SiteID -Limit ALL -ErrorAction SilentlyContinue
                if ($null -ne $web) {
                    try {
                        $assemblyToDelete = $web.EventReceivers | Where-Object -FilterScript {
                            $_.Id -eq $AssemblyID
                        }
                        if ($null -ne $assemblyToDelete) {
                            if ($PSCmdlet.ShouldProcess("SPWeb $WebID", "Delete AssemblyID $AssemblyID")) {
                                $assemblyToDelete.Delete()
                                Write-Output "AssemblyID $AssemblyID removed from SPWeb object."
                            }
                        }
                        else {
                            Write-Output "AssemblyID $AssemblyID does not exist in SPWeb object."
                        }
                    }
                    finally {
                        $web.Dispose()
                    }
                }
                else {
                    Write-Output "WebID $WebID does not exist.`nPlease check this WebID"
                }
            }
            '2' {
                Write-Output ' * HostTypeValue: 2 => SPList'
                $web = Get-SPWeb -Identity $WebID -Site $SiteID -Limit ALL -ErrorAction SilentlyContinue
                if ($null -ne $web) {
                    try {
                        $list = $web.Lists | Where-Object -FilterScript { $_.Id -eq $HostID }
                        if ($null -ne $list) {
                            $assemblyToDelete = $list.EventReceivers | Where-Object -FilterScript {
                                $_.Id -eq $AssemblyID
                            }
                            if ($null -ne $assemblyToDelete) {
                                if ($PSCmdlet.ShouldProcess("SPList $HostID", "Delete AssemblyID $AssemblyID")) {
                                    $assemblyToDelete.Delete()
                                    Write-Output "AssemblyID $AssemblyID removed from SPList object."
                                }
                            }
                            else {
                                Write-Output "AssemblyID $AssemblyID does not exist in SPList object."
                            }
                        }
                        else {
                            Write-Output "List with host $HostID does not exist.`nPlease check this hostID"
                        }
                    }
                    finally {
                        $web.Dispose()
                    }
                }
                else {
                    Write-Output "WebID $WebID does not exist.`nPlease check this WebID"
                }
            }
            default {
                Throw "Unsupported HostType value '$HostType'. Expected values are 0, 1, or 2."
            }
        }
    }
    catch {
        Throw ("Remove-SPSMissingAssembly failed (Database='{0}', AssemblyID='{1}', SiteID='{2}', WebID='{3}', HostType='{4}', HostID='{5}'). {6}" -f $Database, $AssemblyID, $SiteID, $WebID, $HostType, $HostID, $_.Exception.Message)
    }
}
