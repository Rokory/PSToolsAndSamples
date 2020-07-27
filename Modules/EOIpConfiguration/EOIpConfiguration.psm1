<#
.SYNOPSIS
Configures the most common IPv4 settings.
.DESCRIPTION
Configures the interface IPv4 settings either for DHCP or manually. 
With manual configuration, an IP address including a prefix length, a default gateway,
and DNS servers can be configured.
.PARAMETER InterfaceAlias
The name of the network interface to configure. Use Get-NetAdapter to get the name.
.PARAMETER Dhcp
Sets IPv4 address, default gateway and DNS servers to be retrieved by DHCPDISCOVER.
.PARAMETER IpAddress
The IPv4 address to be configured.
.PARAMETER PrefixLength
The number of bits set in the subnet mask.
.PARAMETER DefaultGateway
The default gateway to be configured.
.PARAMETER DnsServerAddresses
Comma-separated list of IPv4 addresses of DNS servers.
.EXAMPLE
Set-NetIpConfiguration -InterfaceAlias Ethernet -IpAddress 172.16.0.30 -PrefixLength 16 -DefaultGateway 172.16.0.1 -DnsServerAddresses 172.16.0.10, 172.16.0.20

Sets the IPv4 address of the network interface 'Ethernet' to 172.16.0.30, 
with a subnet mask of 255.255.0.0. The default gateway is set to 172.16.0.1 and two
DNS servers are configured with the addresses 172.16.0.10 and 172.16.0.20.


.EXAMPLE
Set-NetIpConfiguration -InterfaceAlias Ethernet -Dhcp

Configures the network interface 'Ethernet' for DHCP.
#>
function Set-NetIpConfiguration {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $InterfaceAlias,

        [Parameter(ParameterSetName='DHCP')]
        [switch]
        [bool]
        $Dhcp,
        
        [Parameter(ParameterSetName='NonDHCP', Mandatory=$true)]
        [String]
        [ValidatePattern('(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)(?:\.(?!$)|$)){4}')]
        $IpAddress,

        [Parameter(ParameterSetName='NonDHCP', Mandatory=$true)]
        [ValidateRange(1, 31)]
        [byte]
        $PrefixLength,

        [Parameter(ParameterSetName='NonDHCP')]
        [ValidatePattern('(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)(?:\.(?!$)|$)){4}')]
        [String]
        $DefaultGateway,

        [Parameter(ParameterSetName='NonDHCP')]
        [ValidatePattern('(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)(?:\.(?!$)|$)){4}')]
        [String[]]
        $DnsServerAddresses
    )

    Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 | 
    Remove-NetIPAddress -WhatIf:$WhatIfPreference
    
    Get-NetRoute `
        -InterfaceAlias $InterfaceAlias `
        -DestinationPrefix 0.0.0.0/* `
        -ErrorAction SilentlyContinue | 
    Remove-NetRoute -WhatIf:$WhatIfPreference

    switch ($PSCmdlet.ParameterSetName) {
        DHCP {
            if ($PSCmdlet.ShouldProcess(
                "NetIPInterface -InterfaceAlias $InterfaceAlias", 'Set -Dhcp Enabled')
            ) {
                Set-NetIPInterface -Dhcp Enabled -InterfaceAlias $InterfaceAlias
            }
            if ($PSCmdlet.ShouldProcess(
                "DnsClientServerAddress -InterfaceAlias $InterfaceAlias", 
                'Set -ResetServerAddresses'
            )) {
                Set-DnsClientServerAddress `
                    -ResetServerAddresses `
                    -InterfaceAlias $InterfaceAlias
            }
        }
        NonDHCP {
            if ($PSCmdlet.ShouldProcess(
                "NetIPInterface -InterfaceAlias $InterfaceAlias", 
                'Set -Dhcp Disabled'
            )) {
                Set-NetIPInterface -Dhcp Disabled -InterfaceAlias $InterfaceAlias
            }
            if ($PSCmdlet.ShouldProcess(
                "NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IpAddress -PrefixLength $PrefixLength -AddressFamily IPV4",
                "New"
            )) {
                New-NetIPAddress `
                    -InterfaceAlias $InterfaceAlias `
                    -IPAddress $IpAddress `
                    -PrefixLength $PrefixLength `
                    -AddressFamily IPv4
            }
            if ($null -ne $DefaultGateway `
                -and $PSCmdlet.ShouldProcess(
                    "NetRoute -InterfaceAlias $InterfaceAlias -NextHop $DefaultGateway -RouteMetrix 0 -AddressFamily IPv4",
                    "New"
                )
            ) {
                New-NetRoute `
                    -InterfaceAlias $InterfaceAlias `
                    -DestinationPrefix 0.0.0.0/0 `
                    -NextHop $DefaultGateway `
                    -RouteMetric 0 `
                    -AddressFamily IPv4 `
                > $null
            }
            if ($null -ne $DnsServerAddresses `
                -and $PSCmdlet.ShouldProcess(
                    "DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DnsServerAddresses",
                    "Set"
                )
            ) {
                Set-DnsClientServerAddress `
                    -InterfaceAlias $InterfaceAlias `
                    -ServerAddresses $DnsServerAddresses
            }
        }
    }
}

# Set-NetIpConfiguration `
#     -InterfaceAlias Ethernet `
#     -IpAddress 172.16.0.30 `
#     -PrefixLength 16 `
#     -DefaultGateway 172.16.0.1 `
#     -DnsServerAddresses 172.16.0.10

# Set-NetIpConfiguration `
#     -InterfaceAlias Ethernet `
#     -IpAddress 172.16.0.30 `
#     -PrefixLength 16 `
#     -DefaultGateway 172.16.0.1

# Set-NetIpConfiguration `
#     -InterfaceAlias Ethernet `
#     -IpAddress 172.16.0.30 `
#     -PrefixLength 16 `
#     -DnsServerAddresses 172.16.0.10

# Set-NetIpConfiguration `
#     -InterfaceAlias Ethernet `
#     -IpAddress 172.16.0.30 `
#     -PrefixLength 16


# Set-NetIpConfiguration -InterfaceAlias Ethernet -Dhcp
