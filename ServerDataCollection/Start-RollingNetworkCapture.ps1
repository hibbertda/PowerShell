
Param (
	[parameter(Position=1, Mandatory=$False)][Switch]$AutoRestart
)

[string]$MachineName = ((get-wmiobject "Win32_ComputerSystem").Name)
[String]$DateTime = (Get-Date -Format yyyyMMdd-hhmm)

$CaputreFileName = $((Get-ItemProperty -Path HKLM:\Software\MSPScripts\DataCollection).FolderPath)+"\Network Capture\"+$MachineName+"_Network Capture_"+$DateTime+".etl"

# Write Event Log entry

If ($PSBoundParameters["AutoRestart"]) {
    $Message = "[Automatic Capture Restart]`n`nMSP Rolling network capture started. `nCapture file: $CaputreFileName"
}
Else {
    $Message = "MSP Rolling network capture started. `nCapture file: $CaputreFileName"
}
$EventID = "5"

Write-EventLog -ComputerName $Machinename -Logname Application -Source MSPDataCollector -EventId $EventID -Message $Message -Category 1

#Start rolling network capture
netsh trace start capture=yes scenario=lan,ndis tracefile=$CaputreFileName