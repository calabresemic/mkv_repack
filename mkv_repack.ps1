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
    Write-Host "Searching for files in $path"
    [array]$files = Get-ChildItem -Path $path -Filter *.mkv -Recurse

    #Check for applicable files
    if ($files.Count -lt 1) {
        Write-Warning "No .mkv files found!"
        Continue
    }

    #There are files to process if we've made it this far
    Write-Host "$($files.count) .mkv files found!"
    Write-Host ""
    

    if($outputType -eq 'Recon'){

        #Initialize counter
        $badFiles = 0

        #Loop through and process files
        foreach($file in $files){

            #Get file information
            $fileInfo = & $mkvMergePath -J $($file.FullName) | ConvertFrom-Json
    
            #Find Audio and Subtitle Tracks
            [array]$audioTracks = $fileInfo.tracks | Where-Object {$_.type -eq 'audio'}
            [array]$unwantedAudioTracks = $audioTracks | Where-Object {$_.properties.language -ne 'eng'}

            [array]$subtitleTracks = $fileInfo.tracks | Where-Object {$_.type -eq 'subtitles'}
            [array]$unwantedSubtitleTracks = $subtitleTracks | Where-Object {$_.properties.language -ne 'eng'}

            #Display message if unwanted tracks exist
            if($unwantedAudioTracks.Count -eq $audioTracks.Count){
                
                #Foreign film, ignore audio tracks.
                if($unwantedSubtitleTracks.Count -gt 0) {
                    $badFiles ++
                    Write-Host "$($file.Name) has 0 unwanted audio track(s) and $($unwantedSubtitleTracks.Count) unwanted subtitle track(s)."
                }

            } else {
            
                #Display message if unwanted tracks exist
                if($unwantedAudioTracks.Count -gt 0 -or $unwantedSubtitleTracks.Count -gt 0) {
                    $badFiles ++
                    Write-Host "$($file.Name) has $($unwantedAudioTracks.Count) unwanted audio track(s) and $($unwantedSubtitleTracks.Count) unwanted subtitle track(s)."
                }

            }
        }

        #Display total info
        Write-Host ""
        Write-Host "Total files with bad tracks: $badFiles of $($files.Count)"

    } else {
        
        if($outputType -eq 'Replace'){

            #Test for and create backup dir
            if(!(Test-Path $backupPath)){
                Write-Host "Creating backup directory"
                New-Item $backupPath -ItemType Directory | Out-Null
            }

            Write-Host "Original files will be backed up to $backupPath"

        }

        [double]$totalSizeChanged = 0
        $resultsJSON = [pscustomObject]@{
            Date = Get-Date
            Operation = $outputType
            Path = $path
            Results = @()
        }

        #Loop through and process files
        foreach($file in $files){

            #Get file information
            $fileInfo = & $mkvMergePath -J $($file.FullName) | ConvertFrom-Json
    
            #Find Audio and Subtitle Tracks
            [array]$audioTracks = $fileInfo.tracks | Where-Object {$_.type -eq 'audio'}
            [array]$unwantedAudioTracks = $audioTracks | Where-Object {$_.properties.language -ne 'eng'}

            [array]$subtitleTracks = $fileInfo.tracks | Where-Object {$_.type -eq 'subtitles'}
            [array]$unwantedSubtitleTracks = $subtitleTracks | Where-Object {$_.properties.language -ne 'eng'}

            #If there's no unwanted tracks to remove, skip file
            if($unwantedAudioTracks.Count -eq 0 -and $unwantedSubtitleTracks.Count -eq 0) {

                Write-Host "$($file.Name) does not need to be processed. Skipping."
                continue

            } else {

                Write-Host "Processing file: $($file.Name)"

                #Calculate Original File Size
                $originalFileSize = [string]::Format("{0:0.00} MB",$file.Length/1MB)

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
            [array]$audioToCopy = $audioTracks | Where-Object {$_ -notin $unwantedAudioTracks}
            [array]$subtitleToCopy = $subtitleTracks | Where-Object {$_ -notin $unwantedSubtitleTracks}

            #If no english tracks exist (foreign film) this will just not add the -a param and will default to copying all.
            if($audioToCopy.Count -gt 0){
                
                $cmd += " -a $($audioToCopy.id -join ',')"
                [array]$removedAudioTracks = $unwantedAudioTracks

            } else {
                
                #Foreign Film, adjust the output for results
                $removedAudioTracks = @()

            }

            #If there are multiple audio tracks in english pick the "best" one
            #Best in this case means most channels since Dolby should be at least 6 and AC-3 is 2
            #I have discovered that this sometimes only works by accident between multiple 6 channel tracks. Oh well. They'll both sound good I guess...
            if($audioToCopy.Count -gt 1){
                $cmd += " --default-track-flag $(($audioToCopy | Sort-Object {$_.properties.audio_channels} -Descending | Select-Object -First 1).id):true"
            }

            #Check for english subtitle to keep or remove all
            if($subtitleToCopy.Count -eq 0 -or $noSubs){

                $cmd += ' -S'
                [array]$removedSubtitleTracks = $subtitleTracks

            } else {

                $cmd += " -s $($subtitleToCopy.id -join ',')"
                [array]$removedSubtitleTracks = $unwantedSubtitleTracks
            
            }

            #Append source file
            $cmd += " `"$sourceFile`""

            #Send commands to commandline
            cmd /c $cmd

            #Calculate New File Size
            $newFileSize = [string]::Format("{0:0.00} MB",(Get-Item -LiteralPath $newFileName).Length/1MB)
            $sizeChanged = [double]$newFileSize.Replace(' MB','') - [double]$originalFileSize.Replace(' MB','')
            $totalSizeChanged += $sizeChanged

            $resultEntry = [pscustomobject]@{
                FileName = $file.Name
                OriginalSize = $originalFileSize
                NewFile = $newFileName
                NewFileSize = $newFileSize
                AudioTracksRemoved = $removedAudioTracks
                SubtitleTracksRemoved = $removedSubtitleTracks
                SizeChange = [string]$sizeChanged + ' MB'
            }

            $resultsJSON.Results += $resultEntry
        }

        Write-Host "Operation resulted in a net of $totalSizeChanged MBs"
        Write-Host "Saving results file"
        $resultsJSON | ConvertTo-Json | Out-File "$backupPath\mkv_repack_results.json" -Force
    }
}
