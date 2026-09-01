function Get-SQLMissingSetupFileInfo {
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
        $SetupPath
    )

    class SQLMissingSetupFileInfo {
        [System.String]$FileID
        [System.String]$SiteID
        [System.String]$DirName
        [System.String]$LeafName
        [System.String]$WebId
        [System.String]$ListId
    }
    $tbSQLmissingSetupFiles = New-Object -TypeName System.Collections.ArrayList
    try {
        $sqlQuery =
        @"
USE $($DatabaseName)
SELECT id, SiteID, DirName, LeafName, WebId, ListId
FROM AllDocs (NOLOCK) where SetupPath = '$($SetupPath)'
"@

        $invokeSQLQueries = Invoke-Sqlcmd -Query $sqlQuery `
            -ServerInstance "$($DatabaseServer)"

        foreach ($invokeSQLQuery in $invokeSQLQueries) {
            [void]$tbSQLmissingSetupFiles.Add([SQLMissingSetupFileInfo]@{
                    FileID   = $invokeSQLQuery.id;
                    SiteID   = $invokeSQLQuery.SiteID;
                    DirName  = $invokeSQLQuery.DirName;
                    LeafName = $invokeSQLQuery.LeafName;
                    WebId    = $invokeSQLQuery.WebId;
                    ListId   = $invokeSQLQuery.ListId;
                })
        }
    }
    catch {
        return $_
    }
    return $tbSQLmissingSetupFiles
}
