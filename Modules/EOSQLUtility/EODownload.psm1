<#
    .SYNOPSIS
    Downloads a file using BITS, while displaying a progress bar
    .DESCRIPTION
    Initiates an asynchronous download using BITS and displays an progress bar.
    By default the file is downloaded to the users's Downloads default folder.
    The Source parameter must contain a valid filename. It it does not contain
    the filename, specify the a full path including the filename using the
    Destination parameter.
    .PARAMETER Source
    URL of the file to be downloaded.
    .PARAMETER Destination
    Destination path to download. If the URL contains a filename, this can be a
    directory only. If the URL does not contain a filename, specify it as part
    of the parameter.
#>
function Invoke-BitsTransfer {
    [OutputType([String])]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(
            Mandatory = $true, 
            ValueFromPipeline = $true, 
            ValueFromPipelineByPropertyName = $true
        )]
        [string]
        $Source,
        
        
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]
        # Defaults to Download folder of user
        $Destination = (
            New-Object -ComObject Shell.Application
        ).NameSpace(
            'shell:Downloads'
        ).Self.Path
    )
    BEGIN {
        # Initialize a list to store the BITS jobs as well as the progress
        # bar status.
        # ArrayList is an expandable list, which can hold any type of object.
        $jobs = New-Object -Type System.Collections.ArrayList
    }
    PROCESS {
        # Initiate the BITS transfer for each URL in source
        foreach ($sourceItem in $Source) {
            if ($PSCmdlet.ShouldProcess(
                "BitsTransfer -Source $sourceItem -Destination $Destination",
                'Start',
                "BITS transfer from $sourceItem to $Destination."
            )) {
                try {
                    $bitsJob = Start-BitsTransfer `
                        -Source $sourceItem `
                        -Destination $Destination `
                        -Asynchronous `
                        -ErrorAction Stop

                    # Get resulting local name of download
                    $localName = $bitsJob.FileList[0].LocalName
                    Write-Verbose "Local name of downloaded file: $localName"

                    # Initialize progress calculation

                    $startTime = Get-Date

                    # Initialize progress bar parameters
                    $progress = @{
                        Id = Get-Random
                        Activity = "Downloading from $sourceItem to $localName"
                        Status = $bitsJob.JobState
                        SecondsRemaining = [int32]::MaxValue
                        PercentComplete = -1
                    }

                    # Add job to hash table
                    # The Add returns the position of the inserted object.
                    # We do not need the information, therefore, we redirect
                    # it to $null
                    $jobs.Add(@{
                        bitsJob = $bitsJob
                        progress = $progress
                    }) > $null

                    # Emit the file name to the pipeline
                    $localName
                }
                catch {
                    # If the Throw keyword is used in a Catch block without an 
                    # expression, it throws the current RuntimeException again. See:
                    # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_throw#syntax
                    throw
                }
            }
        }
    }
    END {
        # Here we track the progress of all downloads and display progress bars
        $transferringBitsJobs = $jobs
        # While the BITS jobs are not finished, calculate and write progress
        while ($transferringBitsJobs.Count -gt 0 ) {
            # Get all jobs, which are not finished yet
            $transferringBitsJobs = $jobs |
                Where-Object { $PSItem.bitsJob.JobState -ne 'Transferred' }

            # Get all finished jobs
            $finishedBitsJobs = $jobs |
                Where-Object { $PSItem.bitsJob.JobState -eq 'Transferred' }

            # Update progress bars for unfinished jobs
            foreach ($job in $transferringBitsJobs) {
                # First get the BITS job and the progress
                $bitsJob = $job.bitsJob
                $progress = $job.progress

                #region Calculate progress
                # The ByteTotal are retrieved at each loop, because for some
                # downloads this might change after initialization
                $bytesTotal = $bitsJob.BytesTotal
                $bytesTransferred = $bitsJob.BytesTransferred

                # Time differences can be calculated using TimeSpan objects
                # The TotalSeconds property of a TimeSpan object contains
                # the seconds passed in total.
                $secondsPassed = `
                    (
                        New-TimeSpan -Start $startTime -End (Get-Date)
                    ).TotalSeconds

                # The progress bar needs the percent complete as a number
                # between 0 and 100 instead 0 to 1, therefore we multiply by
                # 100
                $progress.PercentComplete = `
                    $bytesTransferred / $bytesTotal * 100

                # The progress bar needs the seconds remaining as integer
                # Therefore, we use the Round function.
                $secondsRemaining = [System.Math]::Round(
                    $secondsPassed / ($progress.PercentComplete / 100), 0
                )

                # This calculation will result in a speed in bytes/second
                $speed = $bytesTransferred / $secondsPassed
                #endregion

                #region Update progress bar parameters
                # In some cases, e. g. download has not transferred any bytes
                # yet, seconds remaining could be infinite, therefore, we check
                # for that.
                if ($secondsRemaining -le [int]::MaxValue) {
                    $progress.SecondsRemaining = $secondsRemaining
                }

                # MBit/s are displayed with one decimal precision
                # MBit/s are calculated by dividing the bytes/seconds by 1 MB
                # and multiplying it by 8 (assuming that one byte is 8 bits).
                $progress.Status = '{0} {1}/{2} bytes @ {3:n1} Mbit/s' -f `
                    $bitsJob.JobState, `
                    $bytesTransferred, `
                    $bytesTotal, `
                    ($speed / 1MB * 8)
                #endregion
                # Show progress bar
                # @ splats the hash table to the parameters of Write-Progress
                Write-Progress @progress
            }

            # Complete finished jobs
            foreach ($job in ($finishedBitsJobs)) {
                # Get the progress hash table and the BITS job of the
                # finished job
                $progress = $job.progress
                $bitsJob = $job.bitsJob

                # Complete the BITS transfer to remove it from the queue
                Complete-BitsTransfer -BitsJob $bitsJob

                # Hide progress bar by calling it with the Completed switch
                Write-Progress @progress -Completed

                # Remove the job from our list, so it does not need to be
                # processed anymore
                $jobs.Remove($job)
            }

            # Sleep for 1 second to smoothen the display of the downloaded
            # bytes.
            Start-Sleep -Seconds 1         
        }
    }
}