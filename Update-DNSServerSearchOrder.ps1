<#
.NOTES
	Daniel Hibbert:

.SYNOPSIS
	Script-o-matically change DNS Search Order on local / remote computers. 

.DESCRIPTION
	This script will be used to automate the process of bulk DNS Server Search Order on Windows servers. By default this
	script will discover all of the in site Active Directory Domain Controllers for the target computer, and overwrite
	any existing DNS configuration with these servers.  

	There are also functions / parameters to add or remove DNS servers to the existing search order. 

	In order to function in environments that do not allow Remote PowerShell all of the network config performed on remote
	computers is performed using WMI. This script can be used against any Windows operating system that the operator has 
	adminstrator permissions for. 
	
.PARAMETER ComputerName
	Target computer for DNS changes.

.PARAMETER CustomDNSServers
	Add aditional DNS servers to the end of the DNS server search order on the target computer. 

.PARAMETER RemoveServer
	Provide IP address for DNS server(s) to remove from the DNS server search order on the target computer. 

.PARAMETER IncludeInSiteDC
	All configured DNS servers will be replaced with the IPs of all the local AD domain controllers in the AD site local
	to the target computer.

.EXAMPLE
	Update-DNSServerSearchOrder -ComputerName computer01.contoso.com ps1 -CustomDNSServers “192.168.30.8”,”192.168.30.4”
	Using the 'CustomerDNSServerServers' parameter the additional DNS servers will be added on to the end of the DNS server search order
	for the target computer (Computer01.contoso.com).

.EXAMPLE
	Update-DNSServerSearchOrder -ComputerName computer01.contoso.com ps1 -RemoveServer 192.168.30.8 
	Using the 'RemoveServer' parameter the additional DNS servers will be removed from the DNS server search order
	for the target computer (Computer01.contoso.com).

.EXAMPLE
	Update-DNSServerSearchOrder -ComputerName computer01.contoso.com –IncludeInSiteDC
	The existing DNS server search order on the target computer (Computer01.contoso.com) will be overwritten with all of the
	in-site AD domain controllers.
	
#>

Param (
	[parameter(Position=0, Mandatory=$True)][Array]$ComputerName = @(),
    [parameter(Position=1, Mandatory=$False)][Array]$CustomDNSServers = @(),
	[parameter(Position=3, Mandatory=$False)][Switch]$IncludeInSiteDC = $True,
    [parameter(Position=2, Mandatory=$False)][Array]$RemoveServer = $()
)

# Global Variables
[Array]$DNSServerSearchOrder = @()
[String]$ExportPath = $ENV:USERPROFILE+"\Desktop\ExchangeServerDNSSettings.CSV"

If ($PSBoundParameters["Debug"]) {$DebugPreference = "Continue"}

if ($IncludeInSiteDC -eq $True){
    try {Import-Module ActiveDirectory -ErrorAction stop}
    catch {Write-Host -ForegroundColor Red "Unable to import Active Directory module`nThis script requires Active Directory PowerShell module"; Exit}
}

foreach ($Server in $ComputerName){

    $SrvNetworkConfig = (Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'True'" -ComputerName $Server | Where-Object {$_.DNSServerSearchOrder -ne $Null})
    Write-Debug "[$Server] Current configured DNS Servers: $($SrvNetworkConfig.DNSServerSearchOrder)"
    Write-Host -ForegroundColor Green "Updating DNS server search settinsg for: $($Server)"

    Switch ($RemoveServer.count -gt 0){
		$True{
            # Removing DNS Servers
            Write-Debug "Removing DNS Servers"
            # Default Arrays are fixed size and cannot be edited. Changeing the array type to support removing entries. 
            [system.collections.arraylist]$DNS = $SrvNetworkConfig.DNSServerSearchOrder

			foreach ($DNS_SrvRemove in $RemoveServer){
                Write-Debug "[$Server] Removing DNS server: $DNS_SrvRemove"
                $DNS.Remove($DNS_SrvRemove)
			}
            $DNSServerSearchOrder += $DNS
        }
		$False{
			if ($IncludeInSiteDC -eq $False){
				# Discover AD DNS servers in Remote AD Site
				$RemoteADSiteName = (invoke-command -ComputerName $Server -Command {nltest /dsgetsite})[0]
				Write-Debug "[$Server] AD Site for $RemoteADSiteName"

				$RemoteADSite_DC = (Get-ADDomainController -Filter {Site -eq $RemoteADSiteName} | Select-Object Name, IPV4Address)
				Write-Debug "[$Server] Discovered ($($RemoteADSite_DC.count)) domain controlles in AD Site: $RemoteADSiteName"
		}
        Else {$DNSServerSearchOrder += $SrvNetworkConfig.DNSServerSearchOrder}
	}        
	}
    
	# Add discovered DCs to DNS Server Search List
    Foreach ($IP in $RemoteADSite_DC){$DNSServerSearchOrder += $IP.IPV4Address}

    # Add in any additional DNS Servers
    $DNSServerSearchOrder += $CustomDNSServers
    Write-debug "DNS Servers to Add: $($DNSServerSearchOrder)"

	# Set updated DNS Server Search Order
    $SrvNetworkConfig.SetDNSServerSearchOrder($DNSServerSearchOrder)
    $Post_SrvNetworkConfig = (Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'True'" -ComputerName $Server | Where-Object {$_.DNSServerSearchOrder -ne $Null})
}

# Reset default debug preference
$DebugPreference = "SilentlyContinue"