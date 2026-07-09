@{
    RootModule        = 'SPSCleanDependencies.Common.psm1'
    ModuleVersion     = '1.4.0'
    GUID              = 'aa259ca2-c421-487d-80ec-b7d7b440c584'
    Author            = 'Jean-Cyril DROUHIN'
    CompanyName       = 'luigilink'
    Copyright         = '(c) Jean-Cyril DROUHIN. All rights reserved.'
    Description       = 'Shared functions for the SPSCleanDependencies toolkit (audit and clean Missing Server Side Dependencies in a SharePoint Server farm: missing features, web parts, setup files, assemblies, configurations and orphaned sites).'

    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Backup-SPSJsonFile'
        'Clear-SPSLogFolder'
        'Export-SPSCleanDependenciesReport'
        'Get-SPSInstalledProductVersion'
        'Get-SPSMissingServerDependencies'
        'Remove-SPSMissingAssembly'
        'Remove-SPSMissingConfiguration'
        'Remove-SPSMissingFeature'
        'Remove-SPSMissingSetupFile'
        'Remove-SPSMissingWebPart'
        'Remove-SPSOrphanedSite'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('SharePoint', 'SharePointServer', 'MissingDependencies', 'ContentDatabase', 'Cleanup')
            LicenseUri   = 'https://github.com/luigilink/SPSCleanDependencies/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/luigilink/SPSCleanDependencies'
            ReleaseNotes = 'https://github.com/luigilink/SPSCleanDependencies/blob/main/RELEASE-NOTES.md'
        }
    }
}
