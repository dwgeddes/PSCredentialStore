function Set-StoredCredential {
    <#
    .SYNOPSIS
        Stores a credential in the operating system's native credential store
    .DESCRIPTION
        Saves a credential to the Windows Credential Manager, MacOS Keychain, 
        or Linux Keyring/Secret Service depending on the platform.
    .PARAMETER Id
        A unique identifier for the credential
    .PARAMETER Credential
        The PowerShell credential object to store
    .PARAMETER Force
        If specified, overwrites any existing credential with the same Id without prompting
    .EXAMPLE
        $cred = Get-Credential
        Set-StoredCredential -Id "MyApp" -Credential $cred
        # Stores the credential in the native OS credential store
    .EXAMPLE
        Set-StoredCredential -Id "DatabaseAccess" -UserName "dbuser" -Password (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force)
        # Creates and stores a credential using provided username and password
    .OUTPUTS
        [PSObject] with Id, UserName and Credential properties
    #>
    [CmdletBinding(DefaultParameterSetName = 'Credential', SupportsShouldProcess = $true)]
    [OutputType([PSObject])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [string]$Id,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Credential', Position = 1, ValueFromPipeline = $true)]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'UsernamePassword', Position = 1)]
        [string]$UserName,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'UsernamePassword', Position = 2)]
        [securestring]$Password,
        
        [Parameter()]
        [switch]$Force
    )
    
    process {
        # If username/password provided, create credential object using PowerShell 7 constructor syntax
        if ($PSCmdlet.ParameterSetName -eq 'UsernamePassword') {
            $Credential = [System.Management.Automation.PSCredential]::new($UserName, $Password)
        }
        
        # Check if credential already exists with improved flow control
        try {
            $existingCred = Get-StoredCredential -Id $Id -ErrorAction Stop
            
            # Use PowerShell 7's improved conditional logic
            if ($existingCred -and -not $Force -and -not $PSCmdlet.ShouldProcess($Id, "Overwrite existing credential")) {
                Write-Warning "A credential with ID '$Id' already exists. Use -Force to overwrite."
                return $null
            }
        }
        catch {
            # Credential doesn't exist, continue
        }
        
        # Execute platform-specific implementation using PowerShell 7 switch expression
        $result = switch (Get-OSPlatform) {
            'Windows' { Invoke-WindowsCredentialManager -Operation Set -Target $Id -Credential $Credential }
            'MacOS'   { Invoke-MacOSKeychain -Operation Set -Target $Id -Credential $Credential }
            'Linux'   { Invoke-LinuxKeyring -Operation Set -Target $Id -Credential $Credential }
        }
        
        # Return the result with appropriate message and credentials object
        if ($result) {
            Write-Host "Credential for ID '$Id' set successfully."
            # Return the credential as a consistent object format
            return [PSCustomObject]@{
                Id = $Id
                UserName = $Credential.UserName
                Credential = $Credential
            }
        }
        else {
            Write-Error "Failed to store credential for ID '$Id'"
            return $null
        }
    }
}