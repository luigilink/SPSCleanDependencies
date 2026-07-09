function Remove-SPSMissingSetupFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter()]
        [System.String]
        $Database,

        [Parameter()]
        [System.String]
        $FileID,

        [Parameter()]
        [System.String]
        $SiteID,

        [Parameter()]
        [System.String]
        $WebID
    )

    try {
        Write-Output '-----------------------------------------------'
        Write-Output 'Removing Missing Setup File Dependencies of:'
        Write-Output " * Database: $Database"
        Write-Output " * FileID: $FileID"
        Write-Output " * SiteID: $SiteID"
        Write-Output " * WebID: $WebID"
        Write-Output '-----------------------------------------------'
        #Display site information
        $site = Get-SPSite $SiteID -ErrorAction SilentlyContinue
        if ($null -ne $site) {
            Write-Output "Checking SPSite: $($site.Url)"
            $web = Get-SPWeb -Identity $WebID -Site $siteID -Limit ALL
            if ($null -ne $web) {
                Write-Output "Checking SPWeb Object ID: $WebID"
                $file = $web.GetFile([GUID]$FileID)
                if ($null -ne $file.ServerRelativeUrl) {
                    $filelocation = "{0}{1}" -f ($site.WebApplication.Url).TrimEnd("/"), $file.ServerRelativeUrl
                    Write-Output "Found file location: $filelocation"
                    #Delete the file, the Delete() method bypasses the recycle bin
                    if ($PSCmdlet.ShouldProcess($filelocation, "Delete setup file $FileID")) {
                        $file.Delete()
                    }
                    $web.dispose()
                    $site.dispose()
                }
                else {
                    Write-Output "SetupFileID $FileID does not exist.`nPlease check this SetupFileID"
                }
            }
            else {
                Write-Output "WebID $WebID does not exist.`nPlease check this WebID"
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
