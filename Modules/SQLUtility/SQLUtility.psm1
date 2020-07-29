function Use-Module {
    [CmdletBinding()]
    param (
        [Parameter(
            ValueFromPipeline = $true, 
            ValueFromPipelineByPropertyName = $true)
        ]
        [string[]]
        $Name
    )
    BEGIN {}
    PROCESS {
        foreach ($moduleName in $Name) {
            if ($null -eq (Get-Module -Name $moduleName)) {
                Import-Module -Name $moduleName
            }
        }
    }
    END {}
}
<#
    .SYNOPSIS
    Downloads and optionally installs SQL Server 2019
    .DESCRIPTION
    If you specify the switch -Download, the setup sources for SQL Server 2019
    are downloaded only. Without the switch, SQL Server is downloaded and
    installed.
    .PARAMETER Download
    Use this parameter to download SQL server without installing it.
    .PARAMETER Edition
    Choose between Developer or Express edition. Defaults to Express.
    .PARAMETER Language
    Choose the language for SQL Server. Defaults to en-US. Supported languages
    are zh-TW, zh-CN, de-DE, en-US, fr-FR, it-IT, ko-KR, pt-BR, ru-RU, and
    es-ES.
    .PARAMETER InstallPath
    Specifies the location of the SQL server instance including data files.
    .PARAMETER MediaPath
    Specifies the location for the downloaded media files
    .PARAMETER MediaType
    Specifies the media to be downloaded. Can be either CAB or ISO. Defaults
    to CAB. In install mode, MediaType is always CAB.
    .PARAMETER BootstrapPath
    Specifies the location where the downloader file should be saved to.
    Defaults to the Download folder of the current user.
    .PARAMETER Configuration
    Specifies an optional configuration file to be used to install SQL Server.
#>
function Install-SqlServer {
    # Disables the default behaviour of assigning
    # position numbers to parameters in the order in which the parameters are
    # declared. More information:
    # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters#attributes-of-parameters
    #
    # Enables support for -WhatIf parameter
    [CmdletBinding(PositionalBinding = $false, SupportsShouldProcess = $true)]
    param (
        # This is a switch parameter
        [Parameter(ParameterSetName = 'Download', Mandatory = $true)]
        [switch]
        [bool]
        $Download,

        # Edition selection for installation and download
        [Parameter(ParameterSetName = 'Download')]
        [Parameter(ParameterSetName = 'Install')]
        # A validate set is a list of allowed values for the parameter
        [ValidateSet('Developer', 'Express')]
        [String]
        $Edition = 'Express',

        # Language selection for installation and download
        [Parameter(ParameterSetName = 'Download')]
        [Parameter(ParameterSetName = 'Install')]
        [ValidateSet(
            'zh-TW', 
            'zh-CN', 
            'de-DE',
            'en-US',
            'fr-FR',
            'it-IT',
            'ja-JP',
            'ko-KR', 
            'pt-BR',
            'ru-RU',
            'es-ES'
        )]
        [string]
        $Language = 'en-us',

        # Specifies the location for SQL server data files
        [Parameter(ParameterSetName = 'Install')]
        [String]
        $InstallPath,

        # Location to which the SQL Server setup media are downloaded and 
        # extracted
        [Parameter(ParameterSetName = 'Download')]
        [Parameter(ParameterSetName = 'Install')]
        [String]
        $MediaPath,

        # Specifies the type of media to be downloaded
        [Parameter(ParameterSetName = 'Download')]
        [ValidateSet('ISO', 'CAB')]
        [String]
        $MediaType = 'CAB',

        # Specifies the location of the bootstrap downloader
        [Parameter(ParameterSetName = 'Download')]
        [Parameter(ParameterSetName = 'Install')]
        [String]
        $BootstrapPath,
        
        # Specifies the configuration file to be used
        [Parameter(ParameterSetName = 'Install')]
        [String]
        $ConfigurationFile
    )

    # Import required modules

    Use-Module -Name 'BITSDownload' -ErrorAction Stop

    #region Download SQL server

    switch ($Edition) {
        'Developer' { 
            $downloadPath = `
                'https://download.microsoft.com/download/d/a/2/da259851-b941-459d-989c-54a18a5d44dd/SQL2019-SSEI-Dev.exe'
         }
        'Express' {
            $downloadPath = `
                'https://download.microsoft.com/download/7/f/8/7f8a9c43-8c8a-4f7c-9f92-83c18d96b681/SQL2019-SSEI-Expr.exe'
        }
    }

    # Parameters for Cmdlets can be assembled as hash table
    $parameters = @{ Source = $downloadPath }
    if (-not [String]::IsNullOrWhiteSpace($BootstrapPath)) {
        $parameters.Add('Destination', $BootstrapPath)
    }
    # To use a hashtable as parameter set, instead of preceeding the variable
    # name with $, preceed it with an @ sign.
    $setupFile = Invoke-BitsTransfer @parameters
    #endregion


    #region Build the parameters
    $parameters = '/IACCEPTSQLSERVERLICENSETERMS /QUIET '
    $parameters += "/LANGUAGE:$language "

    if (-not [String]::IsNullOrWhiteSpace($MediaPath)) {
        $parameters += "/MEDIAPATH:""$MediaPath"" "
    }

    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
        $parameters += "/VERBOSE "
    }

    switch ($PSCmdlet.ParameterSetName) {
        'Download' { 
            $parameters += '/ACTION:Download '
            $parameters += "/MEDIATYPE:$MediaType " 
         }
        'Install' {
            $parameters += '/ACTION:Install '

            if (-not [String]::IsNullOrWhiteSpace($InstallPath)) {
                $parameters += "/INSTALLPATH:""$InstallPath"" "
            }
            if (-not [string]::IsNullOrWhiteSpace($ConfigurationFile)) {
                $parameters += "/CONFIGURATIONFILE:""$ConfigurationFile"" "
            }
        }
    }
    #endregion

    #region The user locale must be set to the system locale to avoid errors
    $itemPath = 'HKCU:\Control Panel\International'
    $itemPropertyName = 'LocaleName'
    $itemPropertyValue = Get-ItemPropertyValue `
        -Path $itemPath `
        -Name $itemPropertyName
    $winSystemLocale = (Get-WinSystemLocale).Name
    
    $message = "Setting $itemPropertyName in $itemPath to $winSystemLocale"
    if ($PSCmdlet.ShouldProcess($message)) {
        Set-ItemProperty `
            -Path $itemPath `
            -Name $itemPropertyName `
            -Value $winSystemLocale        
    }
    #endregion
    
    # Download or install
    if ($PSCmdlet.ShouldProcess(
        "Executing downloaded file $setupFile with parameters $parameters"
    )) {
        Start-Process -FilePath $setupFile -ArgumentList $parameters -Wait
    }

    # Restore user locale
    $value = $itemPropertyValue
    $message = "Setting $itemPropertyName in $itemPath to $value"
    if ($PSCmdlet.ShouldProcess($message)) {
        Set-ItemProperty `
            -Path $itemPath `
            -Name $itemPropertyName `
            -Value $value
    }
}

<#
    .SYNOPSIS
    Downloads and installs SQL Server Management Studio
#>

function Install-SqlServerManagementStudio {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        # Language selection for installation and download
        [ValidateSet(
            'CHS', 
            'CHT', 
            'DEU',
            'ENU',
            'FRA',
            'ITA',
            'JPN',
            'KOR', 
            'PTB',
            'RUS',
            'ESN'
        )]
        [string]
        $Language = 'ENU',

        # Specifies the location of the bootstrap downloader
        [String]
        $BootstrapPath = (
            New-Object -ComObject Shell.Application
        ).NameSpace(
            'shell:Downloads'
        ).Self.Path,

        # Suppress any attempts to restart
        [Parameter()]
        [switch]
        [bool]
        $NoRestart,

        # Logs to a specific file. By default a log file is created in %TEMP%
        [Parameter()]
        [string]
        $Log
    )

    #region Download SQL Server Management Studio

    $BootstrapPath = Join-Path -Path $BootstrapPath -ChildPath 'SSMS-Setup-'
    switch ($Language) {
        'CHS' {
            $downloadPath = `
                'https://go.microsoft.com/fwlink/?linkid=2125901&clcid=0x804'
        }
        'CHT' {
            $downloadPath = `
                'https://go.microsoft.com/fwlink/?linkid=2125901&clcid=0x404'
        }
        'ENU' { 
            $downloadPath = `
                'https://go.microsoft.com/fwlink/?linkid=2125901&clcid=0x409'
         }
         'FRA' {
            $downloadPath = `
                'https://go.microsoft.com/fwlink/?linkid=2125901&clcid=0x40c'
         }
         'DEU' {
            $downloadPath = `
                'https://go.microsoft.com/fwlink/?linkid=2125901&clcid=0x407'
         }
         'ITA' {
            $downloadPath = `
                'https://go.microsoft.com/fwlink/?linkid=2125901&clcid=0x410'
         }
         'JPN' {
            $downloadPath = `
                'https://go.microsoft.com/fwlink/?linkid=2125901&clcid=0x411'
         }
         'KOR' {
            $downloadPath = `
                'https://go.microsoft.com/fwlink/?linkid=2125901&clcid=0x412'
         }
         'PTB' {
            $downloadPath = `
                'https://go.microsoft.com/fwlink/?linkid=2125901&clcid=0x416'
         }
         'RUS' {
            $downloadPath = `
                'https://go.microsoft.com/fwlink/?linkid=2125901&clcid=0x419'
         }
         'ESN' {
            $downloadPath = `
                'https://go.microsoft.com/fwlink/?linkid=2125901&clcid=0x40a'
         }
    }
    $BootstrapPath += "$Language.exe"
    $parameters = @{ Source = $downloadPath }
    if (-not [String]::IsNullOrWhiteSpace($BootstrapPath)) {
        $parameters.Add('Destination', $BootstrapPath)
    }
    $setupFile = Invoke-BitsTransfer @parameters

    #endregion

    #region Build the parameters

    $parameters = '/install /passive'
    if ($NoRestart) {
        $parameters += ' /norestart'
    }

    if (-not [string]::IsNullOrWhiteSpace($Log)) {
        $parameters += " /log ""$Log"""
    }

    #endregion

    # Download or install
    if ($PSCmdlet.ShouldProcess(
        "Executing downloaded file $setupFile with parameters $parameters"
    )) {
        Start-Process -FilePath $setupFile -ArgumentList $parameters -Wait
    }
}

<#
    .SYNOPSIS
    Opens a connection to SQL server and returns the connection object
    .PARAMETER Server
    Name of the SQL server. Use syntax servername\instance,port to connect to a 
    particular instance or to a non-default port. Defaults to localhost.
    .PARAMETER Database
    Name of the database to connect to. Defaults to master.
#>
function Connect-SqlServer {
    [OutputType([System.Data.SqlClient.SqlConnection])]
    [CmdletBinding()]
    param (
        [String]
        $Server = 'localhost',
        
        [String]
        $Database = 'master'
    )

    # Create a new SQLConnection object using the current windows account
    $sqlConnection = New-Object `
        -TypeName System.Data.SqlClient.SqlConnection `
        -ArgumentList `
            "Server=$server;Database=$database;Trusted_Connection=True;"
    # Open the connection
    $sqlConnection.Open()
    return $sqlConnection
}

<#
    .SYNOPSIS
    Executes some SQL command which is not a query and returns the affected rows
    .PARAMETER Command
    Non-querying SQL command
    .PARAMETER Connection
    SqlConnection object to execute the command on.
#>
function Invoke-SqlCommand {
    [OutputType([int32])]
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $Command,

        # Sql connection object
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]
        $Connection
    )

    # If connection is not open, open it
    if ($Connection.State -ne 'Open') {
        $Connection.Open()
    }

    # Create the command object using the provided parameters
    $sqlCommand = New-Object `
        -TypeName System.Data.SqlClient.SqlCommand `
        -ArgumentList $Command, $Connection
    
    # Execute the command and return the result
    return $sqlCommand.ExecuteNonQuery()
}

<#
    .SYNOPSIS
    Creates a new database on the server with default settings.
    .PARAMETER Name
    Name of the new database
    .PARAMETER Server
    Server, where the database should be created. Defaults to localhost.
#>
function New-SqlDatabase {
    [OutputType([int32])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Name,

        [String]
        $Server = 'localhost'
    )

    # Connect to the master database (default)
    $sqlConnection = Connect-SqlServer -Server $Server

    # Invoke an SQL command to create the database and save result
    $result = Invoke-SqlCommand `
        -Command "CREATE DATABASE $Name" `
        -Connection $sqlConnection

    # Close the connection and return result
    $sqlConnection.Close()
    return $result
}


<#
    .SYNOPSIS
    Creates an SQL data reader object using the provided query string.
    .PARAMETER Query
    SQL query
    .PARAMETER Connection
    SqlConnection object to execute the command on.
#>
function Get-SqlDataReader {
    [OutputType([System.Data.SqlClient.SqlDataReader])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Query,

        # SQL database connection
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]
        $Connection
    )

    # Create a command object
    $sqlCommand = New-Object `
        -TypeName System.Data.SqlClient.SqlCommand `
        -ArgumentList $Query, $Connection
 
    # Execute the query and return the data reader object
    <# 
    When returning from a function Powershell will sometimes attempt to unroll
    the object. To force Powershell to not unroll an object use a comma in front
    of the variable being returned
    https://stackoverflow.com/questions/45286964/unable-to-return-an-object-from-one-function-and-pass-it-to-another
    #>
    return , $sqlCommand.ExecuteReader()
}