Function Language-Repack {

    Param (
        [ValidateSet('Copy','Replace','Recon')]
        [string]$outputType,

        [string]$path = $pwd.path,

        [string]$backupPath = "$path\backup",

        [string]$mkvMergePath = 'F:\mkvtoolnix\mkvmerge.exe',

        [switch]$noSubs
    )

    #Check for executable
    if(!(test-path $mkvMergePath)){
        Write-Warning "Unable to locate mkvmerge.exe!"
        Continue
    }

    #Search for files
    $files = Get-ChildItem -Path $path -Filter *.mkv -Recurse

    #Check for applicable files
    if ($files.Count -lt 1) {
        Write-Warning "No mkv files found!"
        Continue
    }

    #There are files to process if we've made it this far
    if($outputType -eq 'Recon'){

        #Initialize counter
        $badfiles = 0

        #Loop through and process files
        foreach($file in $files){

            #Get file information
            $fileInfo = & $mkvMergePath -J $($file.FullName) | ConvertFrom-Json
    
            #Find Audio and Subtitle Tracks
            [array]$audioTracks = $fileInfo.tracks | Where-Object {$_.type -eq 'audio'}
            [array]$badAudioTracks = $audioTracks | Where-Object {$_.properties.language -ne 'eng'}

            [array]$subtitleTracks = $fileInfo.tracks | Where-Object {$_.type -eq 'subtitles'}
            [array]$badsubtitleTracks = $subtitleTracks | Where-Object {$_.properties.language -ne 'eng'}

            #Display message if bad tracks exist
            if($badAudioTracks.Count -gt 0 -or $badsubtitleTracks.Count -gt 0) {
                $badfiles ++
                Write-Host "$($file.Name) has $($badAudioTracks.Count) bad audio tracks and $($badsubtitleTracks.Count) bad subtitle tracks."
            }
        }

        #Display total info
        Write-Host "Total bad files: $badfiles of $($files.Count)"

    } else {
        
        if($outputType -eq 'Replace'){

            #Test for and create backup dir
            if(!(Test-Path $backupPath)){
                Write-Host "Creating backup directory"
                New-Item $backupPath -ItemType Directory | Out-Null
            }

            Write-Host "Original files will be backed up to $backupPath"

        }

        #Loop through and process files
        foreach($file in $files){
            #Get file information
            $fileInfo = & $mkvMergePath -J $($file.FullName) | ConvertFrom-Json
    
            #Find Audio and Subtitle Tracks
            [array]$audioTracks = $fileInfo.tracks | Where-Object {$_.type -eq 'audio'}
            [array]$badAudioTracks = $audioTracks | Where-Object {$_.properties.language -ne 'eng'}

            [array]$subtitleTracks = $fileInfo.tracks | Where-Object {$_.type -eq 'subtitles'}
            [array]$badsubtitleTracks = $subtitleTracks | Where-Object {$_.properties.language -ne 'eng'}

            #If there's no bad tracks to remove, skip file
            if($badAudioTracks.Count -eq 0 -and $badsubtitleTracks.Count -eq 0) {

                Write-Host "$($file.Name) does not need to be processed. Skipping."
                continue

            } else {

                Write-Host "Processing file: $($file.Name)"

                if($outputType -eq 'Replace'){

                    #Declare variables used for commandline
                    Write-Host "Backing up original file..."
                    $sourceFile = Copy-Item -LiteralPath $file.FullName -Destination $backupPath -Force -PassThru
                    $newFileName = $file.FullName
                    $cmd = "$mkvMergePath -o `"$newFileName`""

                } else {

                    #Declare variables used for commandline
                    $sourceFile = $file.FullName
                    $newFileName = Join-Path $file.DirectoryName $($file.BaseName + '(MKV_REPACK).mkv')
                    $cmd = "$mkvMergePath -o `"$newFileName`""

                }
            }

            #Find tracks to keep
            [array]$audioToCopy = $audioTracks | Where-Object {$_ -notin $badAudioTracks}
            [array]$subtitleToCopy = $subtitleTracks | Where-Object {$_ -notin $badsubtitleTracks}

            #Assuming all files have at least an english track.. filtered before downloading
            #This technically works with files with no english tracks as well, will make this actually nice later
            if($audioToCopy.Count -gt 0){
                $cmd += " -a $($audioToCopy.id -join ',')"
            }

            #If there are multiple audio tracks in english pick the "best" one
            #Best in this case means most channels since Dolby should be at least 5.1(6) and AC-3 is 2
            #I have discovered that this sometimes only works by accident between multiple 6 channel tracks. Oh well. They'll both sound good I guess...
            if($audioToCopy.Count -gt 1){
                $cmd += " --default-track-flag $(($audioToCopy | Sort-Object {$_.properties.audio_channels} -Descending | Select-Object -First 1).id):true"
                $cmd += " -a $($audioToCopy.id -join ',')"
            }

            #Check for english subtitle to keep or remove all
            if($subtitleToCopy.Count -eq 0 -or $noSubs){
                $cmd += ' -S'
            } else {
                $cmd += " -s $($subtitleToCopy.id -join ',')"
            }

            #Append source file
            $cmd += " `"$sourceFile`""

            #Send commands to commandline
            cmd /c $cmd
        }
    }
}
