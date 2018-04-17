<#
.NOTES
	Daniel Hibbert, Microsoft - May 2014
	Version 1.0

	Exchange - Fix-OWARedirect.ps1

	THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY
	KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
	IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
	PARTICULAR PURPOSE.

.SYNOPSIS

	script to correct Exchange 2010 OWA / ECP Virtual Directory Authentication
	settings to enable silent cross-site redirect.
#>

$CAStoFix = (Import-CSV -Path ./list.csv)
$Date = Get-Date -Format yyyyMMdd
$DomainName = domain.com
Clear-Host


Foreach ($i in $CAStoFix){

	[String]$targetServer = $i.Server
	Write-Progress -Activity "Updating Exchange OWA / ECP Virtual Directory Configuration" -Status "Progress: $TargetServer" -PercentComplete (($ii / $CAStoFix.Count)*100) -Id 1

	#Write-Host -ForegroundColor Green "Fixing $TargetServer"
	#Write-Host ""
	$ExchSrv = (Get-ExchangeServer -Identity $TargetServer)
	$computersitename = $ExchSrv.site.name
	$computerFQDN = $ExchSrv.fqdn

	$SessionURI = "http://"+$computerFQDN+"/PowerShell/"
	Write-Progress -Activity "Initiating Remote PowerShell" -Status "Connecting to: $SessionURI" -ParentId 1

	
	$s = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $SessionURI -Authentication Kerberos
	Import-PSSession $S -AllowClobber | out-Null 

	$externalOWAName = "https://Mail"+$COMPUTERSITENAME+"."+$DomainName+"/owa"
	$externalECPName = "https://Mail"+$COMPUTERSITENAME+"."+$DomainName+"/ecp"

	$OWAVdirId = $TargetServer+"\owa (Default Web Site)"
	$ECPVdirId = $TargetServer+"\ecp (Default Web Site)"


	<# OWA VDir #>
	Write-Progress -Activity "Updating OWA Virtual Directory" -Status "Progress: $OWAVdirId" -ParentId 1
	Set-OWAVirtualDirectory -Identity $OWAVdirId -FormsAuthentication:$True -ExternalURL $externalOWAName -CrossSiteRedirectType Silent -ExternalAuthenticationMethods fba
	Sleep 10

	<# ECP VDir #>
	Write-Progress -Activity "Updating ECP Virtual Directory" -Status "Progress: $ECPVdirId" -ParentId 1
	Set-ECPVirtualDirectory -Identity $ECPVdirId -FormsAuthentication:$True -ExternalURL $externalECPName
	Sleep 10

	$targetServer >> ./Complete.txt

	<# Tear down remote PS session to remote Exchage server #>
	Remove-PSSession $S

	$ii++
	Clear-Host
}

