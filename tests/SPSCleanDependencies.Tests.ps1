# Pester tests for SPSCleanDependencies.ps1
# Resolve repo root - works on CI/CD (GitHub Actions) and local runs

BeforeAll {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    $script:scriptPath = Join-Path -Path $repoRoot -ChildPath 'scripts/SPSCleanDependencies.ps1'
    $script:scriptContent = Get-Content -Path $script:scriptPath -Raw -ErrorAction SilentlyContinue
}

Describe 'SPSCleanDependencies.ps1 File Existence' {

    It 'SPSCleanDependencies.ps1 exists' {
        $script:scriptPath | Should -Exist
    }

    It 'is a PowerShell script file' {
        (Get-Item $script:scriptPath).Extension | Should -Be '.ps1'
    }

    It 'has valid PowerShell syntax' {
        $parseErrors = $null
        $tokens = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput(
            $script:scriptContent, [ref]$tokens, [ref]$parseErrors)
        $parseErrors | Should -BeNullOrEmpty
    }
}

Describe 'SPSCleanDependencies.ps1 Metadata' {

    It 'Should contain a SYNOPSIS' {
        $script:scriptContent | Should -Match '\.SYNOPSIS'
    }

    It 'Should contain a DESCRIPTION' {
        $script:scriptContent | Should -Match '\.DESCRIPTION'
    }

    It 'Should contain an EXAMPLE' {
        $script:scriptContent | Should -Match '\.EXAMPLE'
    }

    It 'Should declare an Author in NOTES' {
        $script:scriptContent | Should -Match 'Author:\s*luigilink'
    }

    It 'Should declare a Version in NOTES' {
        $script:scriptContent | Should -Match 'Version:\s*\d+\.\d+\.\d+'
    }

    It 'Should require PowerShell 5.1 or higher' {
        $script:scriptContent | Should -Match '#requires\s+-Version\s+5\.1'
    }
}

Describe 'SPSCleanDependencies.ps1 Parameters' {

    BeforeAll {
        $ast = [System.Management.Automation.Language.Parser]::ParseInput(
            $script:scriptContent, [ref]$null, [ref]$null)
        $script:paramBlock = $ast.ParamBlock
    }

    It 'Should define a param block' {
        $script:paramBlock | Should -Not -BeNullOrEmpty
    }

    It 'Should expose a mandatory FileName parameter' {
        $fileNameParam = $script:paramBlock.Parameters | Where-Object {
            $_.Name.VariablePath.UserPath -eq 'FileName'
        }
        $fileNameParam | Should -Not -BeNullOrEmpty

        $mandatoryAttr = $fileNameParam.Attributes | Where-Object {
            $_ -is [System.Management.Automation.Language.AttributeAst] -and
            $_.TypeName.Name -eq 'Parameter'
        }
        $mandatoryArg = $mandatoryAttr.NamedArguments |
            Where-Object { $_.ArgumentName -eq 'Mandatory' }
        $mandatoryArg | Should -Not -BeNullOrEmpty
    }

    It 'Should type FileName as System.String' {
        $fileNameParam = $script:paramBlock.Parameters | Where-Object {
            $_.Name.VariablePath.UserPath -eq 'FileName'
        }
        $typeAttr = $fileNameParam.Attributes | Where-Object {
            $_ -is [System.Management.Automation.Language.TypeConstraintAst]
        }
        $typeAttr.TypeName.FullName | Should -Be 'System.String'
    }

    It 'Should expose a Clean switch parameter' {
        $cleanParam = $script:paramBlock.Parameters | Where-Object {
            $_.Name.VariablePath.UserPath -eq 'Clean'
        }
        $cleanParam | Should -Not -BeNullOrEmpty

        $typeAttr = $cleanParam.Attributes | Where-Object {
            $_ -is [System.Management.Automation.Language.TypeConstraintAst]
        }
        $typeAttr.TypeName.FullName | Should -Be 'switch'
    }

    It 'Should have exactly two parameters' {
        $script:paramBlock.Parameters.Count | Should -Be 2
    }
}

Describe 'SPSCleanDependencies.ps1 Module Imports' {

    It 'Should import the helper module SPSCleanDependencies.util.psm1' {
        $script:scriptContent | Should -Match 'Import-Module[^\n]*SPSCleanDependencies\.util\.psm1'
    }

    It 'Should import the SqlServer module' {
        $script:scriptContent | Should -Match 'Import-Module\s+-Name\s+SqlServer'
    }
}

Describe 'SPSCleanDependencies.ps1 Logs/Results Bootstrapping' {

    It 'Should create the Logs folder if it does not exist' {
        $script:scriptContent | Should -Match "New-Item[^\n]+-Name\s+'Logs'"
    }

    It 'Should create the Results folder if it does not exist' {
        $script:scriptContent | Should -Match "New-Item[^\n]+-Name\s+'Results'"
    }

    It 'Should start a transcript' {
        $script:scriptContent | Should -Match 'Start-Transcript\s+-Path\s+\$pathLogFile'
    }

    It 'Should stop the transcript at the end' {
        $script:scriptContent | Should -Match 'Stop-Transcript'
    }
}

Describe 'SPSCleanDependencies.ps1 Clean Branch' {

    It 'Should call Get-SPSMissingServerDependencies when -Clean is not specified' {
        $script:scriptContent | Should -Match 'Get-SPSMissingServerDependencies\s+-Path\s+\$pathJsonFile'
    }

    It 'Should read the JSON results file with Test-Path / ConvertFrom-Json' {
        $script:scriptContent | Should -Match 'Test-Path\s+\$pathJsonFile'
        $script:scriptContent | Should -Match 'ConvertFrom-Json'
    }

    It 'Should call Remove-SPSMissingFeature in the Clean branch' {
        $script:scriptContent | Should -Match 'Remove-SPSMissingFeature\s+-Database'
    }

    It 'Should call Remove-SPSMissingSetupFile in the Clean branch' {
        $script:scriptContent | Should -Match 'Remove-SPSMissingSetupFile\s+-Database'
    }

    It 'Should call Remove-SPSMissingAssembly in the Clean branch' {
        $script:scriptContent | Should -Match 'Remove-SPSMissingAssembly\s+-Database'
    }

    It 'Should call Remove-SPSMissingConfiguration in the Clean branch' {
        $script:scriptContent | Should -Match 'Remove-SPSMissingConfiguration\s+-Database'
    }

    It 'Should call Remove-SPSMissingWebPart in the Clean branch' {
        $script:scriptContent | Should -Match 'Remove-SPSMissingWebPart\s+-Database'
    }

    It 'Should call Remove-SPSOrphanedSite in the Clean branch' {
        $script:scriptContent | Should -Match 'Remove-SPSOrphanedSite\s+-Database'
    }

    It 'Should throw when the JSON results file is missing' {
        $script:scriptContent | Should -Match 'Throw\s+"Missing\s+\$pathJsonFile'
    }
}
