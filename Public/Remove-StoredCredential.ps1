function Remove-StoredCredential {
    <#
    .SYNOPSIS
        Removes a credential from the operating system's native credential store
    .DESCRIPTION
        Deletes a previously saved credential from the Windows Credential Manager, MacOS Keychain, 
        or Linux Keyring/Secret Service depending on the platform.
    .PARAMETER Id
        A unique identifier for the credential to remove
    .PARAMETER Force
        If specified, removes the credential without prompting for confirmation
    .EXAMPLE
        Remove-StoredCredential -Id "MyApp"
        # Removes the stored credential for "MyApp"
    .EXAMPLE
        Get-StoredCredential | Remove-StoredCredential -Force
        # Removes all stored credentials without prompting for confirmation
    .OUTPUTS
        [PSObject] with Id and Status properties
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSObject])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [string]$Id,
        
        [Parameter()]
        [switch]$Force
    )
    
    process {
        # Confirm whether to proceed
        if (-not $Force -and -not $PSCmdlet.ShouldProcess($Id, 'Remove credential')) {
            return [PSCustomObject]@{
                Id = $Id
                Status = "Skipped"
                Message = "Operation canceled by user"
            }
        }
        
        # Execute platform-specific implementation
        $result = switch (Get-OSPlatform) {
            'Windows' { Invoke-WindowsCredentialManager -Operation Remove -Target $Id }
            'MacOS'   { Invoke-MacOSKeychain -Operation Remove -Target $Id }
            'Linux'   { Invoke-LinuxKeyring -Operation Remove -Target $Id }
        }
        
        # Return result with console output and object
        if ($result) {
            Write-Host "Successfully removed credential for ID '$Id'"
            return [PSCustomObject]@{
                Id = $Id
                Status = "Success"
                Message = "Credential removed successfully"
            }
        } else {
            $errorMsg = "Failed to remove credential for ID '$Id'"
            Write-Error $errorMsg
            return [PSCustomObject]@{
                Id = $Id
                Status = "Failed"
                Message = $errorMsg
            }
        }
    }
}