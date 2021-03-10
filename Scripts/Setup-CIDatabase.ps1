<#
    .SYNOPSIS
    Sets up a database for the Computer Inventory example.
#>
#Requires -Modules EOSQLUtility

# The name of the database
$databaseName = 'Assets'
$server = 'localhost/SQLExpress'

# Create the database
New-SqlDatabase -Name $databaseName -Server $server

# Connect to the database
$sqlConnection = Connect-SqlServer -Database $databaseName -Server $server

# Create a table OperatingSystems
Invoke-SqlCommand `
    -Command @"
    CREATE TABLE OperatingSystems (
        Id                  UNIQUEIDENTIFIER    PRIMARY KEY,
        Name                VARCHAR(255)        NOT NULL,
        Version             VARCHAR(255)
    )
"@ `
    -Connection $sqlConnection

# Create table Packages
Invoke-SqlCommand `
    -Command @"
    CREATE TABLE Packages (
        Id                  UNIQUEIDENTIFIER    PRIMARY KEY,
        Name                VARCHAR(255)        NOT NULL,
        Version             VARCHAR(255)
    )
"@ `
    -Connection $sqlConnection

# Create table Computers
Invoke-SqlCommand `
    -Command @"
    CREATE TABLE Computers (
        Id UNIQUEIDENTIFIER PRIMARY KEY,
        Name                VARCHAR(255)        NOT NULL,
        SerialNumber        VARCHAR(255),
        OperatingSystemId   UNIQUEIDENTIFIER
    )
"@ `
    -Connection $sqlConnection

# Create table ComputerPackages
# This will store the actually installed packages on a particular computer
Invoke-SqlCommand `
    -Command @"
    CREATE TABLE ComputerPackages (
        Id                  UNIQUEIDENTIFIER PRIMARY KEY,
        ComputerId          UNIQUEIDENTIFIER NOT NULL,
        PackageId           UNIQUEIDENTIFIER NOT NULL,
        Source              VARCHAR(255),
        FullPath            VARCHAR(255),
        ProviderName        VARCHAR(255)
    )
"@ `
    -Connection $sqlConnection

# Create table ComputerPackagesTemp
# This is a temporary table to store the query information from a computer,
# before it is merged into the database
Invoke-SqlCommand `
    -Command @"
    CREATE TABLE ComputerPackagesTemp (
        InventoryRunId      UNIQUEIDENTIFIER,
        ComputerId          UNIQUEIDENTIFIER,
        Name                VARCHAR(255),
        Version             VARCHAR(255),
        Source              VARCHAR(255),
        FullPath            VARCHAR(255),
        ProviderName        VARCHAR(255)
    )
"@ `
    -Connection $sqlConnection

# Close the connection
$sqlConnection.Close()
