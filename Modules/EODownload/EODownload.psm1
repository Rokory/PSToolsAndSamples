<#
    .SYNOPSIS
    Downloads a file using BITS, while displaying a progress bar
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

    if ($PSCmdlet.ShouldProcess(
        "Starting BITS transfer from $Source to $Destination."
    )) {
        try {
            $bitsJob = Start-BitsTransfer `
                -Source $Source `
                -Destination $Destination `
                -Asynchronous `
                -ErrorAction Stop

            $localName = $bitsJob.FileList[0].LocalName
            
            # Get resulting local name of download
            $localName = $bitsJob.FileList[0].LocalName
            Write-Verbose "Local name of downloaded file: $localName"

            # Initialize progress calculation

            $startTime = Get-Date

            # Initialize progress bar parameters
            $progress = @{
                Id = Get-Random
                Activity = "Downloading from $Source to $localName"
                Status = $bitsJob.JobState
                SecondsRemaining = [int32]::MaxValue
                PercentComplete = -1
            }

            # Wait for BITS job to finish and write progress
            
            while ($bitsJob.JobState -ne 'Transferred' ) {
                # Calculate progress
                $bytesTotal = $bitsJob.BytesTotal
                $bytesTransferred = $bitsJob.BytesTransferred
                $secondsPassed = `
                    (New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds
                $progress.PercentComplete = $bytesTransferred / $bytesTotal * 100
                $secondsRemaining = [System.Math]::Round(
                    $secondsPassed / ($progress.PercentComplete / 100), 0
                )
                $speed = $bytesTransferred / $secondsPassed

                # Update progress bar parameters
                if ($secondsRemaining -le [int]::MaxValue) {
                    $progress.SecondsRemaining = $secondsRemaining
                }
                $progress.Status = '{0} {1}/{2} bytes @ {3:n1} Mbit/s' -f `
                    $bitsJob.JobState, $bytesTransferred, $bytesTotal, ($speed / 1MB * 8)

                # Show progress bar
                Write-Progress @progress
            }

            # Hide progress bar
            Complete-BitsTransfer -BitsJob $bitsJob
            Write-Progress @progress -Completed            
        }
        catch {
            # If the Throw keyword is used in a Catch block without an 
            # expression, it throws the current RuntimeException again. See:
            # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_throw#syntax
            throw
        }
        
    }

    return $localName
}