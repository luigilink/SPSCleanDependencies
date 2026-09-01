# SPSCleanDependencies

![Latest release date](https://img.shields.io/github/release-date/luigilink/SPSCleanDependencies.svg?style=flat)
![Total downloads](https://img.shields.io/github/downloads/luigilink/SPSCleanDependencies/total.svg?style=flat)  
![Issues opened](https://img.shields.io/github/issues/luigilink/SPSCleanDependencies.svg?style=flat)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](code_of_conduct.md)

## Description

SPSCleanDependencies is a PowerShell script tool to clean Missing Server Dependencies in your SharePoint Farm.

It's compatible with **SharePoint Server Subscription Edition**.

> [!NOTE]
> SharePoint Server 2016 and 2019 reached end of support on 14 July 2026. If you are still running one of those versions, use the previous major release ([v1.4.0](https://github.com/luigilink/SPSCleanDependencies/releases/tag/v1.4.0)).

> [!IMPORTANT]
> Backup content database first​ and test script on testing environment

## Requirements

### Windows Management Framework 5.0

Required because this module now implements class-based resources.
Class-based resources can only work on computers with Windows rManagement Framework 5.0 or above.
The preferred version is PowerShell 5.1 or higher, which ships with Windows 10 or Windows Server 2016.
This is discussed further on the [SPSCleanDependencies Wiki Getting-Started](https://github.com/luigilink/SPSCleanDependencies/wiki/Getting-Started)

### SqlServer PowerShell Module

This module allows SQL Server developers, administrators and business intelligence professionals to automate database development and server administration, as well as both multidimensional and tabular cube processing.

🚛 Get it via the [PowerShell gallery](https://www.powershellgallery.com/packages/SqlServer)

🔎 [Cmdlet Reference](https://docs.microsoft.com/powershell/module/sqlserver/)

## Documentation

For detailed usage, configuration, and getting started information, visit the [SPSCleanDependencies Wiki](https://github.com/luigilink/SPSCleanDependencies/wiki)

## Changelog

A full list of changes in each version can be found in the [change log](CHANGELOG.md)
