<#
.NOTES
	Daniel Hibbert, Microsoft - June 2014
	Version 1.0

	Exchange - Reset-DefaultCalendarPermissions.ps1

	THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY
	KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
	IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
	PARTICULAR PURPOSE.

.SYNOPSIS

	Reset Defualt User calendar permission.

.DESCRIPTION

	This script will read from a list of users and rested the default calendar permissions to the default
	of 'AvailabilityOnly'.

#>
Clear-Host
$ii = 0
$UsrList = (Import-Csv -Path ".\ResetCal-List.csv")
Set-ADServerSettings -ViewEntireForest:$true


foreach ($usr in $UsrList){

	[String]$UsrID = $Usr.EmailAddress
	$FolderID = $UsrID+":\Calendar"

	Write-Progress -Activity ":: Restting Default Calendar Permissionsm ::" -Status "Progress: $UsrID" -PercentComplete (($ii / $UrsList.Count)*100)

	Set-MailboxFolderPermission $FolderID -User Default -AccessRights Owner | Out-Null
	Start-Sleep -Seconds 2
	$ii++
}