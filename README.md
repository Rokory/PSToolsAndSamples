# PowerShell Tools and Samples

This repository contains some small scripts, modules and samples.

## Scripts

### Classes.ps1

This script demonstrates the usage of object-oriented features in PowerShell. It is recommended to run this in debug mode to understand what's going on. The comments will help understanding the concepts.

### Pipeline.ps1

This is a short example on how to process items from the pipeline without using any loop.

### Setup-CIDatabase.ps1 and Update-CIAssets.ps1

#### Synopsis

Sample powershell script for retrieving computer inventory data and storing it in a database.

#### Requirements

Module EOSQLUtility, which you can find in the modules folder.

#### Getting started

1. Install some edition of Microsoft SQL server on the local computer. You can use ````Install-SQLServer```` from the EOSQLUtility module to quickly install an Express edition
2. Run the Setup-CIDatabase to create the database structure.
3. Run the Update-CIAssets to store the computer inventory information in the database.

## Modules

### Getting started

It is recommended to copy the folders in Modules to one of the folders indicated by the $env:PSModulePath variable (e. g. %userprofile%\Documents\WindowsPowerShell\Modules).

First, import the module.

````powershell
Import-Module <String>
````

You can either use the module name or the full path, if you did not copy the module to one of the paths in $env:PSModulePath.

To find information about useage, use ```Get-Help``` followed by the cmdlet in the module

### EODownload

#### Invoke-BitsTransfer

Simple cmdlet to start a synchronous download of a file using BITS. Demonstrates the usage of a progress bar.

### EOIpConfiguration

#### Set-NetIpConfiguration

Provides an easy way to set the most common IP configuration settings. Demonstrates parameter sets and comment-based help.

### EOSQLUtility

#### Requirements

Requires the module EODownload.

#### Install-SqlServer

Downloads and optionally installs SQL Server 2019 Developer or Express editition. Demonstrates the support of the -WhatIf parameter.

#### Install-SqlServerManagementStudio

Downloads and installs SQL Server Management Studio 18.4.

#### Connect-SqlServer, Invoke-SqlCommand, New-SqlDatabase, Get-SqlDataReader

Demonstrate useful patterns for working with SQL databases in PowerShell.
