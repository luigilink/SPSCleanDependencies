function Get-SQLMissingAssemblyInfo {
    param
    (
        [Parameter()]
        [System.String]
        $DatabaseName,

        [Parameter()]
        [System.String]
        $DatabaseServer,

        [Parameter()]
        [System.String]
        $AssemblyInfo
    )

    class SQLMissingSetupFileInfo {
        [System.String]$AssemblyID
        [System.String]$SiteID
        [System.String]$WebId
        [System.String]$HostId
        [System.String]$HostType
    }
    $tbSQLmissingAssemblies = New-Object -TypeName System.Collections.ArrayList
    try {
        $sqlQuery =
        @"
USE $($DatabaseName)
Select Id, SiteID, WebID, HostType, hostId
FROM EventReceivers (NOLOCK) where Assembly = '$($AssemblyInfo)'
"@

        $invokeSQLQueries = Invoke-Sqlcmd -Query $sqlQuery `
            -ServerInstance "$($DatabaseServer)"

        foreach ($invokeSQLQuery in $invokeSQLQueries) {
            [void]$tbSQLmissingAssemblies.Add([SQLMissingSetupFileInfo]@{
                    AssemblyID = $invokeSQLQuery.id;
                    SiteID     = $invokeSQLQuery.SiteID;
                    WebId      = $invokeSQLQuery.WebId;
                    HostId     = $invokeSQLQuery.HostId;
                    HostType   = $invokeSQLQuery.HostType;
                })
        }
    }
    catch {
        return $_
    }
    return $tbSQLmissingAssemblies
}
