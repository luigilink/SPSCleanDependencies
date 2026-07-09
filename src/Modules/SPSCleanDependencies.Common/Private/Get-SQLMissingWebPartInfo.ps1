function Get-SQLMissingWebPartInfo {
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
        $ClassID
    )

    class SQLMissingWebPartInfo {
        [System.String]$StorageKey
        [System.String]$ClassName
        [System.String]$SiteID
        [System.String]$WebID
        [System.String]$ListID
        [System.String]$DirName
        [System.String]$LeafName
    }
    $tbSQLmissingWebParts = New-Object -TypeName System.Collections.ArrayList
    try {
        $sqlQuery =
        @"
USE $($DatabaseName)
SELECT wp.tp_ID, d.SiteId, d.WebId, d.ListId, d.DirName, d.LeafName, wp.tp_Class
FROM AllDocs d WITH (NOLOCK)
INNER JOIN AllWebParts wp WITH (NOLOCK) ON wp.tp_PageUrlID = d.Id
INNER JOIN AllWebs w WITH (NOLOCK) ON d.WebId = w.id
WHERE wp.tp_WebPartTypeId = '$($ClassID)'
"@

        $invokeSQLQueries = Invoke-Sqlcmd -Query $sqlQuery `
            -ServerInstance "$($DatabaseServer)"

        foreach ($invokeSQLQuery in $invokeSQLQueries) {
            [void]$tbSQLmissingWebParts.Add([SQLMissingWebPartInfo]@{
                    StorageKey = $invokeSQLQuery.tp_ID;
                    ClassName  = $invokeSQLQuery.tp_Class;
                    SiteID     = $invokeSQLQuery.SiteId;
                    WebID      = $invokeSQLQuery.WebId;
                    ListID     = $invokeSQLQuery.ListId;
                    DirName    = $invokeSQLQuery.DirName;
                    LeafName   = $invokeSQLQuery.LeafName;
                })
        }
    }
    catch {
        return $_
    }
    return $tbSQLmissingWebParts
}
