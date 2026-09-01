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

function Get-SPSMissingServerDependencies {
    param
    (
        [Parameter()]
        [System.String]
        $Path
    )

    # Initialize the jSON object and the per-category collections that will be
    # serialized to $Path once every content database has been inspected.
    $jsonObject = [PSCustomObject]@{}
    $tbSPmissingFeatures = New-Object -TypeName System.Collections.ArrayList
    $tbSPmissingWebParts = New-Object -TypeName System.Collections.ArrayList
    $tbSPmissingSetupFiles = New-Object -TypeName System.Collections.ArrayList
    $tbSPmissingAssemblies = New-Object -TypeName System.Collections.ArrayList
    $tbSPmissingConfigurations = New-Object -TypeName System.Collections.ArrayList
    $tbSPmissingSiteDefinitions = New-Object -TypeName System.Collections.ArrayList
    $tbSPmissingOrphanedSites = New-Object -TypeName System.Collections.ArrayList

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
