function Remove-SPSMissingFeature {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter()]
        [System.String]
        $Database,

        [Parameter()]
        [System.String]
        $FeatureID,

        [Parameter()]
        [System.String]
        $SiteID
    )

    try {
        Write-Output '-----------------------------------------------'
        Write-Output 'Removing Missing Feature Dependencies of:'
        Write-Output " * Database: $Database"
        Write-Output " * FeatureID: $FeatureID"
        Write-Output " * SiteID: $SiteID"
        Write-Output '-----------------------------------------------'
        #Display site information
        $site = Get-SPSite $SiteID -ErrorAction SilentlyContinue
        if ($null -ne $site) {
            Write-Output "Checking SPSite: $($site.Url)"
            #Remove the feature from all subsites
            ForEach ($web in $Site.AllWebs) {
                if ($web.Features[$featureID]) {
                    Write-Output "`nFound Feature $featureID in web: $($Web.Url)`nRemoving feature"
                    if ($PSCmdlet.ShouldProcess($Web.Url, "Remove feature $featureID")) {
                        $web.Features.Remove($featureID, $true)
                    }
                }
                else {
                    Write-Output "`nDid not find feature $featureID in web: $($Web.Url)"
                }
            }
            #Remove the feature from the site collection
            if ($Site.Features[$featureID]) {
                Write-Output "`nFound feature $featureID in site: $($site.Url)`nRemoving Feature"
                if ($PSCmdlet.ShouldProcess($site.Url, "Remove feature $featureID")) {
                    $site.Features.Remove($featureID, $true)
                }
            }
            else {
                Write-Output "Did not find feature $featureID in site: $($site.Url)"
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
