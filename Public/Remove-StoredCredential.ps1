function Remove-StoredCredential {
    <#
    .SYNOPSIS
        Removes a credential from the operating system's native credential store
    .DESCRIPTION
        Deletes a previously saved credential from the Windows Credential Manager, MacOS Keychain, 
        or Linux Keyring/Secret Service depending on the platform.
    .PARAMETER Target
        A unique identifier for the credential to remove
    .PARAMETER Force
        If specified, removes the credential without prompting for confirmation
    .EXAMPLE
        Remove-StoredCredential -Target "MyApp"
        # Removes the stored credential for "MyApp"
    .OUTPUTS
        [Boolean] True if successful, False if failed
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Target,
        
        [Parameter()]
        [switch]$Force
    )
    
    # Confirm whether to proceed
    if (-not $Force -and -not $PSCmdlet.ShouldProcess($Target, 'Remove credential')) {
        return $false
    }
    
    # Execute platform-specific implementation
    $result = switch (Get-OSPlatform) {
        'Windows' { Invoke-WindowsCredentialManager -Operation Remove -Target $Target }
        'MacOS'   { Invoke-MacOSKeychain -Operation Remove -Target $Target }
        'Linux'   { Invoke-LinuxKeyring -Operation Remove -Target $Target }
    }
    
    # Return result with verbose or error
    if ($result) {
        Write-Verbose "Successfully removed credential for target '$Target'"
        return $true
    } else {
        Write-Error "Failed to remove credential for target '$Target'"
        return $false
    }
}