<#
.NOTES

.SYNOPSIS

.DESCRIPTION
    This script is used to stop MSP automated rolling network captures. The scipt is intended to be ran with an Event Trigger to aid
    in the troubleshooting of network issues. 
  
.PARAMETER RestartCapture
	Used to disable automatic restart of the rolling capture. 
#>

Param (
    #Parameter to control automatic restart of rolling network capture. 
    [parameter(Position=0, Mandatory=$False)][Bool]$RestartCapture = $True
)

[string]$MachineName = ((get-wmiobject "Win32_ComputerSystem").Name)
[int]$ScriptVer = 1

#Read folder path for data collection from registry
try {
    # Check MSP Collection Version Number
    [int]$MSPCollectorVersion = $((Get-ItemProperty -Path HKLM:\Software\MSPScripts\DataCollection -ErrorAction Stop).Version)
    # Check MSP Collection Directory Path
    [String]$MSPCollectorPath = $((Get-ItemProperty -Path HKLM:\Software\MSPScripts\DataCollection -ErrorAction Stop).FolderPath)
}
Catch {
    $text = ("MSP Data Collector config not found.`n $($_)`nRun MSP Data Collector setup and attempt to rerun this script.")
	$a = new-object -comobject wscript.shell
	$b = $a.popup("$text",0,"$popup_label",0+48)

    Exit
}

if ($ScriptVer -lt $MSPCollectorVersion){
    ## DO Something
}

#Start rolling network capture
$Netsh_Status = (netsh trace stop)

# Write Event Log entry
$Message = "MSP Rolling network capture stoped. `n`n$Netsh_Status"
$EventID = "5"
Write-EventLog -ComputerName $Machinename -Logname Application -Source MSPDataCollector -EventId $EventID -Message $Message -Category 2

# Restart the rolling capture

Switch ($RestartCapture){
    $True {
        & $($MSPCollectorPath+"\Scripts\Start-RollingNetworkCapture.ps1 -AutoRestart")
    }
    $False {
        # Write Event Log entry
        $Message = "Rolling network capture not automatically started."
        $EventID = "5"
        Write-EventLog -ComputerName $Machinename -Logname Application -Source MSPDataCollector -EventId $EventID -Message $Message -Category 3
    }
}

