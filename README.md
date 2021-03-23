# PowerShell Tools and Samples

This content of this repository has been moved to various separate repositories.

## Scripts

<<<<<<< HEAD
Demonstration scripts for classes, menus and database operations can be found at <https://github.com/Rokory/PSSamples>.
=======
### Menu.ps1

Example patter for a text-based menu. Demonstrates Write-Host, Read-Host, loops and switch constructs.

### Classes.ps1

This script demonstrates the usage of object-oriented features in PowerShell. It is recommended to run this in debug mode to understand what's going on. The comments will help understanding the concepts.

### Setup-CIDatabase.ps1 and Update-CIAssets.ps1

#### Synopsis

Sample powershell script for retrieving computer inventory data and storing it in a database. Demonstrates working with SQL and error handling.

#### Requirements

Module EOSQLUtility, which you can find in the modules folder.

#### Getting started

1. Install some edition of Microsoft SQL server on the local computer. You can use ````Install-SQLServer```` from the EOSQLUtility module to quickly install an Express edition
2. Run the Setup-CIDatabase to create the database structure.
3. Run the Update-CIAssets to store the computer inventory information in the database.
>>>>>>> c30fb90f50dced8d4510beca2bb070cd19c353c5

## Modules

### BITSDownload

start a synchronous download of a file using BITS. Demonstrates handling of multiple pipeline values and the usage of a progress bar. Clone it from <https://github.com/Rokory/BITSDownload>.

### IpConfiguration

Provides an easy way to set the most common IP configuration settings. Demonstrates parameter sets and comment-based help. Clone it from <https://github.com/Rokory/IpConfiguration>.

### SQLUtility

Cmdlets to download and install SQL Server 2019 Developer or Express editition, as well as connecting, querying and manipulating databases. Demonstrate the support of the -WhatIf parameter.
