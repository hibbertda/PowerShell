
Param (
    # Local folder to store MSP Data Collection 
    [parameter(Position=0, Mandatory=$False)][String]$FolderPath = "C:\MSP Datacollection",
    # Remote location to copy all collection for analysis
    [parameter(Position=1, Mandatory=$False)][String]$CollectionRepository = "C:\MSP Datacollection"
)

Clear-Host
If ($PSBoundParameters["Debug"]) {$DebugPreference = "Continue"}

$ScriptVer = 1


# Check for registry config and create if not present
Switch (Test-Path HKLM:\Software\MSPScripts\DataCollection) {
	$False {
		Write-Debug "Registy settings not found."

        # Create script version registry entries
		New-Item -Path HKLM:\Software\MSPScripts\DataCollection -Force
		New-ItemProperty -Path HKLM:\Software\MSPScripts\DataCollection -Name Version -Value $ScriptVer
        New-ItemProperty -Path HKLM:\Software\MSPScripts\DataCollection -Name FolderPath -Value $FolderPath

		# Add Event Log entry for loffing script actions
		eventcreate /ID 5 /L Application /T Information /SO MSPDataCollector /D "MSP  Data Collection installation started"
	}
	$true {
        Write-Debug "Registy settings found."
        Write-Debug "Script Ver: $((Get-ItemProperty -Path HKLM:\Software\MSPScripts\DataCollection).Version)"
        Write-Debug "Script Ver: $((Get-ItemProperty -Path HKLM:\Software\MSPScripts\DataCollection).FolderPath)"
	}
}

#Check for the capture storage folder
If ((Test-Path $FolderPath) -eq $False){
    Write-Host -ForegroundColor Yellow "Creating Data Collection Folder: " -NoNewline
    Write-Host -ForegroundColor White $FolderPath
    New-Item $FolderPath -Type Directory -force | Out-Null
    New-Item $($FolderPath+"\Scripts") -Type Directory -force | Out-Null
    New-Item $($FolderPath+"\Network Capture") -Type Directory -force | Out-Null
    New-Item $($FolderPath+"\Tasks") -Type Directory -force | Out-Null
}

# Copy files to capture folder

# Copy for scripts for network capture

Copy-Item "./Start-RollingNetworkCapture.ps1" -Destination $($FolderPath+"\Scripts") -Force
Copy-Item "./Stop-RollingNetworkCapture.ps1" -Destination $($FolderPath+"\Scripts") -Force

# Copy task XML
Copy-Item "./STOP MSP Rolling Network Capture.xml" -Destination $($FolderPath+"\Tasks") -Force

## Create Event Trigger scheduled task

# Import Task XML
[xml]$StopNetCapTaskXML = (Get-Content -ReadCount -1 $($FolderPath+"\Tasks\STOP MSP Rolling Network Capture.xml"))

# Update task XML with path to STOP network capture script
$TaskArguments = $StopNetCapTaskXML.task.actions.exec.Arguments.replace("REPLACE", "$($FolderPath+"\Scripts\Stop-RollingNetworkCapture.ps1")")
$StopNetCapTaskXML.task.actions.exec.Arguments = $TaskArguments
Write-Debug $TaskArguments

# Write updates to XML
$StopNetCapTaskXML.save("$($FolderPath+"\Tasks\STOP MSP Rolling Network Capture.xml")")

# Create Scheduled Task
schtasks /create /tn "STOP MSP Rolling Network Capture" /xml $($FolderPath+"\Tasks\STOP MSP Rolling Network Capture.xml")


# reset default debug preference
$DebugPreference = "SilentlyContinue"