function Get-SPSInstalledProductVersion {
    [OutputType([System.Version])]
    param ()

    $pathToSearch = 'C:\Program Files\Common Files\microsoft shared\Web Server Extensions\*\ISAPI\Microsoft.SharePoint.dll'
    $fullPath = Get-Item $pathToSearch -ErrorAction SilentlyContinue | Sort-Object { $_.Directory } -Descending | Select-Object -First 1
    if ($null -eq $fullPath) {
        throw 'SharePoint path {C:\Program Files\Common Files\microsoft shared\Web Server Extensions} does not exist'
    }
    else {
        return (Get-Command $fullPath).FileVersionInfo
    }
}

# Import-time prelude (admin check, power plan, SharePoint snap-in load).
# Skipped when $env:SPSCD_SKIP_PRELUDE is set, so the module can be imported on
# CI / non-SharePoint hosts (e.g. Pester) without elevation or SharePoint installed.
if (-not $env:SPSCD_SKIP_PRELUDE) {
    # Ensure the script is running with administrator privileges
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        Throw "Administrator rights are required. Please re-run this script as an Administrator."
    }
    # Setting power management plan to High Performance"
    Start-Process -FilePath "$env:SystemRoot\system32\powercfg.exe" -ArgumentList '/s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' -NoNewWindow

    # Load SharePoint Powershell Snapin or Import-Module
    try {
        $installedVersion = Get-SPSInstalledProductVersion
        if ($installedVersion.ProductMajorPart -eq 15 -or $installedVersion.ProductBuildPart -le 12999) {
            if ($null -eq (Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue)) {
                Add-PSSnapin Microsoft.SharePoint.PowerShell
            }
        }
        else {
            Import-Module SharePointServer -Verbose:$false -WarningAction SilentlyContinue -DisableNameChecking
        }
    }
    catch {
        # Handle errors during retrieval of Installed Product Version
        $catchMessage = @"
Failed to get installed Product Version for $($env:COMPUTERNAME)
Exception: $($_.Exception.Message)
"@
        Write-Error -Message $catchMessage
    }
}

# Initialize jSON Object
New-Variable -Name jsonObject `
    -Description 'jSON object variable' `
    -Option AllScope `
    -Force
$jsonObject = [PSCustomObject]@{}

#Initialize ArrayList variable
$tbSPmissingFeatures = New-Object -TypeName System.Collections.ArrayList
$tbSPmissingWebParts = New-Object -TypeName System.Collections.ArrayList
$tbSPmissingSetupFiles = New-Object -TypeName System.Collections.ArrayList
$tbSPmissingAssemblies = New-Object -TypeName System.Collections.ArrayList
$tbSPmissingConfigurations = New-Object -TypeName System.Collections.ArrayList
$tbSPmissingSiteDefinitions = New-Object -TypeName System.Collections.ArrayList
$tbSPmissingOrphanedSites = New-Object -TypeName System.Collections.ArrayList

class SPMissingFeaturesInfo {
    [System.String]$Database
    [System.String]$Category
    [System.String]$FeatureID
    [System.String]$Message
    [System.String]$Remedy
    [System.String]$SiteID
    [System.String]$Path
}
class SPMissingWebPartInfo {
    [System.String]$Database
    [System.String]$Category
    [System.String]$WebPartID
    [System.String]$Message
    [System.String]$Remedy
    [System.String]$ClassName
    [System.String]$StorageKey
    [System.String]$SiteID
    [System.String]$WebID
    [System.String]$ListID
    [System.String]$DirName
    [System.String]$LeafName
}
class SPMissingSetupFileInfo {
    [System.String]$Database
    [System.String]$Category
    [System.String]$Message
    [System.String]$Remedy
    [System.String]$SetupPath
    [System.String]$FileID
    [System.String]$SiteID
    [System.String]$WebID
}
class SPMissingAssemblyInfo {
    [System.String]$Database
    [System.String]$Category
    [System.String]$Message
    [System.String]$Remedy
    [System.String]$AssemblyInfo
    [System.String]$AssemblyID
    [System.String]$HostID
    [System.String]$HostType
    [System.String]$SiteID
    [System.String]$WebID
}
class SPMissingConfigurationInfo {
    [System.String]$Database
    [System.String]$Category
    [System.String]$Message
    [System.String]$Remedy
    [System.String]$SiteID
    [System.String]$Login
}
class SPMissingSiteDefinition {
    [System.String]$Database
    [System.String]$Category
    [System.String]$Message
    [System.String]$Remedy
}
class SPMissingOrphanedSites {
    [System.String]$Database
    [System.String]$Category
    [System.String]$Message
    [System.String]$Remedy
    [System.String]$SiteID
}

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

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '',
    Justification = 'Public function name kept for backward compatibility with existing callers and documentation.')]
function Get-SPSMissingServerDependencies {
    param
    (
        [Parameter()]
        [System.String]
        $Path
    )

    Write-Output '-----------------------------------------------'
    Write-Output 'Getting SharePoint Content Databases'
    try {
        $spContentDBs = Get-SPContentDatabase
        if ($null -ne $spContentDBs) {
            foreach ($spContentDB in $spContentDBs) {
                Write-Output " * Testing SharePoint Content Database $($spContentDB.Name)"
                $testDbContent = Test-SPContentDatabase $spContentDB -ShowLocation:$true -ExtendedCheck:$true
                if ($null -ne $testDbContent) {
                    $missingFeatures = $testDbContent | Where-Object -FilterScript { $_.Category -eq 'MissingFeature' }
                    $missingWebParts = $testDbContent | Where-Object -FilterScript { $_.Category -eq 'MissingWebPart' }
                    $missingSetupFiles = $testDbContent | Where-Object -FilterScript { $_.Category -eq 'MissingSetupFile' }
                    $missingAssemblies = $testDbContent | Where-Object -FilterScript { $_.Category -eq 'MissingAssembly' }
                    $missingConfigurations = $testDbContent | Where-Object -FilterScript { $_.Category -eq 'Configuration' }
                    $missingSiteDefinitions = $testDbContent | Where-Object -FilterScript { $_.Category -eq 'MissingSiteDefinition' }
                    $missingOrphanedSites = $testDbContent | Where-Object -FilterScript { $_.Category -eq 'SiteOrphan' }

                    if ($null -ne $missingFeatures) {
                        foreach ($missingFeature in $missingFeatures) {
                            $featureID = ([regex]::Matches($missingFeature.Message, '[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}')).value
                            [void]$tbSPmissingFeatures.Add([SPMissingFeaturesInfo]@{
                                    Database  = "$($spContentDB.Name)";
                                    Category  = $missingFeature.Category;
                                    FeatureID = $featureID
                                    Message   = $missingFeature.Message;
                                    Remedy    = $missingFeature.Remedy;
                                    SiteID    = $missingFeature.Locations[0].SiteId;
                                    Path      = $missingFeature.Locations[0].Path;
                                })
                        }
                    }
                    if ($null -ne $missingWebParts) {
                        foreach ($missingWebPart in $missingWebParts) {
                            $webPartID = ([regex]::Matches($missingWebPart.Message, '[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}')).value
                            $sqlMissingWebParts = Get-SQLMissingWebPartInfo -DatabaseName "$($spContentDB.Name)" `
                                -DatabaseServer "$($spContentDB.Server)" `
                                -ClassID "$($webPartID)"

                            if ($null -ne $sqlMissingWebParts -and $sqlMissingWebParts.Count -gt 0) {
                                foreach ($sqlMissingWebPart in $sqlMissingWebParts) {
                                    [void]$tbSPmissingWebParts.Add([SPMissingWebPartInfo]@{
                                            Database   = "$($spContentDB.Name)";
                                            Category   = $missingWebPart.Category;
                                            WebPartID  = $webPartID;
                                            Message    = $missingWebPart.Message;
                                            Remedy     = $missingWebPart.Remedy;
                                            ClassName  = $sqlMissingWebPart.ClassName;
                                            StorageKey = $sqlMissingWebPart.StorageKey;
                                            SiteID     = $sqlMissingWebPart.SiteID;
                                            WebID      = $sqlMissingWebPart.WebID;
                                            ListID     = $sqlMissingWebPart.ListID;
                                            DirName    = $sqlMissingWebPart.DirName;
                                            LeafName   = $sqlMissingWebPart.LeafName;
                                        })
                                }
                            }
                            else {
                                [void]$tbSPmissingWebParts.Add([SPMissingWebPartInfo]@{
                                        Database  = "$($spContentDB.Name)";
                                        Category  = $missingWebPart.Category;
                                        WebPartID = $webPartID;
                                        Message   = $missingWebPart.Message;
                                        Remedy    = $missingWebPart.Remedy;
                                    })
                            }
                        }
                    }
                    if ($null -ne $missingSetupFiles) {
                        foreach ($missingSetupFile in $missingSetupFiles) {
                            $setupPathInfo = ([regex]::Matches($missingSetupFile.Message, '(?<=\[)(\w+\\\w+.*?)(?=\])')).value
                            $sqlMissingSetupFileInfos = Get-SQLMissingSetupFileInfo -DatabaseName "$($spContentDB.Name)" `
                                -DatabaseServer "$($spContentDB.Server)" `
                                -SetupPath "$($setupPathInfo)"

                            foreach ($sqlMissingSetupFileInfo in $sqlMissingSetupFileInfos) {
                                [void]$tbSPmissingSetupFiles.Add([SPMissingSetupFileInfo]@{
                                        Database  = "$($spContentDB.Name)";
                                        Category  = $missingSetupFile.Category;
                                        Message   = $missingSetupFile.Message;
                                        Remedy    = $missingSetupFile.Remedy;
                                        SetupPath = $setupPathInfo;
                                        FileID    = $sqlMissingSetupFileInfo.FileID;
                                        SiteID    = $sqlMissingSetupFileInfo.SiteID;
                                        WebID     = $sqlMissingSetupFileInfo.WebID;
                                    })
                            }
                        }
                    }
                    if ($null -ne $missingAssemblies) {
                        foreach ($missingAssembly in $missingAssemblies) {
                            $assemblyInfo = ([regex]::Matches($missingAssembly.Message, '(?<=\[)(\w+\.\w+.*?)(?=\])')).value
                            $sqlMissingAssemblies = Get-SQLMissingAssemblyInfo -DatabaseName "$($spContentDB.Name)" `
                                -DatabaseServer "$($spContentDB.Server)" `
                                -AssemblyInfo "$($assemblyInfo)"

                            foreach ($sqlMissingAssembly in $sqlMissingAssemblies) {
                                [void]$tbSPmissingAssemblies.Add([SPMissingAssemblyInfo]@{
                                        Database     = "$($spContentDB.Name)";
                                        Category     = $missingAssembly.Category;
                                        Message      = $missingAssembly.Message;
                                        Remedy       = $missingAssembly.Remedy;
                                        AssemblyInfo = $assemblyInfo;
                                        AssemblyID   = $sqlMissingAssembly.AssemblyID;
                                        SiteID       = $sqlMissingAssembly.SiteID;
                                        WebID        = $sqlMissingAssembly.WebID;
                                        HostID       = $sqlMissingAssembly.HostID;
                                        HostType     = $sqlMissingAssembly.HostType;
                                    })
                            }
                        }
                    }
                    if ($null -ne $missingConfigurations) {
                        foreach ($missingConfiguration in $missingConfigurations) {
                            if (([regex]::Matches($missingConfiguration.Message, '^(.*?(\bclaims\b)[^$]*)$')).success) {
                                $sqlMissingConfigurations = Get-SQLMissingConfiguration -DatabaseName "$($spContentDB.Name)" `
                                    -DatabaseServer "$($spContentDB.Server)"
                            }
                            foreach ($sqlMissingConfiguration in $sqlMissingConfigurations) {
                                [void]$tbSPmissingConfigurations.Add([SPMissingConfigurationInfo]@{
                                        Database = "$($spContentDB.Name)";
                                        Category = $missingConfiguration.Category;
                                        Message  = $missingConfiguration.Message;
                                        Remedy   = $missingConfiguration.Remedy;
                                        SiteID   = $sqlMissingConfiguration.SiteID;
                                        Login    = $sqlMissingConfiguration.Login;
                                    })
                            }
                        }
                    }
                    if ($null -ne $missingSiteDefinitions) {
                        foreach ($missingSiteDefinition in $missingSiteDefinitions) {
                            [void]$tbSPmissingSiteDefinitions.Add([SPMissingSiteDefinition]@{
                                    Database = "$($spContentDB.Name)";
                                    Category = $missingSiteDefinition.Category;
                                    Message  = $missingSiteDefinition.Message;
                                    Remedy   = $missingSiteDefinition.Remedy;
                                })
                        }
                    }
                    if ($null -ne $missingOrphanedSites) {
                        foreach ($missingOrphanedSite in $missingOrphanedSites) {
                            $siteID = ([regex]::Matches($missingOrphanedSite.Message, '[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}')).value
                            [void]$tbSPmissingOrphanedSites.Add([SPMissingOrphanedSites]@{
                                    Database = "$($spContentDB.Name)";
                                    Category = $missingOrphanedSite.Category;
                                    Message  = $missingOrphanedSite.Message;
                                    Remedy   = $missingOrphanedSite.Remedy;
                                    SiteID   = $siteID;
                                })
                        }
                    }
                }
            }
            Write-Output 'Adding each list object in PsCustomObject jsonObject:'
            if ($null -ne $tbSPmissingFeatures) {
                Write-Output '* Adding MissingFeature object'
                $jsonObject | Add-Member -MemberType NoteProperty `
                    -Name MissingFeature `
                    -Value $tbSPmissingFeatures
            }
            if ($null -ne $tbSPmissingWebParts) {
                Write-Output '* Adding MissingWebPart object'
                $jsonObject | Add-Member -MemberType NoteProperty `
                    -Name MissingWebPart `
                    -Value $tbSPmissingWebParts
            }
            if ($null -ne $tbSPmissingSetupFiles) {
                Write-Output '* Adding MissingSetupFile object'
                $jsonObject | Add-Member -MemberType NoteProperty `
                    -Name MissingSetupFile `
                    -Value $tbSPmissingSetupFiles
            }
            if ($null -ne $tbSPmissingAssemblies) {
                Write-Output '* Adding MissingAssembly object'
                $jsonObject | Add-Member -MemberType NoteProperty `
                    -Name MissingAssembly `
                    -Value $tbSPmissingAssemblies
            }
            if ($null -ne $tbSPmissingConfigurations) {
                Write-Output '* Adding MissingConfiguration object'
                $jsonObject | Add-Member -MemberType NoteProperty `
                    -Name Configuration `
                    -Value $tbSPmissingConfigurations
            }
            if ($null -ne $tbSPmissingSiteDefinitions) {
                Write-Output '* Adding MissingSiteDefinitions object'
                $jsonObject | Add-Member -MemberType NoteProperty `
                    -Name MissingSiteDefinition `
                    -Value $tbSPmissingSiteDefinitions
            }
            if ($null -ne $tbSPmissingOrphanedSites) {
                Write-Output '* Adding MissingSiteOrphans object'
                $jsonObject | Add-Member -MemberType NoteProperty `
                    -Name SiteOrphan `
                    -Value $tbSPmissingOrphanedSites
            }
            $jsonObject | ConvertTo-Json | Set-Content -Path $Path -Force
        }
    }
    catch {
        return $_
    }
}

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
            Write-Output "Checking SPSite:" $site.Url
            #Remove the feature from all subsites
            ForEach ($web in $Site.AllWebs) {
                if ($web.Features[$featureID]) {
                    Write-Output "`nFound Feature $featureID in web:"$Web.Url"`nRemoving feature"
                    if ($PSCmdlet.ShouldProcess($Web.Url, "Remove feature $featureID")) {
                        $web.Features.Remove($featureID, $true)
                    }
                }
                else {
                    Write-Output "`nDid not find feature $featureID in web:" $Web.Url
                }
            }
            #Remove the feature from the site collection
            if ($Site.Features[$featureID]) {
                Write-Output "`nFound feature $featureID in site:"$site.Url"`nRemoving Feature"
                if ($PSCmdlet.ShouldProcess($site.Url, "Remove feature $featureID")) {
                    $site.Features.Remove($featureID, $true)
                }
            }
            else {
                Write-Output "Did not find feature $featureID in site:" $site.Url
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
            Write-Output "Checking SPSite:" $site.Url
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

function Remove-SPSMissingWebPart {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter()]
        [System.String]
        $Database,

        [Parameter()]
        [System.String]
        $WebPartID,

        [Parameter()]
        [System.String]
        $StorageKey,

        [Parameter()]
        [System.String]
        $SiteID,

        [Parameter()]
        [System.String]
        $WebID,

        [Parameter()]
        [System.String]
        $DirName,

        [Parameter()]
        [System.String]
        $LeafName
    )

    try {
        Write-Output '-----------------------------------------------'
        Write-Output 'Removing Missing WebPart Dependencies of:'
        Write-Output " * Database: $Database"
        Write-Output " * WebPartID (class): $WebPartID"
        Write-Output " * StorageKey: $StorageKey"
        Write-Output " * SiteID: $SiteID"
        Write-Output " * WebID: $WebID"
        Write-Output " * Page: $DirName/$LeafName"
        Write-Output '-----------------------------------------------'

        if ([string]::IsNullOrEmpty($StorageKey)) {
            Write-Output 'StorageKey is empty - no specific WebPart instance to remove. Re-run the audit to collect per-page locations.'
            return
        }

        $site = Get-SPSite -Limit All -Identity $SiteID -ErrorAction SilentlyContinue
        if ($null -ne $site) {
            $isSiteReadOnly = $site.ReadOnly
            $web = Get-SPWeb -Identity $WebID -Site $site -Limit ALL -ErrorAction SilentlyContinue
            if ($null -ne $web) {
                $webAppUrl = ($site.WebApplication.Url).TrimEnd('/')
                $pageUrl = "{0}/{1}/{2}" -f $webAppUrl, $DirName, $LeafName
                Write-Output "Page URL: $pageUrl"

                if ($isSiteReadOnly) {
                    Write-Output 'ReadOnly flag temporarily removed from site'
                    $site.ReadOnly = $false
                }

                try {
                    $spWebPartManager = $web.GetLimitedWebPartManager($pageUrl, [System.Web.UI.WebControls.WebParts.PersonalizationScope]::Shared)
                    $webPartToDelete = $spWebPartManager.WebParts | Where-Object -FilterScript { $_.StorageKey -eq $StorageKey }
                    if ($null -ne $webPartToDelete) {
                        Write-Output "Removing WebPart with StorageKey $StorageKey from page"
                        if ($PSCmdlet.ShouldProcess($pageUrl, "Delete WebPart with StorageKey $StorageKey")) {
                            $spWebPartManager.DeleteWebPart($spWebPartManager.WebParts[$webPartToDelete.Id])
                        }
                    }
                    else {
                        Write-Output "WebPart with StorageKey $StorageKey not found on page"
                    }
                }
                finally {
                    if ($isSiteReadOnly) {
                        Write-Output 'ReadOnly flag re-applied to site'
                        $site.ReadOnly = $true
                    }
                    $web.Dispose()
                }
            }
            else {
                Write-Output "WebID $WebID does not exist.`nPlease check this WebID"
            }
            $site.Dispose()
        }
        else {
            Write-Output "SiteID $SiteID does not exist.`nPlease check this SiteID"
        }
    }
    catch {
        return $_
    }
}

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
            Write-Output "Checking SPSite:" $site.Url
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

function Remove-SPSOrphanedSite {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter()]
        [System.String]
        $Database,

        [Parameter()]
        [System.String]
        $SiteID
    )

    try {
        Write-Output '-----------------------------------------------'
        Write-Output 'Removing Orphaned Site Dependencies of:'
        Write-Output " * Database: $Database"
        Write-Output " * SiteID: $SiteID"
        Write-Output '-----------------------------------------------'

        $spContentDb = Get-SPContentDatabase $Database
        if ($null -ne $spContentDb) {
            Write-Output "Removing SPSite object $SiteID with the method ForceDeleteSite"
            if ($PSCmdlet.ShouldProcess("SiteID $SiteID in database $Database", 'ForceDeleteSite')) {
                $spContentDb.ForceDeleteSite($siteID, $false, $false)
            }
        }
        else {
            Write-Output "SPContentDatabse $Database does not exist.`nPlease check this Database"
        }
    }
    catch {
        return $_
    }
}
