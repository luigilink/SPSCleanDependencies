function Get-SQLMissingConfiguration {
    param
    (
        [Parameter()]
        [System.String]
        $DatabaseName,

        [Parameter()]
        [System.String]
        $DatabaseServer
    )

    class SQLMissingConfigurationInfo {
        [System.String]$SiteID
        [System.String]$Login
    }
    $tbSQLmissingConfigurations = New-Object -TypeName System.Collections.ArrayList
    try {
        $sqlQuery =
        @"
USE $($DatabaseName)
SELECT [tp_SiteID],[tp_Login] FROM [UserInfo] WITH (NOLOCK) WHERE tp_IsActive = 1 AND tp_SiteAdmin = 1 AND tp_Deleted = 0 and tp_Login not LIKE 'i:%'
"@
        $invokeSQLQueries = Invoke-Sqlcmd -Query $sqlQuery `
            -ServerInstance "$($DatabaseServer)"

        foreach ($invokeSQLQuery in $invokeSQLQueries) {
            [void]$tbSQLmissingConfigurations.Add([SQLMissingConfigurationInfo]@{
                    SiteID = $invokeSQLQuery.tp_SiteID;
                    Login  = $invokeSQLQuery.tp_Login;
                })
        }
    }
    catch {
        return $_
    }
    return $tbSQLmissingConfigurations
}
