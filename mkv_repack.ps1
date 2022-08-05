Function Language-Repack {

    [CmdletBinding()]
    Param (
        [ValidateSet('Copy','Replace','Recon')]
        [string]$outputType,

        [string]$path,

        [string]$backupPath = "$path\backup",

        [string]$mkvMergePath = 'F:\mkvtoolnix\mkvmerge.exe',

        [switch]$NoSubs
    )

    #Validate executable
    try{  $mkvVersion = & $mkvMergePath --version  }
    catch{  $mkvVersion = $null  }

    if($mkvVersion -notlike 'mkvmerge*'){
        
        #This isn't a valid mkvmerge binary
        Write-Warning "Unable to validate mkvmerge.exe! Halting."
        Continue

    } else {
        
        #Valid binary show version if running verbose
        Write-Verbose "$mkvVersion"

    }

    #Search for files
    Write-Host "Searching for files in $path"
    [array]$files = Get-ChildItem -Path $path -Filter *.mkv -Recurse

    #Check for applicable files
    if ($files.Count -lt 1) {

        Write-Warning "No .mkv files found! Halting."
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
                    Write-Host "$($file.Name) has no English audio tracks and $($unwantedSubtitleTracks.Count) unwanted subtitle track(s)."
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
            Write-Host ""

        }

        #Initialize the JSON output
        $resultsJSON = [pscustomObject]@{
            Date = (Get-Date).ToString()
            Operation = $outputType
            Path = $path
            TotalSizeChanged = [string]0
            Results = @()
        }

        [double]$totalSizeChanged = 0

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
                Continue

            } else {

                Write-Host "Processing file: $($file.Name)"

                #Calculate Original File Size
                $originalFileSize = [string]::Format("{0:0.00} MB",$file.Length/1MB)
                Write-Verbose "Original File Size: $originalFileSize"

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
                
                [array]$removedAudioTracks = $unwantedAudioTracks | Select-Object codec,id,@{N='Track Name';E={$_.properties.track_name}},@{N='Language';E={$_.properties.language}},@{N='Default Track';E={$_.properties.default_track}}
                Write-Verbose "Removing $($removedAudioTracks.Count) audio tracks."
                $cmd += " -a $($audioToCopy.id -join ',')"

            } else {
                
                #Foreign Film, adjust the output for results
                $removedAudioTracks = 'N/A'
                Write-Verbose "Not removing any audio tracks."

            }

            #If there are multiple audio tracks in english pick the "best" one
            #Best in this case means most channels since Dolby should be at least 6 and AC-3 is 2
            #I have discovered that this sometimes only works by accident between multiple 6 channel tracks. Oh well. They'll both sound good I guess...
            if($audioToCopy.Count -gt 1){

                $defaultTrack = $audioToCopy | Sort-Object {$_.properties.audio_channels} -Descending | Select-Object -First 1
                Write-Verbose "Setting default audio track to: $($defaultTrack.properties.track_name)"
                $cmd += " --default-track-flag $($defaultTrack.id):true"
                
            }

            #Check for english subtitle to keep or remove all
            if($subtitleToCopy.Count -eq 0 -or $noSubs){

                $cmd += ' -S'

            } else {

                $cmd += " -s $($subtitleToCopy.id -join ',')"
            
            }

            [array]$removedSubtitleTracks = $subtitleTracks | Select-Object codec,id,@{N='Track Name';E={$_.properties.track_name}},@{N='Language';E={$_.properties.language}}
            Write-Verbose "Removing $($removedSubtitleTracks.Count) subtitle tracks."

            #Append source file
            $cmd += " `"$sourceFile`""

            #Send commands to commandline
            Write-Verbose "$cmd"
            cmd /c $cmd

            #Calculate New File Size
            $newFileSize = [string]::Format("{0:0.00} MB",(Get-Item -LiteralPath $newFileName).Length/1MB)
            Write-Verbose "New File Size: $newFileSize"
            $sizeChanged = [double]$newFileSize.Replace(' MB','') - [double]$originalFileSize.Replace(' MB','')
            Write-Verbose "Size changed: $([string]::Format("{0:0.00} MB",$sizeChanged))"
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

        #Update total size changed result in JSON
        $totalSizeChangedString = [string]::Format("{0:0.00} MB",$totalSizeChanged)
        $resultsJSON.TotalSizeChanged = $totalSizeChangedString

        Write-Verbose "Operation resulted in a net of $totalSizeChangedString"
        Write-Host "Saving results file"

        $resultsJSON | ConvertTo-Json | Out-File "$backupPath\mkv_repack_results.json" -Force
    }
}
