#region Import Functions
# Import all public functions
$Public = @(Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}
#endregion Import Functions

# Export public functions explicitly for performance and clarity
# Functions to export from this module; list explicitly for performance
$FunctionsToExport = @(
    'Get-StoredCredential',
    'Set-StoredCredential',
    'Remove-StoredCredential',
    'Test-StoredCredential'
)

Export-ModuleMember -Function $FunctionsToExport