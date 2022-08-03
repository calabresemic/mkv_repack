#Declare required executables
$mkvMerge_exe = 'F:\mkvtoolnix\mkvmerge.exe'

#Check for executable
if(!(test-path $mkvMerge_exe)){
    Write-Warning "Unable to locate mkvmerge.exe!"
    pause
    exit
}

#Search for files
$files = Get-ChildItem *.mkv -Recurse

#Check for applicable files
if ($files.Count -lt 1) {
    Write-Warning "No mkv files found!"
    pause
    exit
}

#Loop through and process files
foreach($file in $files){
    #Get file information
    $fileInfo = & $mkvMerge_exe -J $($file.FullName) | ConvertFrom-Json
    
    #Find Audio and Subtitle Tracks
    [array]$audioTracks = $fileInfo.tracks | Where-Object {$_.type -eq 'audio'}
    [array]$subtitleTracks = $fileInfo.tracks | Where-Object {$_.type -eq 'subtitles'}

    #If there's no tracks to remove, skip file
    if($audioTracks.Count -lt 2 -and $subtitleTracks.Count -lt 2) {
        Write-Host "$($file.Name) does not need to be processed. Skipping."
        continue
    } else {
        Write-Host "Processing file: $($file.Name)"
    }

    #Find tracks to keep
    [array]$audioToCopy = $audioTracks | Where-Object {$_.properties.language -eq 'eng'}
    [array]$subtitleToCopy = $subtitleTracks | Where-Object {$_.properties.language -eq 'eng'}
    

    #Declare variables used for commandline
    $newFileName = Join-Path $file.DirectoryName $($file.BaseName + '(MKV_REPACK).mkv')
    #$newFileName = $file.FullName + '.temp'
    $sourceFile = $file.FullName
    $cmd = "$mkvMerge_exe -o `"$newFileName`""
    
    #Assuming all files have at least an english track.. filtered before downloading
    if($audioToCopy.Count -gt 0){
        $cmd += " -a $($audioToCopy.id -join ',')"
    }

    #Check for english subtitle to keep or declare keeping none
    if($subtitleToCopy.Count -gt 0){
        $cmd += " -s $($subtitleToCopy.id -join ',')"
    } else {
        $cmd += ' -S'
    }

    #Append source file
    $cmd += " `"$sourceFile`""

    #Send commands to commandline
    cmd /c $cmd
}
