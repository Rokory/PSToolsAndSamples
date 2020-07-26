Function Do-Something {
    [CmdletBinding(SupportsShouldProcess = $True, ConfirmImpact = 'High')]
    Param(
        [Parameter(
            ValueFromPipeline = $True
        )]
        $Values
    )
    BEGIN {
        Write-Host "Starting to do something."
    }
    PROCESS {
        if ($PSCmdlet.ShouldProcess(
            $PSItem
        )) {
            
        }
        Write-Host $PSItem
    }
    END {
        Write-Host "Finished doing something."
    }
}

'A', 'B', 'C' | Do-Something

try {
    Remove-Item bla -ErrorAction Stop
}
catch {
    Write-Host $_.Exception.GetType()
}