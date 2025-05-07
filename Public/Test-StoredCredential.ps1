function Test-StoredCredential {
    <#
    .SYNOPSIS
        Checks if a credential exists in the operating system's native credential store
    .DESCRIPTION
        Tests whether a credential with the specified target name exists in the 
        Windows Credential Manager, MacOS Keychain, or Linux Keyring
    .PARAMETER Target
        A unique identifier for the credential to check
    .EXAMPLE
        Test-StoredCredential -Target "MyApp"
        # Returns $true if credential exists, $false otherwise
    .OUTPUTS
        [Boolean] True if credential exists, False if it doesn't
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Target
    )
    
    # For macOS, use a direct check rather than relying on Get-StoredCredential
    # This is needed because the MacOS keychain has a known issue with credential deletion verification
    if ((Get-OSPlatform) -eq 'MacOS') {
        try {
            $serviceName = "PSCredentialStore:$Target"
            try {
                $result = security find-generic-password -s "$serviceName" -a "$Target" -w 2>$null
                return $null -ne $result
            }
            catch {
                return $false
            }
        }
        catch {
            # On any error, assume credential doesn't exist
            return $false
        }
    }
    else {
        # For other platforms, use Get-StoredCredential
        return $null -ne (Get-StoredCredential -Target $Target -ErrorAction SilentlyContinue)
    }
}