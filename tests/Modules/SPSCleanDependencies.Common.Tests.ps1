# Pester tests for the SPSCleanDependencies.Common module.
# Resolve repo root - works on both local and CI/CD.

BeforeAll {
    $repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:moduleRoot = Join-Path -Path $repoRoot -ChildPath 'src/Modules/SPSCleanDependencies.Common'
    $script:moduleManifest = Join-Path -Path $script:moduleRoot -ChildPath 'SPSCleanDependencies.Common.psd1'
    $script:moduleFile = Join-Path -Path $script:moduleRoot -ChildPath 'SPSCleanDependencies.Common.psm1'
    $script:moduleName = 'SPSCleanDependencies.Common'
    $script:dependenciesFunctionFile = Join-Path -Path $script:moduleRoot -ChildPath 'Public/Get-SPSMissingServerDependencies.ps1'

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

    # The module is import-safe by design (the admin/powercfg/snap-in prelude now lives in the
    # entry script, not the module). Surface real import errors instead of hiding them.
    Import-Module -Name $script:moduleManifest -Force -DisableNameChecking
}

AfterAll {
    Remove-Module -Name 'SPSCleanDependencies.Common' -Force -ErrorAction SilentlyContinue
}

Describe 'SPSCleanDependencies.Common Module' {

    It 'module manifest exists' {
        $script:moduleManifest | Should -Exist
    }

    It 'loader module file exists' {
        $script:moduleFile | Should -Exist
    }

    It 'loader has valid PowerShell syntax' {
        $parseErrors = $null
        $tokens = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput(
            (Get-Content -Path $script:moduleFile -Raw), [ref]$tokens, [ref]$parseErrors)
        $parseErrors | Should -BeNullOrEmpty
    }

    It 'manifest declares a ModuleVersion' {
        (Test-ModuleManifest -Path $script:moduleManifest).Version | Should -Not -BeNullOrEmpty
    }

    It 'module loads successfully' {
        Get-Module -Name $script:moduleName | Should -Not -BeNullOrEmpty
    }
}

Describe 'SPSCleanDependencies.Common Public Functions' {

    $publicFunctions = @(
        'Backup-SPSJsonFile',
        'Clear-SPSLogFolder',
        'Export-SPSCleanDependenciesReport',
        'Get-SPSInstalledProductVersion',
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

    It 'manifest FunctionsToExport matches the exported set' {
        $expectedExports = @(
            'Backup-SPSJsonFile',
            'Clear-SPSLogFolder',
            'Export-SPSCleanDependenciesReport',
            'Get-SPSInstalledProductVersion',
            'Get-SPSMissingServerDependencies',
            'Remove-SPSMissingFeature',
            'Remove-SPSMissingSetupFile',
            'Remove-SPSMissingAssembly',
            'Remove-SPSMissingConfiguration',
            'Remove-SPSMissingWebPart',
            'Remove-SPSOrphanedSite'
        ) | Sort-Object
        $exported = (Get-Module -Name $script:moduleName).ExportedFunctions.Keys | Sort-Object
        $exported | Should -Be $expectedExports
    }
}

Describe 'SPSCleanDependencies.Common Private SQL Helpers' {

    $sqlHelpers = @(
        'Get-SQLMissingSetupFileInfo',
        'Get-SQLMissingAssemblyInfo',
        'Get-SQLMissingWebPartInfo',
        'Get-SQLMissingConfiguration'
    )

    It 'defines internal helper <_> (module scope)' -ForEach $sqlHelpers {
        $helper = $_
        InModuleScope -ModuleName 'SPSCleanDependencies.Common' -Parameters @{ helper = $helper } {
            param($helper)
            Get-Command -Name $helper -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    It 'does not export the SQL helpers to callers <_>' -ForEach $sqlHelpers {
        (Get-Module -Name $script:moduleName).ExportedFunctions.Keys | Should -Not -Contain $_
    }
}

Describe 'SPSCleanDependencies.Common Private HTML Report Helpers' {

    $htmlHelpers = @(
        'ConvertTo-SPSHtmlEncoded',
        'Get-SPSReportHtmlHead',
        'Get-SPSReportCardHtml',
        'Get-SPSReportHtmlScript'
    )

    It 'defines internal helper <_> (module scope)' -ForEach $htmlHelpers {
        $helper = $_
        InModuleScope -ModuleName 'SPSCleanDependencies.Common' -Parameters @{ helper = $helper } {
            param($helper)
            Get-Command -Name $helper -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    It 'does not export the HTML helpers to callers <_>' -ForEach $htmlHelpers {
        (Get-Module -Name $script:moduleName).ExportedFunctions.Keys | Should -Not -Contain $_
    }

    It 'ConvertTo-SPSHtmlEncoded escapes HTML metacharacters' {
        InModuleScope -ModuleName 'SPSCleanDependencies.Common' {
            ConvertTo-SPSHtmlEncoded -Value 'a<b>&"x''y' | Should -Be 'a&lt;b&gt;&amp;&quot;x&#39;y'
        }
    }
}

Describe 'Backup-SPSJsonFile' {

    BeforeEach {
        $script:tempRoot = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString('N'))
        $null = New-Item -Path $script:tempRoot -ItemType Directory -Force
        $script:jsonPath = Join-Path -Path $script:tempRoot -ChildPath 'CONTOSO-PROD-SPSE.json'
        $script:historyFolder = Join-Path -Path $script:tempRoot -ChildPath 'history'
    }

    It 'returns $null and creates nothing when the source does not exist' {
        $result = Backup-SPSJsonFile -Path $script:jsonPath -HistoryFolder $script:historyFolder
        $result | Should -BeNullOrEmpty
        Test-Path $script:historyFolder | Should -BeFalse
    }

    It 'archives an existing file with a timestamped name and leaves the original in place' {
        '{}' | Set-Content -Path $script:jsonPath
        $result = Backup-SPSJsonFile -Path $script:jsonPath -HistoryFolder $script:historyFolder -TimeStamp '20260709-1615'
        $result | Should -Not -BeNullOrEmpty
        Split-Path $result -Leaf | Should -Be 'CONTOSO-PROD-SPSE-20260709-1615.json'
        Test-Path $result | Should -BeTrue
        Test-Path $script:jsonPath | Should -BeTrue
    }
}

Describe 'Clear-SPSLogFolder' {

    BeforeEach {
        $script:folder = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString('N'))
        $null = New-Item -Path $script:folder -ItemType Directory -Force
        $script:oldFile = Join-Path -Path $script:folder -ChildPath 'old.json'
        $script:newFile = Join-Path -Path $script:folder -ChildPath 'new.json'
        '{}' | Set-Content -Path $script:oldFile
        '{}' | Set-Content -Path $script:newFile
        (Get-Item $script:oldFile).LastWriteTime = (Get-Date).AddDays(-40)
    }

    It 'declares SupportsShouldProcess' {
        $params = (Get-Command Clear-SPSLogFolder).Parameters.Keys
        $params | Should -Contain 'WhatIf'
        $params | Should -Contain 'Confirm'
    }

    It 'removes files older than the retention window and keeps recent ones' {
        Clear-SPSLogFolder -Path $script:folder -Retention 30 -Extension '*.json' | Out-Null
        Test-Path $script:oldFile | Should -BeFalse
        Test-Path $script:newFile | Should -BeTrue
    }

    It 'does nothing when Retention is 0' {
        Clear-SPSLogFolder -Path $script:folder -Retention 0 -Extension '*.json' | Out-Null
        Test-Path $script:oldFile | Should -BeTrue
        Test-Path $script:newFile | Should -BeTrue
    }
}

Describe 'Export-SPSCleanDependenciesReport' {

    BeforeEach {
        $script:reportRoot = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString('N'))
        $null = New-Item -Path $script:reportRoot -ItemType Directory -Force
        $script:inJson = Join-Path -Path $script:reportRoot -ChildPath 'in.json'
        $script:outHtml = Join-Path -Path $script:reportRoot -ChildPath 'out.html'
    }

    It 'renders a self-contained report with a section per non-empty category' {
        $sample = [ordered]@{
            MissingFeature = @(@{ Database = 'WSS'; FeatureID = 'f1'; SiteID = 's1'; Path = '/a' })
            SiteOrphan     = @(@{ Database = 'WSS'; SiteID = 's2' })
        }
        $sample | ConvertTo-Json -Depth 6 | Set-Content -Path $script:inJson -Encoding UTF8

        $out = Export-SPSCleanDependenciesReport -InputFile $script:inJson -OutputFile $script:outHtml -FarmName 'CONTOSO-PROD-SPSE'
        $out | Should -Be $script:outHtml
        Test-Path $script:outHtml | Should -BeTrue

        $html = Get-Content -Path $script:outHtml -Raw
        $html | Should -Match '^\ufeff?<!DOCTYPE html>'
        $html.TrimEnd() | Should -Match '</html>$'
        $html | Should -Match 'thead-MissingFeature'
        $html | Should -Match 'thead-SiteOrphan'
        $html | Should -Match 'Total items'
    }

    It 'HTML-encodes values coming from the results (no raw markup leaks)' {
        $sample = [ordered]@{
            MissingWebPart = @(@{ Database = 'WSS'; WebPartID = 'wp'; ClassName = 'Contoso.WP<script>'; StorageKey = 'k'; SiteID = 's'; WebID = 'w'; ListID = 'l'; DirName = 'd'; LeafName = 'p.aspx' })
        }
        $sample | ConvertTo-Json -Depth 6 | Set-Content -Path $script:inJson -Encoding UTF8
        [void](Export-SPSCleanDependenciesReport -InputFile $script:inJson -OutputFile $script:outHtml)
        $html = Get-Content -Path $script:outHtml -Raw
        $html | Should -Not -Match 'Contoso\.WP<script>'
    }

    It 'renders a clean "nothing to clean" state when the results are empty' {
        '{}' | Set-Content -Path $script:inJson
        [void](Export-SPSCleanDependenciesReport -InputFile $script:inJson -OutputFile $script:outHtml)
        (Get-Content -Path $script:outHtml -Raw) | Should -Match 'No missing server side dependencies'
    }

    It 'throws when the input file is missing' {
        { Export-SPSCleanDependenciesReport -InputFile (Join-Path $script:reportRoot 'nope.json') -OutputFile $script:outHtml } |
            Should -Throw
    }
}

Describe 'SPSCleanDependencies.Common Function Parameter Contracts' {

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

Describe 'SPSCleanDependencies.Common ShouldProcess Support' {

    $stateChangingFunctions = @(
        'Remove-SPSMissingFeature',
        'Remove-SPSMissingSetupFile',
        'Remove-SPSMissingWebPart',
        'Remove-SPSMissingAssembly',
        'Remove-SPSMissingConfiguration',
        'Remove-SPSOrphanedSite'
    )

    It '<_> declares SupportsShouldProcess' -ForEach $stateChangingFunctions {
        $cmd = Get-Command -Name $_ -ErrorAction Stop
        # CmdletBinding(SupportsShouldProcess) injects -WhatIf and -Confirm into the function.
        $cmd.Parameters.Keys | Should -Contain 'WhatIf'
        $cmd.Parameters.Keys | Should -Contain 'Confirm'
    }
}

Describe 'SPSCleanDependencies.Common Class Definitions' {

    BeforeAll {
        $script:functionContent = Get-Content -Path $script:dependenciesFunctionFile -Raw
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

    It 'defines class <_> in Get-SPSMissingServerDependencies.ps1' -ForEach $expectedClasses {
        $script:functionContent | Should -Match "class\s+$_\b"
    }

    It 'SPMissingWebPartInfo class carries per-page location fields' {
        $script:functionContent | Should -Match 'class\s+SPMissingWebPartInfo[\s\S]*\$StorageKey[\s\S]*\$DirName[\s\S]*\$LeafName'
    }
}
