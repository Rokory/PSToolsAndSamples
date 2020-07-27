$path = 'bla'
# Surround a code block, which is prone to errors with try
try {
    # This will most likely produce an error
    Remove-Item $path -ErrorAction Stop
}
# catch [System.Management.Automation.ItemNotFoundException] {
#     Write-Host "Sorry, could not find $path. I cannot delete it."
# }
# This will catch all errors
catch {
    # $PSItem contains the whole error record
    # To obtain the error type, we call GetType() on the Exception property
    Write-Host $PSItem.Exception.GetType()
    # It is a good idea, to throw the error again
    throw
}
finally {
    Write-Host 'This part is executed, regardless whether an error occured.'
}