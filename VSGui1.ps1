#ERASE ALL THIS AND PUT XAML BELOW between the @" "@ 
$inputXML = @"
<Window x:Class="WpfApplication1.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Public Folder Info" Height="600" Width="1000" ResizeMode="NoResize">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="321*"/>
            <RowDefinition/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="379*"/>
            <ColumnDefinition Width="140*"/>
        </Grid.ColumnDefinitions>
        <TextBlock HorizontalAlignment="Left" Margin="10,10,0,0" TextWrapping="Wrap" Text="This is my super cool GUI app that I am working on. " VerticalAlignment="Top" Height="29" Width="331"/>
        <Button Name="Search" Content="Search" HorizontalAlignment="Left" Margin="305,45,0,0" VerticalAlignment="Top" Width="98" Height="40"/>
        <ListView Name="PFResults" HorizontalAlignment="Left" Height="328" Margin="10,121,0,0" VerticalAlignment="Top" Width="974" Grid.ColumnSpan="2">
            <ListView.View>
                <GridView>
                    <GridViewColumn Header="Name" DisplayMemberBinding ="{Binding Name}" Width ="201" />
                    <GridViewColumn Header="Path" DisplayMemberBinding ="{Binding Path}" Width ="280"/>
                </GridView>
            </ListView.View>
        </ListView>
        <TextBox x:Name="PFServer" HorizontalAlignment="Left" Height="23" Margin="100,44,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="187"/>
        <TextBlock HorizontalAlignment="Left" Margin="19,45,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Height="22" RenderTransformOrigin="0.373,0.636" Width="75"><Run Text="PF Server"/><LineBreak/><Run/></TextBlock>
        <TextBox x:Name="PublicFolder" HorizontalAlignment="Left" Height="23" Margin="100,72,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="187"/>
        <TextBlock HorizontalAlignment="Left" Margin="20,73,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Height="22" RenderTransformOrigin="0.373,0.636" Width="75" Text="Public Folder"/>
        <Button x:Name="FilePath" Content="PATH" HorizontalAlignment="Left" Margin="10,511,0,0" VerticalAlignment="Top" Width="80" Height="20"/>
        <TextBox x:Name="FilePathText" HorizontalAlignment="Left" Height="20" Margin="100,511,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="636" Grid.ColumnSpan="2"/>
        <Button x:Name="Export" Content="Export" HorizontalAlignment="Left" Margin="20.4,511,0,0" VerticalAlignment="Top" Width="98" Height="20" Grid.Column="1"/>
        <TextBlock HorizontalAlignment="Left" Margin="10,479,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Height="27" Width="191" Text="Export results" FontSize="22"/>

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
 
#Get-FormVariables
 
#===========================================================================
# Actually make the objects work
#===========================================================================
$PFListTotal = @()
$Default_ExportPath = $ENV:USERPROFILE+"\Desktop"

$WPF_FilePathText.Text = $Default_ExportPath

Function Get-PFData {
    $PFListTotal = Get-PublicFolder -identity $WPF_PPublicFolder.Text -recurse | Select-Object @{Name='Name';Expression={$_.Name}}, @{Name='Path';Expression={$_.ParentPath}}
    return $PFListTotal
}




$WPF_Search.Add_Click({
    $WPF_PFResults.Items.Clear()
    start-sleep -Milliseconds 840
    Get-PFData | % {$WPF_PFResults.AddChild($_)}
})

#Choose folder to save exported data
$WPF_FilePath.Add_Click({
    $WPF_FilePathText.Clear()
    start-sleep -Milliseconds 500
    
    $app = new-object -com Shell.Application
    $folder = $app.BrowseForFolder(0, "Select Folder", 0, "C:\")
    if ($folder.Self.Path -ne "") {$FilePath= $folder.Self.Path}

    $FilePath
    $WPF_FilePathText.AddText($FilePath)
})

$WPF_Export.Add_Click({
    #$info = Get-PublicFolder -identity $WPF_PPublicFolder.Text -recurse | Select-Object @{Name='Name';Expression={$_.Name}}, @{Name='Path';Expression={$_.ParentPath}}
    #New-Item -ItemType File -Name TestFile -Path $WPF_FilePathText.Text
    
    #$info | Export-CSV -NoTypeInformation -Path $($WPF_FilePathText.Text+"\PFExport.csv")
    $PFListTotal | Export-CSV -NoTypeInformation -Path $($WPF_FilePathText.Text+"\PFExport.csv")
    
    #Launch Explorer to show exported CSV
    explorer $WPF_FilePathText.Text
})
 

# Shows the form
$Form.ShowDialog() | out-null

