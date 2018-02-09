<#
.NOTES
       Daniel Hibbert, Microsoft - Sept 2014
       Version 1.0

      Exchange - Hide-PublicFolder.ps1

       THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY
       KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
       IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
       PARTICULAR PURPOSE.

.DESCRIPTION

       This script will automate the process of hiding public folders that are belived to be orphaned.
       The permissions will be recorded in the case the folder is in use and needs to be restored. 

.PARAMETER Server

       Local Exchange 2010 servers hosting a public folder database

.PARAMETER RootPF

       Target Public Folder

.EXAMPLE
       
       Hide-PublicFolder.ps1 -RootPF \FirstPublicFolder -Server Ex01PF
       
       This example will target the public folder '\FirstPublicFolder' and use Ex01PF to make the changes
#>

#region globalvar
Param (
       [parameter(Mandatory=$True)]$Server = $null,
       [parameter(Mandatory=$False)]$RootPF = $null,
       [parameter(Mandatory=$False)][Array]$PFList = $null          
)
# Set this to path to store archived permissions
$ExpPath = "\\<servername>\D$\PublicFolderPermissionBackup"

# Set this to group to be assigned owner permissions on all Public Folders
$PFGlobalOwnersGroup = ""

$DateTime = (Get-Date -Format yyyyMMdd-hhmm)
clear-Host 
#endregion


#region functions
Function HidePF($HidePF_RootPF){
       Clear-Host
       Write-Host -ForegroundColor Green "## Hide Public Folder ##`n"
       
       #Collect Current Public Folder Permissions
       $PFConfig = (Get-PublicFolder -identity "$($HidePF_RootPF)" -Server $Server)
	   if ($PFConfig -eq $Null){Write-Host -ForegroundColor "Public Folder Not Found"}
       Else {
		   $PermList = (Get-PublicFolderClientPermission -identity "$($HidePF_RootPF)" -Server $Server | Select-Object User,@{Expression={$_.AccessRights};Label="AccessRights"})

		   #Export Public Folder permissions
		   $PFPath = $PFConfig.Identity.tostring().replace("\","_")
		   $PermExpPath = $ExpPath+"\"+$($PFPath)+"_"+$($DateTime)+".csv"
		   $PermList | Select-Object User, AccessRights | Export-Csv -NoTypeInformation -Path $PermExpPath

		   #Hide Public Folder from view
		   foreach ($usr in $PermList){Remove-PublicFolderClientPermission -identity $($HidePF_RootPF) -User $($Usr.user) -AccessRights $usr.AccessRights -Server $Server -Confirm:$False}

		   #Add EML Engineering back to public folder as Owner
		   Add-PublicFolderClientPermission -Identity $($HidePF_RootPF) -User $($PFGlobalOwnersGroup) -AccessRights Owner -Server $Server -ErrorAction SilentlyContinue
		   }
       }

Function RestorePFPerm ($RestorePFPerm_RootPF) {
       Remove-PublicFolderClientPermission -Identity $($RootPF) -User $($PFGlobalOwnersGroup) -AccessRights Owner -Server $Server -ErrorAction SilentlyContinue -Confirm:$False

       $RestorePFPerm_PFConfig = (Get-PublicFolder -identity "$($RestorePFPerm_RootPF)" -Server $Server)
       $RestorePFPerm_FileName = $RestorePFPerm_PFConfig.Identity.tostring().replace("\","_")

       #Import CSV backup of Public Folder Permissions
       $RestorePFPerm_File = (Get-ChildItem $ExpPath | Where-Object {$_.Name -like "$($RestorePFPerm_FileName)*"}).name
       $PFPerm = (Import-Csv -path "$ExpPath\$RestorePFPerm_File")
       
       #Restore Public Folder Permissions
       foreach ($usr in $PFPerm){Add-PublicFolderClientPermission -identity $($RestorePFPerm_RootPF) -User $($Usr.user) -AccessRights $($Usr.AccessRights.split()) -Server $Server -ErrorAction SilentlyContinue}
       
	   #Output the udpate permissions on the Public Folder
       Clear-Host
       Write-Host -ForegroundColor Green "Restored Public Folder Client Permissions for: $($RestorePFPerm_RootPF)"
       Get-PublicFolderClientPermission -identity "$($RestorePFPerm_RootPF)" -server $Server

}
#endregion

#region body
Write-host -ForegroundColor Green "## Hide Public Folder Utility ##"

#Prompt operator for desired action
[int]$act = read-host "`n
1 - Hide Public Folder
2 - Restore Public Folder Permissions

`nPlease enter the number for the function"

switch ($act) {
#Export and Remove all Public Folder Client Permissions
1 {
    Clear-Host
    if ($RootPF -eq $Null -and $PFList -eq $null){[String]$PFList = (Read-Host "Path to Public Folder list")}
    if ((Test-Path $PFlist) -eq $False) {Write-Host -ForegroundColor Red "Invalid Path, please check the path and run the script again"; Exit}
    $list = (Import-CSV -Path $($PFList))
    $i = 0

    Foreach ($Folder in $list){
        Write-Progress -Activity "## Hide Public Folders ##" -Status "Current Folder: $($Folder.Name)" -PercentComplete (($i /$list.count)*100) -id 1
        HidePF $($Folder.Name)
        $i++    
        }
    }
#Restore exported Public Folder permissions
2 {
	Clear-Host
	Write-Host -ForegroundColor Green "## Restore Public Folder Permissions ##"
	
	if ($RootPF -eq $null){$RootPF = (Read-Host "Public Folder to unhide")}
	RestorePFPerm $RootPF
	}
#Invalid Option
default {write-host "Invalid Option.  Script exiting on keystroke..." -foregroundcolor Red;$Host.UI.RawUI.ReadKey() | out-null;Stop-Transcript;exit}
}
#endregion
