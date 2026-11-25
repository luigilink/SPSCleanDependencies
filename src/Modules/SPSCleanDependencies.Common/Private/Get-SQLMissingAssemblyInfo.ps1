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

    if ([string]::IsNullOrWhiteSpace($DatabaseName)) {
        Throw 'DatabaseName is required for Get-SQLMissingAssemblyInfo.'
    }
    if ([string]::IsNullOrWhiteSpace($DatabaseServer)) {
        Throw 'DatabaseServer is required for Get-SQLMissingAssemblyInfo.'
    }
    if ([string]::IsNullOrWhiteSpace($AssemblyInfo)) {
        Throw 'AssemblyInfo is required for Get-SQLMissingAssemblyInfo.'
    }

    class SQLMissingAssemblyInfo {
        [System.String]$AssemblyID
        [System.String]$SiteID
        [System.String]$WebId
        [System.String]$HostId
        [System.String]$HostType
    }

    $tbSQLmissingAssemblies = New-Object -TypeName System.Collections.ArrayList
    try {
        $escapedDatabaseName = $DatabaseName.Replace(']', ']]')
        $escapedAssemblyInfo = $AssemblyInfo.Replace("'", "''")
        $sqlQuery =
@"
USE [$escapedDatabaseName]
Select Id, SiteID, WebID, HostType, hostId
FROM EventReceivers WITH (NOLOCK) where Assembly = N'$escapedAssemblyInfo'
"@

        $invokeSQLQueries = Invoke-Sqlcmd -Query $sqlQuery `
            -ServerInstance "$($DatabaseServer)" `
            -ErrorAction Stop

        foreach ($invokeSQLQuery in $invokeSQLQueries) {
            [void]$tbSQLmissingAssemblies.Add([SQLMissingAssemblyInfo]@{
                    AssemblyID = $invokeSQLQuery.id;
                    SiteID     = $invokeSQLQuery.SiteID;
                    WebId      = $invokeSQLQuery.WebId;
                    HostId     = $invokeSQLQuery.HostId;
                    HostType   = $invokeSQLQuery.HostType;
                })
        }
    }
    catch {
        Throw ("Get-SQLMissingAssemblyInfo failed for database '{0}' on server '{1}' with assembly '{2}'. {3}" -f $DatabaseName, $DatabaseServer, $AssemblyInfo, $_.Exception.Message)
    }

    return $tbSQLmissingAssemblies
}
