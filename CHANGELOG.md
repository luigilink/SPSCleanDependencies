# Change log for SPSCleanDependencies

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-10-21

### Changed

- SPSCleanDependencies.ps1:
  - Resolve Invoke-Sqlcmd does not work because sqlserver is not present [issue #2](https://github.com/luigilink/SPSCleanDependencies/issues/2)
  - Resolve Performing the operation "Set-SPSite" on target "*sitemaster-*" [issue #3](https://github.com/luigilink/SPSCleanDependencies/issues/3)

- Wiki Documentation in repository - Update :
  - wiki/Home.md
  - wiki/Getting-Started.md
  - wiki/Usage.md

- Issue Templates files:
  - 1_bug_report.yml Update version

- README.md
  - Add Requirements for PowerShell 5 and SqlServer PowerShell Module

## [1.0.0] - 2025-04-04

### Added

- Add RELEASE-NOTES.md file
- Add CHANGELOG.md file
- Add CONTRIBUTING.md file
- Add release.yml file
- Add scripts folder with first version of SPSCleanDependencies
- README.md
  - Add code_of_conduct.md badge
- Add CODE_OF_CONDUCT.md file
- Add Issue Templates files:
  - 1_bug_report.yml
  - 2_feature_request.yml
  - 3_documentation_request.yml
  - 4_improvement_request.yml
  - config.yml
- Wiki Documentation in repository - Add :
  - wiki/Home.md
  - wiki/Getting-Started.md
  - wiki/Configuration.md
  - wiki/Usage.md
  - .github/workflows/wiki.yml

### Changed

- SPSCleanDependencies.ps1:
  - Update parameter description
  - Add missing comments
