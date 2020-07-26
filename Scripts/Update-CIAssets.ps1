<#
    .SYNOPSIS
    Queries the local computer for its name, serial number, operating system,
    and installed software packages, and stores the information in a database
#>

#Requires -Modules EOSQLUtility

# The name of the database
$databaseName = 'Assets'

# Get computername, serial number and operating system info
# The property BIOSSeralNumber (sic!) contains the serial number
$computerInfo = Get-ComputerInfo `
    -Property CSName, WindowsProductName, WindowsVersion, BIOSSeralNumber

# Get installed software
$packages = Get-Package |
Select-Object Name, Version, Source, FullPath, ProviderName

# Connect to SQL server
$sqlConnection = Connect-SqlServer -Database $databaseName

# Find operating system in database
$query = @"
    SELECT * 
    FROM OperatingSystems 
    WHERE
            Name    = '$($computerInfo.WindowsProductName)' 
        AND Version = '$($computerInfo.WindowsVersion)'
"@

$dataReader = Get-SqlDataReader -Query $query -Connection $sqlConnection

# If operating system was found, save id

if ($dataReader.Read()) {
    $operatingSystemId = $dataReader['Id']
    Write-Host "Name: $($dataReader['Name']), Version: $($dataReader['Version']))"
}

$dataReader.Close()

# If operating system not found, create new record

if ($null -eq $operatingSystemId) {
    $operatingSystemId = (New-Guid).Guid
    $command = @"
        INSERT INTO OperatingSystems (
                Id, 
                Name, 
                Version
        ) VALUES (
            '$operatingSystemId',   
            '$($ComputerInfo.WindowsProductName)',  
            '$($computerInfo.WindowsVersion)'
        )
"@
    Invoke-SqlCommand -Command $command -Connection $sqlConnection > $null
}

# Find computer in database using the Serial Number

$whereClause = @"
    WHERE
        SerialNumber    = '$($computerInfo.BiosSeralNumber)' 
"@
$query = @"
    SELECT * 
    FROM Computers
    $whereClause
"@

$dataReader = Get-SqlDataReader -Query $query -Connection $sqlConnection

# If computer was found, save data

$computerId = $null
if ($dataReader.Read()) {
    $computerId = $dataReader['Id']
    $computerName = $dataReader['Name']
    $computerOperatingSystemId = $dataReader['OperatingSystemId']
}

$dataReader.Close()

# if necessary, update computer

if ( `
    $null -ne $computerId `
    -and ( `
        $computerName -ne $computerInfo.CsName `
        -or $computerOperatingSystemId -ne $operatingSystemId `
    ) `
) {
    $command = @"
        UPDATE Computers
        SET Name                = '$($computerInfo.CsName)',
            OperatingSystemId   = '$operatingSystemId'
        $whereClause
"@
    Invoke-SqlCommand -Command $command -Connection $sqlConnection > $null
}

# If computer not found, create new record

if ($null -eq $computerId) {
    $computerId = (New-Guid).Guid
    $command = @"
        INSERT INTO Computers (
                Id, 
                Name, 
                OperatingSystemId,
                SerialNumber
        ) VALUES (
            '$computerId',   
            '$($computerInfo.CsName)',  
            '$operatingSystemId',
            '$($computerInfo.BiosSeralNumber)'
        )
"@
    Invoke-SqlCommand -Command $command -Connection $sqlConnection > $null
}

# Write packages to temporary table in database
# This simplifies and speeds up the update of the software packages,
# as this can run in SQL server only

$values = $null
$inventoryRunId = (New-Guid).Guid # unique id of the current inventory run

# Concetanate the values of all packages found
foreach ($package in $packages) {
    if ($null -ne $values) {
        $values += ', '
    }
    $values += @"
        (
            '$inventoryRunId',
            '$computerId',
            '$($package.Name)',
            '$($package.Version)',
            '$($package.source)',
            '$($package.FullPath)',
            '$($package.ProviderName)'
        )
"@
}

# Insert the packages into the temporary table
if ($values) {
    $command = @"
        INSERT INTO ComputerPackagesTemp (
            InventoryRunId,
            ComputerId,
            Name,
            Version,
            Source,
            FullPath,
            ProviderName
        ) VALUES
            $values
"@
    Invoke-SqlCommand -Command $command -Connection $sqlConnection > $null
}

# Create necessary packages in database
# Note the comments in the SQL statements
$command = @"
    INSERT INTO Packages
        -- Add a unique id to each package, which should be inserted
        SELECT NEWID() As Id, * 
            FROM (
                    -- Select all unique software packages, not yet in db
                    SELECT DISTINCT t.Name, t.Version
                        FROM ComputerPackagesTemp AS t
                        -- LEFT JOIN selects all packages found on computer,
                        -- regardless whether they are in the database
                        LEFT JOIN Packages AS P ON 
                            t.Name = p.Name
                            AND t.Version = p.Version
                        -- Find those, which are not in the packages table yet
                        -- For these, the fields from the packages table
                        -- return null.
                        WHERE
                            t.InventoryRunId = '$inventoryRunId'
                            AND p.Id IS NULL
                ) As UniquePackages
"@

Invoke-SqlCommand -Command $command -Connection $sqlConnection > $null

# Add package references, if necessary

$command = @"
    INSERT INTO ComputerPackages
        SELECT
            -- Create new Ids for new records
            NEWID() As Id,
            '$computerId' AS ComputerID, 
            p.Id AS PackageID,
            cpt.Source, 
            cpt.FullPath,
            cpt.ProviderName

            -- First, join packages with temp table, to get the package ids
            FROM Packages AS p
                INNER JOIN ComputerPackagesTemp AS cpt ON
                    p.Name = cpt.Name
                    AND p.Version = cpt.Version
            -- Then, find packages, which are not currently referenced for the
            -- computer using a LEFT JOIN
                LEFT JOIN ComputerPackages AS cp ON
                    p.id = cp.PackageId
            WHERE
                InventoryRunId = '$inventoryRunId'
                AND cp.PackageId IS NULL

"@
Invoke-SqlCommand -Command $command -Connection $sqlConnection > $null

# Remove package references which are not installed anymore

$command = @"
    DELETE FROM ComputerPackages
        WHERE Id IN (
            -- Select Ids for packages, not installed on the computer anymore
            SELECT cp.Id
                -- First, join ComputerPackages with Packages, to get full
                -- package information
                FROM ComputerPackages AS cp
                    INNER JOIN Packages AS p ON
                        cp.PackageId = p.Id
                -- Then, find ComputerPackages not in temp table, which
                -- should be deleted
                    LEFT JOIN ComputerPackagesTemp AS cpt ON
                        cp.ComputerId = cpt.ComputerId
                        AND p.Name = cpt.Name
                        AND p.Version = cpt.Version
                        AND cp.FullPath = cpt.FullPath
                        AND cp.Source = cpt.Source
                        AND cp.ProviderName = cpt.ProviderName
                WHERE
                    cp.ComputerId = '$computerId'
                    AND cpt.InventoryRunId = '$inventoryRunId'
                    AND cpt.Name IS NULL

            )
"@

# Remove packages from temporary table

$command = @"
    DELETE FROM ComputerPackagesTemp
    WHERE InventoryRunId = '$inventoryRunId'
"@
Invoke-SqlCommand -Command $command -Connection $sqlConnection > $null


$sqlConnection.Close()