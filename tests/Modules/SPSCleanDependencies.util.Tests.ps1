# Pester tests for SPSCleanDependencies.util.psm1
# Resolve repo root - works on both local and CI/CD

BeforeAll {
    $repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:modulePath = Join-Path -Path $repoRoot -ChildPath 'scripts/Modules/SPSCleanDependencies.util.psm1'

    # Skip the module's import-time prelude (admin check, powercfg, SharePoint snap-in load),
    # which only makes sense on a real SharePoint farm.
    $script:previousSkipPrelude = $env:SPSCD_SKIP_PRELUDE
    $env:SPSCD_SKIP_PRELUDE = '1'

    # Stub SharePoint cmdlets so the module can be imported on non-Windows / no-SharePoint hosts.
    # Real behaviour is exercised on a SharePoint farm; these tests only validate shape & contracts.
    $spsStubs = @(
        'Get-SPContentDatabase', 'Get-SPSite', 'Get-SPWeb', 'Get-SPFarm', 'Set-SPSite',
        'Test-SPContentDatabase', 'Install-SPFeature', 'Uninstall-SPFeature',
        'Disable-SPFeature', 'Invoke-Sqlcmd', 'Add-PSSnapin', 'Get-PSSnapin'
    )
    foreach ($name in $spsStubs) {
        if (-not (Get-Command -Name $name -ErrorAction SilentlyContinue)) {
            $sb = [ScriptBlock]::Create("function global:$name { param() }")
            & $sb
        }
    }

    # Surface real import errors instead of silently hiding them (which previously
    # produced a cascade of misleading "$null or empty" failures).
    Import-Module -Name $script:modulePath -Force -DisableNameChecking
}

AfterAll {
    Remove-Module -Name 'SPSCleanDependencies.util' -Force -ErrorAction SilentlyContinue
    $env:SPSCD_SKIP_PRELUDE = $script:previousSkipPrelude
}

Describe 'SPSCleanDependencies.util.psm1 Module' {

    It 'module file exists' {
        $script:modulePath | Should -Exist
    }

    It 'has valid PowerShell syntax' {
        $parseErrors = $null
        $tokens = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput(
            (Get-Content -Path $script:modulePath -Raw), [ref]$tokens, [ref]$parseErrors)
        $parseErrors | Should -BeNullOrEmpty
    }

    It 'module loads successfully' {
        Get-Module -Name 'SPSCleanDependencies.util' | Should -Not -BeNullOrEmpty
    }
}

Describe 'SPSCleanDependencies.util.psm1 Public Functions' {

    $publicFunctions = @(
        'Get-SPSMissingServerDependencies',
        'Remove-SPSMissingFeature',
        'Remove-SPSMissingSetupFile',
        'Remove-SPSMissingAssembly',
        'Remove-SPSMissingConfiguration',
        'Remove-SPSMissingWebPart',
        'Remove-SPSOrphanedSite'
    )

    It 'exports <_>' -ForEach $publicFunctions {
        Get-Command -Name $_ -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }
}

Describe 'SPSCleanDependencies.util.psm1 SQL Helper Functions' {

    $sqlHelpers = @(
        'Get-SQLMissingSetupFileInfo',
        'Get-SQLMissingAssemblyInfo',
        'Get-SQLMissingWebPartInfo',
        'Get-SQLMissingConfiguration'
    )

    It 'defines helper <_>' -ForEach $sqlHelpers {
        Get-Command -Name $_ -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }
}

Describe 'SPSCleanDependencies.util.psm1 Function Parameter Contracts' {

    It 'Get-SPSMissingServerDependencies has a Path parameter' {
        (Get-Command Get-SPSMissingServerDependencies).Parameters.Keys | Should -Contain 'Path'
    }

    It 'Remove-SPSMissingFeature exposes Database, FeatureID, SiteID' {
        $params = (Get-Command Remove-SPSMissingFeature).Parameters.Keys
        $params | Should -Contain 'Database'
        $params | Should -Contain 'FeatureID'
        $params | Should -Contain 'SiteID'
    }

    It 'Remove-SPSMissingSetupFile exposes Database, FileID, SiteID, WebID' {
        $params = (Get-Command Remove-SPSMissingSetupFile).Parameters.Keys
        $params | Should -Contain 'Database'
        $params | Should -Contain 'FileID'
        $params | Should -Contain 'SiteID'
        $params | Should -Contain 'WebID'
    }

    It 'Remove-SPSMissingAssembly exposes the full HostType contract' {
        $params = (Get-Command Remove-SPSMissingAssembly).Parameters.Keys
        $params | Should -Contain 'Database'
        $params | Should -Contain 'AssemblyID'
        $params | Should -Contain 'SiteID'
        $params | Should -Contain 'WebID'
        $params | Should -Contain 'HostType'
        $params | Should -Contain 'HostID'
    }

    It 'Remove-SPSMissingConfiguration exposes Database, SiteID, Login' {
        $params = (Get-Command Remove-SPSMissingConfiguration).Parameters.Keys
        $params | Should -Contain 'Database'
        $params | Should -Contain 'SiteID'
        $params | Should -Contain 'Login'
    }

    It 'Remove-SPSMissingWebPart exposes the per-page location contract' {
        $params = (Get-Command Remove-SPSMissingWebPart).Parameters.Keys
        $params | Should -Contain 'Database'
        $params | Should -Contain 'WebPartID'
        $params | Should -Contain 'StorageKey'
        $params | Should -Contain 'SiteID'
        $params | Should -Contain 'WebID'
        $params | Should -Contain 'DirName'
        $params | Should -Contain 'LeafName'
    }

    It 'Remove-SPSOrphanedSite exposes Database and SiteID' {
        $params = (Get-Command Remove-SPSOrphanedSite).Parameters.Keys
        $params | Should -Contain 'Database'
        $params | Should -Contain 'SiteID'
    }
}

Describe 'Remove-SPSMissingWebPart Safety Net' {

    It 'returns early (no throw) when StorageKey is empty' {
        { Remove-SPSMissingWebPart `
            -Database 'WSS_Content_Test' `
            -WebPartID '00000000-0000-0000-0000-000000000000' `
            -StorageKey '' `
            -SiteID '11111111-1111-1111-1111-111111111111' `
            -WebID '22222222-2222-2222-2222-222222222222' `
            -DirName 'SitePages' `
            -LeafName 'Home.aspx' } | Should -Not -Throw
    }
}

Describe 'SPSCleanDependencies.util.psm1 Class Definitions' {

    BeforeAll {
        $script:moduleContent = Get-Content -Path $script:modulePath -Raw
    }

    $expectedClasses = @(
        'SPMissingFeaturesInfo',
        'SPMissingWebPartInfo',
        'SPMissingSetupFileInfo',
        'SPMissingAssemblyInfo',
        'SPMissingConfigurationInfo',
        'SPMissingSiteDefinition',
        'SPMissingOrphanedSites'
    )

    It 'defines class <_>' -ForEach $expectedClasses {
        $script:moduleContent | Should -Match "class\s+$_\b"
    }

    It 'SPMissingWebPartInfo class carries per-page location fields' {
        $script:moduleContent | Should -Match 'class\s+SPMissingWebPartInfo[\s\S]*\$StorageKey[\s\S]*\$DirName[\s\S]*\$LeafName'
    }
}
