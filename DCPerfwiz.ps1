Param (
[int]$Interval = 30,
[int]$maxsize = 512,
[DateTime]$StartDate,
[DateTime]$EndDate,
[int]$Duration = "8",
[String]$FilePath = "C:\PerfLogs",
[Switch]$DeleteCollectorSet,
#[switch]$circular, - NOT IMPLEMENTED
#[switch]$threads,  - NOT IMPLEMENTED
[Array]$Servers
)

#Import required modules
#Try {Import-Module ActiveDirectory -ErrorAction stop}
#Catch {Write-Host -ForegroundColor Yellow "Unable to load Active Directory Module"; Exit}

#Global Variables
$CollectionName = "GC_PerfWiz"
$DCList = @()


#region GUI
#ERASE ALL THIS AND PUT XAML BELOW between the @" "@ 
$inputXML = @"
<Window x:Name="MSP_Perfwiz" x:Class="DC_PerfWizGui.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="MSP Perfwiz" Height="350" Width="400" ResizeMode="NoResize">
    <Grid>
        <TabControl HorizontalAlignment="Left" Height="301" Margin="10,10,0,0" VerticalAlignment="Top" Width="374">
            <TabItem x:Name="GeneralTab" Header="General" Width="51.2">
                <Grid Background="#FFE5E5E5" Margin="0,0,5.8,-0.2">
                    <TextBox x:Name="ADSite" HorizontalAlignment="Left" Height="23" Margin="10,41,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="131"/>
                    <TextBlock HorizontalAlignment="Left" Margin="10,20,0,0" TextWrapping="Wrap" Text="Active Directory Site" VerticalAlignment="Top" Width="131"/>
                    <Button x:Name="CreateCollection" Content="Create" HorizontalAlignment="Left" Margin="10,244,0,0" VerticalAlignment="Top" Width="75"/>
                    <TextBlock HorizontalAlignment="Left" Margin="10,95,0,0" TextWrapping="Wrap" Text="Start Date" VerticalAlignment="Top" Width="145"/>
                    <TextBox x:Name="Collection_Duration" HorizontalAlignment="Left" Height="23" Margin="10,175,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="120" ToolTip="Number of hours to run collection. Example: 8 hours '08:00:00'"/>
                    <TextBlock HorizontalAlignment="Left" Margin="10,154,0,0" TextWrapping="Wrap" Text="Collection Duration" VerticalAlignment="Top" Width="120"/>
                    <Button x:Name="ADSite_Set" Content="Set" HorizontalAlignment="Left" Margin="10,69,0,0" VerticalAlignment="Top" Width="75"/>
                    <TextBlock HorizontalAlignment="Left" Margin="160,23,0,0" TextWrapping="Wrap" Text="Targeted Domain Controllers" VerticalAlignment="Top" Width="193"/>
                    <ListView x:Name="DCList" HorizontalAlignment="Left" Height="86" Margin="160,44,0,0" VerticalAlignment="Top" Width="193">
                        <ListView.View>
                            <GridView>
                                <GridViewColumn Header="FQDN" DisplayMemberBinding ="{Binding FQDN}"/>
                            </GridView>
                        </ListView.View>
                    </ListView>
                    <TextBox x:Name="StartDate_Text" HorizontalAlignment="Left" Height="23" Margin="10,116,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="120" ToolTip=""/>
                </Grid>
            </TabItem>
            <TabItem x:Name="ConfigTab" Header="Config">
                <Grid Background="#FFE5E5E5">
                    <TextBox x:Name="FilePathText" HorizontalAlignment="Left" Height="23" Margin="10,83,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="120" ToolTip="Path to store data collection"/>
                    <TextBlock x:Name="FilePath" HorizontalAlignment="Left" Margin="10,62,0,0" TextWrapping="Wrap" Text="Collection Interval" VerticalAlignment="Top" Width="120"/>
                </Grid>
            </TabItem>
        </TabControl>

    </Grid>
</Window>
"@       

$inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N'  -replace '^<Win.*', '<Window'
 
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML
#Read XAML
 
$reader=(New-Object System.Xml.XmlNodeReader $xaml) 
try{$Form=[Windows.Markup.XamlReader]::Load( $reader )}
catch{Write-Host "Unable to load Windows.Markup.XamlReader. Double-check syntax and ensure .net is installed."}
 
#===========================================================================
# Load XAML Objects In PowerShell
#===========================================================================
 
$xaml.SelectNodes("//*[@Name]") | %{Set-Variable -Name "WPF_$($_.Name)" -Value $Form.FindName($_.Name)}
 
Function Get-FormVariables{
if ($global:ReadmeDisplay -ne $true){Write-host "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Yellow;$global:ReadmeDisplay=$true}
write-host "Found the following interactable elements from our form" -ForegroundColor Cyan
get-variable WPF*
}
 
Get-FormVariables

#endregion

#Set GUI Defaults

$WPF_FilePathText.text = $FilePath
$WPF_Collection_Duration.Text = $Duration

#Function: CounterSetup - Package desired counters into a config file for Logman
Function CounterSetup {
    if ((Test-Path $ConfigPath) -eq $False) {
        Try {New-Item $ConfigPath -Type Directory -force -ErrorAction Stop | Out-Null}
        Catch {Write-Host ""; Write-Warning "Invalid path for Config File. Check the file path is accesable and re-run the script."; exit}
    }


    #General Windows Counters
    $Windows_Counters = @(
        "Process(*)\*"
        "Processor(*)\*"
        "Processor Performance(*)\*"
        "Memory\*"
        "System\Processor Queue Length"
        "Network Interface\Bytes Total/sec"
        "Network Interface\Packets Outbound Errors"
        "PhysicalDisk\Average Disk sec/Read"
        "PhysicalDisk\Average Disk sec/Write"
    )

    #Global Catalog Counters
    $GC_Counters = @(
        "DirectoryServices(*)\*"
        "PhysicalDisk(NTDS Database Disk)\Average Disk sec/Read"
        "PhysicalDisk(NTDS Database Disk)\Average Disk sec/Write"
        "PhysicalDisk(NTDS Log Disk)\Average Disk sec/Read"
        "PhysicalDisk(NTDS Log Disk)\Average Disk sec/Write"
        "PhysicalDisk(NTDS Database or Log Disks)\Average Disk Queue Length"
    )
    #Output counters to configuration file

    $IncludeCounters = @($Windows_Counters + $GC_Counters)

    Write-Debug "Writing Counter Config file to disk"
    Out-File -FilePath "$ConfigFile" -InputObject $IncludeCounters -Force -Encoding "ascii"
}
#endregion

#region mainbody

#Identify target Active Directory Site and collect requred information.
# Results of DCs found will be displayed in the GUI form. 
$WPF_ADSite_Set.Add_Click({
    #Clear any existing items from listview
    $DClist = @()
    $WPF_DCList.items.Clear()
    Start-Sleep -Milliseconds 500

    #Discover all of the domain controllers in the specified Active Directory Site
    $SiteDCList = (Get-ADDomainController -Discover -SiteName $($WPF_ADSite.Text))

    #Loop through each DC and collect required information
    foreach ($i in $SiteDCList) {
        $TempDC = (Get-ADDomainController $i.name)
        $TempObj = (
            New-Object PSObject -Property @{
                Name = $TempDC.Name
                FQDN = $TempDC.HostName
                Domain = $TempDC.Domain
                })
        $DClist += $TempObj
        $DClist | Select-Object FQDN | foreach {$WPF_DCList.AddChild($_)}
    }
})

$WPF_CreateCollection.Add_Click({

    $StDate = (Get-Date $WPF_StartDate_Text.text)
    $StartDate = (Get-Date $StDate.adddays(1) -Hour 05 -Minute 00 -Second 00)
    $EndDate = $StartDate.AddHours($Duration)
 
    
    $commandString = "logman create counter -n $CollectionName -cf ./GC_Perfwiz.config -s DC01.hbl.hibblabs.org -f bin -cnf 0 -v MMDDHHMM -max $MaxSize -si $interval -b $StartDate -e $EndDate -o ./Cap01"
    #$CreateCounter = 
    Invoke-Expression -command $commandString

    #$Form.close()

})

# Shows the form
$Form.ShowDialog() | out-null

#endregion
