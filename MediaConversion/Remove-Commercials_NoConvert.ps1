Param (
	# Full path to search (Defaults to TV)
	[parameter(Position=0, Mandatory=$false)][ValidateScript({Test-Path $_ })][String]$MediaPath = "\\nas.thehibbs.net\Media\TV",
    # Pre-delete folder to move original media files
    [parameter(Position=1, Mandatory=$False)][ValidateScript({Test-Path $_ })][String]$PreDeleteDir = "\\nas.thehibbs.net\media\pre-delete",
    # Number of days to search back (Default 2)
    [parameter(Position=2, Mandatory=$False)][int]$DaysToSearch = -2,
    # Do not move files, for testing
    [parameter(Position=3, Mandatory=$False)][bool]$TestProcess = $False,
    # Size reduction threshold to keep comskip
    [parameter(Position=4, Mandatory=$False)][int]$ComSkipSizeThreshold = .5
)

# set debug
If ($PSBoundParameters["Debug"]) {$DebugPreference = "Continue"}

# Local temp working directory
$local_Temp = "$ENV:USERPROFILE\transcode"
New-Item -ItemType Directory -Path $local_Temp -Force | Out-Null 

Write-Debug "Media Path: $MediaPath"
Write-Debug "Pre-Delete Directory: $PreDeleteDir"
Write-Debug "Days to search back: $DaysToSearch"

# Search for '.ts' files to process
$RecentRecordings = Get-ChildItem $MediaPath -Recurse `
    | Where-Object {$_.name -like "*.ts" -and $_.name -notlike "*_cs.*" -and $_.LastWriteTime -gt $(Get-date).AddDays($DaysToSearch)} `
    | Sort-Object lastwritetime -Descending #| Select-Object name, fullname, Length

Write-Debug "Found [$($RecentRecordings.count)] recording to process"

$Completed_video = @() # list of videos that completed
$Problem_Video = @() # list of videos that had problems and weren't fully processed

# Process all discovered recordings
foreach ($vid in $RecentRecordings){
    
    Write-Debug "Processing file: $($vid.name)"

    # Generate random folder/name to store each file and artifacts
    ##$vid_temp_directory = $local_Temp+"\"+$(Get-Random -SetSeed $vid.length)
    ##try {$vid_temp_directory = $local_Temp+"\"+$((Get-FileHash $vid.fullname -Algorithm md5 -ErrorAction Stop).hash)}
    try {$vid_temp_directory = $local_Temp+"\"+$($vid.name.replace('.','_'))}
    catch {
        Write-Error -Message "Unable to generate hash to create working directory"

        $obj = New-Object psobject -Property @{
            FileName = $vid.fullname
            Error = "Unable to create directory -- HASH"
            #ErrorDetail = $_
        }

        $Problem_Video += $obj
        continue
    }
    Write-Debug "Creating temp directory: $vid_temp_directory"
    New-Item $vid_temp_directory -ItemType Directory -Force | out-null
    
    # create directory to put the comskip cut segements
    $comskip_segement_directory = ($vid_temp_directory+"\segements")
    Write-Debug "Creating Segement Directory: $comskip_segement_directory"
    New-Item $comskip_segement_directory -ItemType Directory -Force | out-null

    # create completed directory
    $completed_directory = ($vid_temp_directory+"\completed")
    Write-Debug "Creating Completed Directory:  $completed_directory"
    New-Item $completed_directory -ItemType Directory -Force | out-null

    # Copy media file to local machine
    $DestinationName = $vid_temp_directory+"\"+$vid.name
    Write-Debug "Making local copy of: $($vid.name)"
    $original_copy = Measure-Command {Copy-Item -Path $vid.fullname -Destination $DestinationName}
    Write-Debug "[$original_copy.seconds] to copy file"

    # Remove commercials
    Write-Debug "Starting commercial removal"
    $TTC_ComSkip = Measure-Command {}

    #region comskip
    # run comskip against the local copy of the media file
    C:\Users\Hibbe\Documents\_media\comskip\comskip.exe $DestinationName #-ini="C:\Users\Hibbe\Documents\_media\comskip\comskip.ini"

    # find path to comskip EDL file
    $comskip_edl_path = Get-ChildItem -path $($vid_temp_directory+"\*") -Include "*.edl" | Select-Object Name, FullName, length
    Write-Debug "[EDL filename] $($comskip_edl_path.name)"

    # import comskip EDL
    $comskip_edl_import = [string](Get-Content $comskip_edl_path.fullname)
    Write-Debug "[EDL Content] $comskip_edl_import"
    $comskip_edl = $comskip_edl_import -split '\s+|\t+' | foreach {if ($_ -notlike "0*"){$_}}
    Write-Debug "Found [$($comskip_edl.count)] segements."

    # Process comskip EDL
    $st = 0     # starting point
    $en = 1     # ending point
    $ittr = 1   # loop itteration
    $segement_cut_list = @()  # empty array for segment cut list

    do { 
        $obj = New-Object PSObject -Property @{
            Segnum = $ittr
            Start = $comskip_edl[$st]
            "End" = $comskip_edl[$en]
            Dur = $comskip_edl[$en]-$comskip_edl[$st] # compute the cut durration be subtracting the start of the current set and the end of the next
            segmentname = "segement-$($ittr).ts" # generate the segment name
        }

        if ($obj.end -eq $null){
            # send end and dur for last segement to 0. FFMPEG will capture the remainder of the file
            $obj.end = 0
            $obj.dur = 0
        }
        # add cut 
        $segement_cut_list += $obj

        # increment counters
        $st += 2
        $en += 2
        $ittr++
    }
    # end the loop when the end count is gt/eq to the total count of segements
    while ($st -lt $comskip_edl.count)

    # cut segements from the video
    foreach ($cut in $segement_cut_list){
        if ($cut.Dur -eq 0){C:\Users\Hibbe\Documents\_media\ffmpeg\bin\ffmpeg.exe -i $DestinationName -ss $cut.start -c copy $($comskip_segement_directory+"\"+$($cut.segmentname))}
        else {C:\Users\Hibbe\Documents\_media\ffmpeg\bin\ffmpeg.exe -i $DestinationName -ss $cut.start -t $cut.dur -c copy $($comskip_segement_directory+"\"+$($cut.segmentname))}
    }

    # generate segement cut list for ffmpeg concat
    $segment_text = $comskip_segement_directory+"\segments.txt"
    $("# Segment File : $($vid.name)") | out-file -FilePath $segment_text -Encoding ascii
    Get-ChildItem $comskip_segement_directory | Where-Object {$_.name -like "*.ts"} `
        | Sort-Object name | ForEach-Object {$("file '"+$_.fullname+"'").tostring() `
        | out-file -FilePath $segment_text -Append -Encoding ascii }

    # Concat segements
    Write-Debug "Starting joining segements together."
    $Concat_file = $vid.name.replace('.ts','_cs.ts')
    #C:\Users\Hibbe\Documents\_media\ffmpeg\bin\ffmpeg.exe -f concat -safe 0 -i $segment_text -c copy $($comskip_segement_directory+"\"+$Concat_file)
    C:\Users\Hibbe\Documents\_media\ffmpeg\bin\ffmpeg.exe -f concat -safe 0 -i $segment_text -c copy $($comskip_segement_directory+"\"+$Concat_file)


    # Check the size of the comskip'd file. if more than 20% smaller stop processing
    Clear-Host
    $original_File_Size = (Get-ChildItem $DestinationName).Length
    Write-Debug "Original file size:  $original_File_Size"
    $ComSkip_File_Size = (Get-ChildItem $($comskip_segement_directory+"\"+$Concat_file)).length
    Write-Debug "File size after ComSkip: $ComSkip_File_Size" 
    $File_Size_Precentage = ($original_File_Size - ($original_File_Size * .5))

    Write-Host -ForegroundColor Green "Checking for filesize sanity..."

    $difference = ($original_File_Size - $ComSkip_File_Size)
    if ($ComSkip_File_Size -lt $File_Size_Precentage){
        Write-Host -ForegroundColor red "File size looks bad"
                Write-Error -Message "Unable to generate hash to create working directory"

        $obj = New-Object psobject -Property @{
            FileName = $vid.fullname
            Error = "FileSize looks too small"
            #ErrorDetail = $_
        }

        $Problem_Video += $obj
        continue; 
    }
    else {Write-Host -ForegroundColor green "File size looks good!!!"}

    #endregion
         
    ## Convert video
    # destination file
    #$Completed_File = $completed_directory+"\"+$($vid.name.replace('.ts','_cs.mp4'))
    
    # Convert file from MPEG(.ts) to H264(mp4)
    #C:\Users\Hibbe\Documents\_media\ffmpeg\bin\ffmpeg.exe -i $($comskip_segement_directory+"\"+$Concat_file) -crf 0 -acodec copy -vcodec h264_nvenc $Completed_File
    #C:\Users\Hibbe\Documents\_media\ffmpeg\bin\ffmpeg.exe -hwaccel cuvid -i $($comskip_segement_directory+"\"+$Concat_file) -vf scale_npp=1280:720 -c:v h264_nvenc $Completed_File

    #C:\Users\Hibbe\Documents\_media\ffmpeg\bin\ffmpeg.exe -i $($comskip_segement_directory+"\"+$Concat_file) -crf 18 -map 0 -c:v h264 $Completed_File

    ## Move Completed file to original NAS directory
    # If testprocess = $True don't move any files
    if (!$TestProcess){
        $Original_file_directory = $vid.fullname.Substring(0,$($vid.fullname.LastIndexOf('\')))+"\"
        Write-Debug "Completed destination: $Original_file_directory"
        Move-Item $($comskip_segement_directory+"\"+$Concat_file) -Destination $Original_file_directory -Verbose

        # Move original file to pre-delete directory
        Move-item $vid.fullname -Destination $PreDeleteDir

        # Clean up temp directory
        #Remove-Item -Path $vid_temp_directory -Force -Recurse -Confirm:$False | Out-Null
    }

    $obj = New-Object psobject -Property @{
        FileName = $vid.name
        Path = $vid.fullname
        NewFileName = $Completed_File
    }

    $Completed_video += $obj
}

Write-Host -ForegroundColor Green "Completed Files:"
$Completed_video

Write-Host -ForegroundColor yellow "Problem Files:"
$Problem_Video