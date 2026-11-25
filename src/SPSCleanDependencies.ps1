<#
    .SYNOPSIS
    SPSCleanDependencies script for SharePoint Server

    .DESCRIPTION
    SPSCleanDependencies is a PowerShell script tool to clean Missing Server Dependencies in your SharePoint Farm.
    Shared logic lives in the SPSCleanDependencies.Common module (src/Modules/SPSCleanDependencies.Common);
    the script version is sourced from that module's manifest (ModuleVersion).

    .PARAMETER FileName
    Specify the name of the file to be used for the script.
    The file name can be in the format: Application-Environment-Farm
    Example: CONTOSO-PROD-SPSE
    The script will create a JSON file with the same name in the Results folder.

    .PARAMETER Clean
    Use the switch Clean parameter if you want to clean up Missing server side dependencies

    .PARAMETER HistoryRetentionDays
    Number of days of archived result snapshots to keep in the Results\history folder.
    Before each audit the current Results\<FileName>.json is copied there with a
    timestamp; snapshots older than this are pruned. Defaults to 30. Set to 0 to disable pruning.

    .PARAMETER LogRetentionDays
    Number of days of transcript log files to keep in the Logs folder. Defaults to 180.
    Set to 0 to disable pruning.

    .EXAMPLE
    SPSCleanDependencies.ps1 -FileName 'CONTOSO-PROD-SPSE'
    This command will create a JSON file in the Results folder with the name CONTOSO-PROD-SPSE.json
    The script will check for Missing server side dependencies and create a log file in the Logs folder.

    .NOTES
    FileName:	SPSCleanDependencies.ps1
    Author:		luigilink (Jean-Cyril DROUHIN)
    Date:		July 9, 2026
    Version:	Defined by the SPSCleanDependencies.Common module manifest (ModuleVersion)

    .LINK
    https://spjc.fr/
    https://github.com/luigilink/SPSCleanDependencies
#>
param(
    [Parameter(Position = 1, Mandatory = $true)]
    [System.String]
    $FileName,

    [Parameter(Position = 2)]
    [switch]
    $Clean,

    [Parameter()]
    [System.UInt32]
    $HistoryRetentionDays = 30,

    [Parameter()]
    [System.UInt32]
    $LogRetentionDays = 180
)

#requires -Version 5.1

function Get-SPSCleanupResult {
    param(
        [Parameter(Mandatory = $true)]
        [System.String]
        $Operation,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Identifier,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Status,

        [Parameter()]
        [System.String]
        $Message
    )

    return [PSCustomObject]@{
        Operation  = $Operation
        Identifier = $Identifier
        Status     = $Status
        Message    = $Message
    }
}

function Invoke-SPSOperationWithStatus {
    param(
        [Parameter(Mandatory = $true)]
        [System.String]
        $Operation,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Identifier,

        [Parameter(Mandatory = $true)]
        [ScriptBlock]
        $ScriptBlock
    )

    $operationOutput = @(& $ScriptBlock 2>&1)
    $operationErrors = New-Object -TypeName System.Collections.ArrayList

    foreach ($item in $operationOutput) {
        if ($item -is [System.Management.Automation.ErrorRecord]) {
            [void]$operationErrors.Add($item)
            continue
        }
        Write-Output $item
    }

    if ($operationErrors.Count -gt 0) {
        $errorMessage = ($operationErrors | ForEach-Object {
                if ($null -ne $_.Exception -and -not [string]::IsNullOrWhiteSpace($_.Exception.Message)) {
                    $_.Exception.Message
                }
                else {
                    $_.ToString()
                }
            }) -join ' | '

        Write-Error "[$Operation] Failed for '$Identifier'. Details: $errorMessage"
        return Get-SPSCleanupResult -Operation $Operation -Identifier $Identifier -Status 'Failed' -Message $errorMessage
    }

    return Get-SPSCleanupResult -Operation $Operation -Identifier $Identifier -Status 'Completed' -Message ''
}

function Add-SPSSkippedCleanupResult {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.ArrayList]
        $Results,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Operation,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Identifier,

        [Parameter(Mandatory = $true)]
        [System.String[]]
        $MissingFields
    )

    $missingFieldsMessage = $MissingFields -join ', '
    $message = "Skipped because required field(s) are missing: $missingFieldsMessage"
    Write-Warning "[$Operation] $Identifier - $message"
    [void]$Results.Add((Get-SPSCleanupResult -Operation $Operation -Identifier $Identifier -Status 'Skipped' -Message $message))
}

function Test-SPSHasValue {
    param(
        [Parameter()]
        [object]
        $Value
    )

    return -not [string]::IsNullOrWhiteSpace([System.String]$Value)
}

#region Initialization
# Clear the host console
Clear-Host

# Set the window title
$Host.UI.RawUI.WindowTitle = "SPSCleanDependencies script running on $env:COMPUTERNAME"

# Import the helper module (SPSCleanDependencies.Common)
$script:HelperModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'Modules'
try {
    Import-Module -Name (Join-Path -Path $script:HelperModulePath -ChildPath 'SPSCleanDependencies.Common\SPSCleanDependencies.Common.psd1') -Force -ErrorAction Stop
}
catch {
    # Handle errors during Import of helper module
    Write-Error -Message @"
Failed to import SPSCleanDependencies.Common module from path: $($script:HelperModulePath)
Exception: $_
"@
    Exit
}

# Ensure the script is running with administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    Throw "Administrator rights are required. Please re-run this script as an Administrator."
}

# Setting power management plan to High Performance
Start-Process -FilePath "$env:SystemRoot\system32\powercfg.exe" -ArgumentList '/s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' -NoNewWindow

# Load the SharePoint Server management module (Subscription Edition)
try {
    # Ensure SharePoint Server is installed on this host (throws if the ISAPI path is missing)
    $null = Get-SPSInstalledProductVersion
    # Import the SharePointServer module (idempotent)
    if ($null -eq (Get-Module -Name SharePointServer)) {
        Import-Module SharePointServer -Verbose:$false -WarningAction SilentlyContinue -DisableNameChecking
    }
}
catch {
    # Handle errors during retrieval of Installed Product Version
    Write-Error -Message @"
Failed to get installed Product Version for $($env:COMPUTERNAME)
Exception: $($_.Exception.Message)
"@
    Exit
}

# Import SQL Server PowerShell module
try {
    Import-Module -Name SqlServer -ErrorAction Stop
}
catch {
    # Handle errors during Import of helper module
    Write-Error -Message @"
Failed to import helper module SqlServer.
Please install the SqlServer module from the PowerShell Gallery or ensure it is available on this system.
Exception: $_
"@
    Exit
}

# Define variable
$SPSCleanDependenciesVersion = (Get-Module -Name 'SPSCleanDependencies.Common').Version.ToString()
$currentUser = ([Security.Principal.WindowsIdentity]::GetCurrent()).Name
$scriptRootPath = $PSScriptRoot
$pathLogsFolder = Join-Path -Path $scriptRootPath -ChildPath 'Logs' -ErrorAction SilentlyContinue
$pathResultsFolder = Join-Path -Path $scriptRootPath -ChildPath 'Results' -ErrorAction SilentlyContinue

# Initialize logs and results folders
if (-not(Test-Path $pathLogsFolder)) {
    New-Item -Path $scriptRootPath -Name 'Logs' -ItemType 'directory'
    $pathLogsFolder = Join-Path -Path $scriptRootPath -ChildPath 'Logs'
}
if (-not(Test-Path $pathResultsFolder)) {
    New-Item -Path $scriptRootPath -Name 'Results' -ItemType 'directory'
    $pathResultsFolder = Join-Path -Path $scriptRootPath -ChildPath 'Results'
}
$pathLogFile = Join-Path -Path $pathLogsFolder -ChildPath "$($FileName)_$([datetime]::Now.ToString('yyyyMMddHHmmss')).log"
$pathJsonFile = Join-Path -Path $pathResultsFolder -ChildPath ("$($FileName).json")
$pathHtmlFile = Join-Path -Path $pathResultsFolder -ChildPath ("$($FileName).html")
$pathHistoryFolder = Join-Path -Path $pathResultsFolder -ChildPath 'history'
$DateStarted = Get-date
$psVersion = ($host).Version.ToString()

# Start transcript to log the output
Start-Transcript -Path $pathLogFile -IncludeInvocationHeader

# Output the script information
Write-Output '-------------------------------------'
Write-Output "| Automated Script - SPSCleanDependencies v$SPSCleanDependenciesVersion"
Write-Output "| Started on : $DateStarted by $currentUser"
Write-Output "| PowerShell Version: $psVersion"
Write-Output '-------------------------------------'
#endregion

#region Main Process
$scriptExitCode = 0
$cleanupResults = New-Object -TypeName System.Collections.ArrayList

try {
    if ($Clean) {
        Write-Output 'Removing Missing Server Side Dependency References'
        Write-Output "Getting content of json: $pathJsonFile"
        if (Test-Path $pathJsonFile) {
            $jsonEnvCfg = Get-Content -Path $pathJsonFile -Raw -Encoding UTF8 | ConvertFrom-Json

            $missingFeatures = @($jsonEnvCfg.MissingFeature)
            if ($missingFeatures.Count -ne 0) {
                Write-Output 'Removing Missing Feature References'
                foreach ($missingFeature in $missingFeatures) {
                    $identifier = "$($missingFeature.Database)|FeatureID=$($missingFeature.FeatureID)|SiteID=$($missingFeature.SiteID)"
                    $missingFields = @()
                    if (-not (Test-SPSHasValue $missingFeature.Database)) { $missingFields += 'Database' }
                    if (-not (Test-SPSHasValue $missingFeature.FeatureID)) { $missingFields += 'FeatureID' }
                    if (-not (Test-SPSHasValue $missingFeature.SiteID)) { $missingFields += 'SiteID' }
                    if ($missingFields.Count -gt 0) {
                        Add-SPSSkippedCleanupResult -Results $cleanupResults -Operation 'MissingFeature' -Identifier $identifier -MissingFields $missingFields
                        continue
                    }

                    $result = Invoke-SPSOperationWithStatus -Operation 'MissingFeature' -Identifier $identifier -ScriptBlock {
                        Remove-SPSMissingFeature -Database $missingFeature.Database `
                            -FeatureID $missingFeature.FeatureID `
                            -SiteID $missingFeature.SiteID
                    }
                    [void]$cleanupResults.Add($result)
                }
            }

            $missingWebParts = @($jsonEnvCfg.MissingWebPart)
            if ($missingWebParts.Count -ne 0) {
                Write-Output 'Removing Missing WebPart References'
                foreach ($missingWebPart in $missingWebParts) {
                    $identifier = "$($missingWebPart.Database)|WebPartID=$($missingWebPart.WebPartID)|StorageKey=$($missingWebPart.StorageKey)"
                    $missingFields = @()
                    if (-not (Test-SPSHasValue $missingWebPart.Database)) { $missingFields += 'Database' }
                    if (-not (Test-SPSHasValue $missingWebPart.WebPartID)) { $missingFields += 'WebPartID' }
                    if (-not (Test-SPSHasValue $missingWebPart.SiteID)) { $missingFields += 'SiteID' }
                    if (-not (Test-SPSHasValue $missingWebPart.WebID)) { $missingFields += 'WebID' }
                    if (-not (Test-SPSHasValue $missingWebPart.DirName)) { $missingFields += 'DirName' }
                    if (-not (Test-SPSHasValue $missingWebPart.LeafName)) { $missingFields += 'LeafName' }
                    if ($missingFields.Count -gt 0) {
                        Add-SPSSkippedCleanupResult -Results $cleanupResults -Operation 'MissingWebPart' -Identifier $identifier -MissingFields $missingFields
                        continue
                    }

                    $result = Invoke-SPSOperationWithStatus -Operation 'MissingWebPart' -Identifier $identifier -ScriptBlock {
                        Remove-SPSMissingWebPart -Database $missingWebPart.Database `
                            -WebPartID $missingWebPart.WebPartID `
                            -StorageKey $missingWebPart.StorageKey `
                            -SiteID $missingWebPart.SiteID `
                            -WebID $missingWebPart.WebID `
                            -DirName $missingWebPart.DirName `
                            -LeafName $missingWebPart.LeafName
                    }
                    [void]$cleanupResults.Add($result)
                }
            }

            $missingSetupFiles = @($jsonEnvCfg.MissingSetupFile)
            if ($missingSetupFiles.Count -ne 0) {
                Write-Output 'Removing Missing SetupFile References'
                foreach ($missingSetupFile in $missingSetupFiles) {
                    $identifier = "$($missingSetupFile.Database)|FileID=$($missingSetupFile.FileID)|SiteID=$($missingSetupFile.SiteID)|WebID=$($missingSetupFile.WebID)"
                    $missingFields = @()
                    if (-not (Test-SPSHasValue $missingSetupFile.Database)) { $missingFields += 'Database' }
                    if (-not (Test-SPSHasValue $missingSetupFile.FileID)) { $missingFields += 'FileID' }
                    if (-not (Test-SPSHasValue $missingSetupFile.SiteID)) { $missingFields += 'SiteID' }
                    if (-not (Test-SPSHasValue $missingSetupFile.WebID)) { $missingFields += 'WebID' }
                    if ($missingFields.Count -gt 0) {
                        Add-SPSSkippedCleanupResult -Results $cleanupResults -Operation 'MissingSetupFile' -Identifier $identifier -MissingFields $missingFields
                        continue
                    }

                    $result = Invoke-SPSOperationWithStatus -Operation 'MissingSetupFile' -Identifier $identifier -ScriptBlock {
                        Remove-SPSMissingSetupFile -Database $missingSetupFile.Database `
                            -FileID $missingSetupFile.FileID `
                            -SiteID $missingSetupFile.SiteID `
                            -WebID $missingSetupFile.WebID
                    }
                    [void]$cleanupResults.Add($result)
                }
            }

            $missingAssemblies = @($jsonEnvCfg.MissingAssembly)
            if ($missingAssemblies.Count -ne 0) {
                Write-Output 'Removing Missing Assemblies References'
                foreach ($missingAssembly in $missingAssemblies) {
                    $identifier = "$($missingAssembly.Database)|AssemblyID=$($missingAssembly.AssemblyID)|HostType=$($missingAssembly.HostType)|HostID=$($missingAssembly.HostID)"
                    $missingFields = @()
                    if (-not (Test-SPSHasValue $missingAssembly.Database)) { $missingFields += 'Database' }
                    if (-not (Test-SPSHasValue $missingAssembly.AssemblyID)) { $missingFields += 'AssemblyID' }
                    if (-not (Test-SPSHasValue $missingAssembly.SiteID)) { $missingFields += 'SiteID' }
                    if (-not (Test-SPSHasValue $missingAssembly.WebID)) { $missingFields += 'WebID' }
                    if (-not (Test-SPSHasValue $missingAssembly.HostType)) { $missingFields += 'HostType' }
                    if (-not (Test-SPSHasValue $missingAssembly.HostID)) { $missingFields += 'HostID' }
                    if ($missingFields.Count -gt 0) {
                        Add-SPSSkippedCleanupResult -Results $cleanupResults -Operation 'MissingAssembly' -Identifier $identifier -MissingFields $missingFields
                        continue
                    }

                    $result = Invoke-SPSOperationWithStatus -Operation 'MissingAssembly' -Identifier $identifier -ScriptBlock {
                        Remove-SPSMissingAssembly -Database $missingAssembly.Database `
                            -AssemblyID $missingAssembly.AssemblyID `
                            -SiteID $missingAssembly.SiteID `
                            -WebID $missingAssembly.WebID `
                            -HostType $missingAssembly.HostType `
                            -HostID $missingAssembly.HostID
                    }
                    [void]$cleanupResults.Add($result)
                }
            }

            $orphanedSites = @($jsonEnvCfg.SiteOrphan)
            if ($orphanedSites.Count -ne 0) {
                Write-Output 'Removing Orphaned Site References'
                foreach ($orphanedSite in $orphanedSites) {
                    $identifier = "$($orphanedSite.Database)|SiteID=$($orphanedSite.SiteID)"
                    $missingFields = @()
                    if (-not (Test-SPSHasValue $orphanedSite.Database)) { $missingFields += 'Database' }
                    if (-not (Test-SPSHasValue $orphanedSite.SiteID)) { $missingFields += 'SiteID' }
                    if ($missingFields.Count -gt 0) {
                        Add-SPSSkippedCleanupResult -Results $cleanupResults -Operation 'SiteOrphan' -Identifier $identifier -MissingFields $missingFields
                        continue
                    }

                    $result = Invoke-SPSOperationWithStatus -Operation 'SiteOrphan' -Identifier $identifier -ScriptBlock {
                        Remove-SPSOrphanedSite -Database $orphanedSite.Database `
                            -SiteID $orphanedSite.SiteID
                    }
                    [void]$cleanupResults.Add($result)
                }
            }

            $missingConfigurations = @($jsonEnvCfg.Configuration)
            if ($missingConfigurations.Count -ne 0) {
                Write-Output 'Checking Classic Authentication Account of each SPSite object'
                $defautSPSiteOwner = (Get-SPFarm).DefaultServiceAccount.Name
                $sitesWithClassicAuth = Get-SPSite -Limit ALL | Where-Object -FilterScript { $_.Owner -notlike 'i:0#.w|*' }
                if ($null -ne $sitesWithClassicAuth) {
                    foreach ($site in $sitesWithClassicAuth) {
                        if ($site.Url -notlike '*sitemaster-*') {
                            Write-Output "Site $($site.Url) has Classic Authentication Owner: $($site.Owner)"
                            Write-Output "Updating SPSite Owner of $($site.Url)"
                            Write-Output "User $($site.Owner) replaced by $($defautSPSiteOwner)"
                            Set-SPSite $site -OwnerAlias "$($defautSPSiteOwner)" -Verbose
                        }
                    }
                }
                Write-Output 'Removing Missing Configuration References'
                foreach ($missingConfiguration in $missingConfigurations) {
                    $identifier = "$($missingConfiguration.Database)|SiteID=$($missingConfiguration.SiteID)|Login=$($missingConfiguration.Login)"
                    $missingFields = @()
                    if (-not (Test-SPSHasValue $missingConfiguration.Database)) { $missingFields += 'Database' }
                    if (-not (Test-SPSHasValue $missingConfiguration.SiteID)) { $missingFields += 'SiteID' }
                    if (-not (Test-SPSHasValue $missingConfiguration.Login)) { $missingFields += 'Login' }
                    if ($missingFields.Count -gt 0) {
                        Add-SPSSkippedCleanupResult -Results $cleanupResults -Operation 'Configuration' -Identifier $identifier -MissingFields $missingFields
                        continue
                    }

                    $result = Invoke-SPSOperationWithStatus -Operation 'Configuration' -Identifier $identifier -ScriptBlock {
                        Remove-SPSMissingConfiguration -Database $missingConfiguration.Database `
                            -SiteID $missingConfiguration.SiteID `
                            -Login $missingConfiguration.Login
                    }
                    [void]$cleanupResults.Add($result)
                }
            }
        }
        else {
            Throw "Missing $pathJsonFile`nPlease re-run this script without the switch parameter Clean"
        }
    }
    else {
        Write-Output 'Getting Missing Server Side Dependencies'

        # Archive the previous results snapshot (if any) before it is overwritten,
        # so a history of past audits is kept under Results\history.
        [void](Backup-SPSJsonFile -Path $pathJsonFile -HistoryFolder $pathHistoryFolder)

        $auditResult = Invoke-SPSOperationWithStatus -Operation 'Audit' -Identifier $pathJsonFile -ScriptBlock {
            Get-SPSMissingServerDependencies -Path $pathJsonFile
        }

        if ($auditResult.Status -eq 'Failed') {
            Throw "Audit failed for $pathJsonFile"
        }

        # Generate a self-contained HTML report from the fresh results.
        if (Test-Path $pathJsonFile) {
            Write-Output "Generating HTML report: $pathHtmlFile"
            $reportResult = Invoke-SPSOperationWithStatus -Operation 'Report' -Identifier $pathHtmlFile -ScriptBlock {
                Export-SPSCleanDependenciesReport -InputFile $pathJsonFile `
                    -OutputFile $pathHtmlFile `
                    -FarmName $FileName `
                    -Version $SPSCleanDependenciesVersion
            }

            if ($reportResult.Status -eq 'Failed') {
                Throw "Report generation failed for $pathHtmlFile"
            }
        }
        else {
            Throw "Audit did not produce expected file: $pathJsonFile"
        }

        # Prune old history snapshots and transcript logs.
        Clear-SPSLogFolder -Path $pathHistoryFolder -Retention $HistoryRetentionDays -Extension '*.json'
        Clear-SPSLogFolder -Path $pathLogsFolder -Retention $LogRetentionDays -Extension '*.log'
    }
}
catch {
    $scriptExitCode = 1
    Write-Error "SPSCleanDependencies failed: $($_.Exception.Message)"
}
finally {
    if ($Clean) {
        if ($cleanupResults.Count -gt 0) {
            Write-Output '-----------------------------------------------'
            Write-Output 'Cleanup summary by status'
            $statusGroups = $cleanupResults | Group-Object -Property Status | Sort-Object -Property Name
            foreach ($statusGroup in $statusGroups) {
                Write-Output (" * {0}: {1}" -f $statusGroup.Name, $statusGroup.Count)
            }
            Write-Output (" * Total cleanup items: {0}" -f $cleanupResults.Count)
            Write-Output '-----------------------------------------------'
        }
        else {
            Write-Output 'No cleanup entries found in the JSON file.'
        }

        if ((@($cleanupResults | Where-Object -FilterScript { $_.Status -eq 'Failed' })).Count -gt 0) {
            $scriptExitCode = 1
        }
    }

    $DateEnded = Get-Date
    Write-Output '-----------------------------------------------'
    Write-Output "| SPSCleanDependencies Script Completed"
    Write-Output "| Started on  - $DateStarted"
    Write-Output "| Ended on    - $DateEnded"
    Write-Output "| Exit code   - $scriptExitCode"
    Write-Output '-----------------------------------------------'

    try {
        Stop-Transcript | Out-Null
    }
    catch {
        Write-Verbose 'Transcript was not active or could not be stopped.'
    }

    Remove-Module -Name 'SPSCleanDependencies.Common' -ErrorAction SilentlyContinue
    Exit $scriptExitCode
}
#endregion
