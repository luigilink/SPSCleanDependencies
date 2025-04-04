<#
    .SYNOPSIS
    SPSCleanDependencies script for SharePoint Server

    .DESCRIPTION
    SPSCleanDependencies is a PowerShell script tool to clean Missing Server Dependencies in your SharePoint Farm

    .PARAMETER FileName
    Specify the name of the file to be used for the script.
    The file name can be in the format: Application-Environment-Farm
    Example: CONTOSO-PROD-SP2019
    The script will create a JSON file with the same name in the Results folder.

    .PARAMETER Clean
    Use the switch Clean parameter if you want to clean up Missing server side dependencies

    .EXAMPLE
    SPSCleanDependencies.ps1 -FileName 'CONTOSO-PROD-SP2019'
    This command will create a JSON file in the Results folder with the name CONTOSO-PROD-SP2019.json
    The script will check for Missing server side dependencies and create a log file in the Logs folder.

    .NOTES
    FileName:	SPSCleanDependencies.ps1
    Author:		luigilink (Jean-Cyril DROUHIN)
    Date:		April 04, 2025
    Version:	1.0.0

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
    $Clean
)

#region Initialization
# Clear the host console
Clear-Host

# Set the window title
$Host.UI.RawUI.WindowTitle = "SPSTrust script running on $env:COMPUTERNAME"

# Define the path to the helper module
$scriptRootPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$script:HelperModulePath = Join-Path -Path $scriptRootPath -ChildPath 'Modules'

# Import the helper module
Import-Module -Name (Join-Path -Path $script:HelperModulePath -ChildPath 'SPSCleanDependencies.util.psm1') -Force -DisableNameChecking

# Define variable
$SPSCleanDependenciesVersion = '1.0.0'
$currentUser = ([Security.Principal.WindowsIdentity]::GetCurrent()).Name
$scriptRootPath = Split-Path -parent $MyInvocation.MyCommand.Definition
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
if ($Clean) {
    Write-Output 'Removing Missing Server Side Dependency References'
    Write-Output "Getting content of json: $pathJsonFile"
    if (Test-Path $pathJsonFile) {
        $jsonEnvCfg = get-content $pathJsonFile | ConvertFrom-Json
        if (($jsonEnvCfg.MissingFeature).Count -ne 0) {
            Write-Output 'Removing Missing Feature References'
            foreach ($missingFeature in $jsonEnvCfg.MissingFeature) {
                Remove-SPSMissingFeature -Database $missingFeature.Database `
                    -FeatureID $missingFeature.FeatureID `
                    -SiteID $missingFeature.SiteId
            }
        }
        if (($jsonEnvCfg.MissingWebPart).Count -ne 0) {
            Write-Output 'Removing Missing WebPart References'
        }
        if (($jsonEnvCfg.MissingSetupFile).Count -ne 0) {
            Write-Output 'Removing Missing SetupFile References'
            foreach ($missingSetupFile in $jsonEnvCfg.MissingSetupFile) {
                Remove-SPSMissingSetupFile -Database $missingSetupFile.Database `
                    -FileID $missingSetupFile.FileID `
                    -SiteID $missingSetupFile.SiteId `
                    -WebID $missingSetupFile.WebID
            }
        }
        if (($jsonEnvCfg.MissingAssembly).Count -ne 0) {
            Write-Output 'Removing Missing Assemblies References'
            foreach ($missingAssembly in $jsonEnvCfg.MissingAssembly) {
                Remove-SPSMissingAssembly -Database $missingAssembly.Database `
                    -AssemblyID $missingAssembly.AssemblyID `
                    -SiteID $missingAssembly.SiteId `
                    -WebID $missingAssembly.WebID `
                    -HostType $missingAssembly.HostType `
                    -HostID $missingAssembly.HostID
            }
        }
        if (($jsonEnvCfg.Configuration).Count -ne 0) {
            Write-Output 'Checking Classic Authentication Account of each SPSite object'
            $defautSPSiteOwner = (Get-SPFarm).DefaultServiceAccount.Name
            $sitesWithClassicAuth = Get-SPSite -Limit ALL | Where-Object -FilterScript { $_.Owner -notlike 'i:0#.w|*' }
            if ($null -ne $sitesWithClassicAuth) {
                foreach ($site in $sitesWithClassicAuth) {
                    Write-Output "Updating SPSite Owner of $($site.Url)"
                    Write-Output "User $($site.Owner) replaced by $($defautSPSiteOwner)"
                    Set-SPSite $site -OwnerAlias "$($defautSPSiteOwner)" -Verbose
                }
            }
            Write-Output 'Removing Missing Configuration References'
            foreach ($missingConfiguration in $jsonEnvCfg.Configuration) {
                Remove-SPSMissingConfiguration -Database $missingConfiguration.Database `
                    -SiteID $missingConfiguration.SiteId `
                    -Login $missingConfiguration.Login
            }
        }
    }
    else {
        Throw "Missing $pathJsonFile`nPlease re-run this script without the switch parameter Clean"
    }
}
else {
    Write-Output 'Getting Missing Server Side Dependencies'    
    Get-SPSMissingServerDependencies -Path $pathJsonFile
}
#endregion

# Clean-Up
Trap { Continue }
$DateEnded = Get-Date
Write-Output '-----------------------------------------------'
Write-Output "| SPSTrust Script Completed"
Write-Output "| Started on  - $DateStarted"
Write-Output "| Ended on    - $DateEnded"
Write-Output '-----------------------------------------------'
Stop-Transcript
Remove-Variable * -ErrorAction SilentlyContinue
Remove-Module * -ErrorAction SilentlyContinue
$error.Clear()
Exit
