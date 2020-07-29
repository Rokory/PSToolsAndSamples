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
                        -Confirm:$false `
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
        # While the BITS jobs are not finished, calculate and write progress
        while ((
            $jobs.bitsJob | 
            Where-Object {$PSItem.JobState -ne 'Transferred'}
        ).Count -gt 0 ) {
            foreach ($job in $jobs) {
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

                # If job is not transferred, show progress bar
                if ($job.bitsJob.JobState -ne 'Transferred') {
                    # @ splats the hash table to the parameters of Write-Progress
                    Write-Progress @progress
                }

                # If job is transferred, remove progress bar and job
                if ($job.bitsJob.JobState -eq 'Transferred') {

                    # Hide progress bar by calling it with the Completed switch
                    Write-Progress @progress -Completed

                }
            }

            # Sleep for 1 second to smoothen the display of the downloaded
            # bytes.
            Start-Sleep -Seconds 1         
        }
        # Complete the BITS transfers to remove it from the queue
        $jobs.bitsJob | Complete-BitsTransfer -Confirm:$false
    }
}