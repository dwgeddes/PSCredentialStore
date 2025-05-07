function Invoke-LinuxKeyring {
    <#
    .SYNOPSIS
        Interacts with the Linux Secret Service API (Keyring)
    .DESCRIPTION
        Internal function that manages credentials in the Linux keyring
    .PARAMETER Operation
        The operation to perform (Get, Set, Remove, List)
    .PARAMETER Target
        The identifier for the credential
    .PARAMETER Credential
        The credential object to store (for Set operation)
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCredential], ParameterSetName='Get')]
    [OutputType([bool], ParameterSetName='Set')]
    [OutputType([bool], ParameterSetName='Remove')]
    [OutputType([string[]], ParameterSetName='List')]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Get', 'Set', 'Remove', 'List')]
        [string]$Operation,
        
        [Parameter(Mandatory = $true)]
        [string]$Target,
        
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )
    
    # Check if we're on Linux (PS7 built-in $IsLinux)
    if (-not $IsLinux) {
        throw "Invoke-LinuxKeyring can only be used on Linux"
    }
    
    # Check if secret-tool is available using PowerShell 7's improved command detection
    $secretTool = Get-Command -Name 'secret-tool' -CommandType Application -ErrorAction SilentlyContinue
    if (-not $secretTool) {
        throw [System.InvalidOperationException]::new(
            "secret-tool is not available. Please install libsecret-tools package using your distribution's package manager.")
    }
    
    $appName = "PSCredentialStore"
    
    return $(switch ($Operation) {
        'Get' {
            try {
                # Get password using secret-tool with improved error handling
                $password = (secret-tool lookup application $appName target "$Target" 2>&1)
                
                # Use PowerShell 7 error handling and early exit with null coalescing
                if (-not $?) {
                    # Not found or error
                    $null
                    break
                }
                
                # Get username (stored as an attribute) - improved pipeline and regex
                $attributes = secret-tool search application $appName target "$Target" --all-attributes 2>&1
                $username = ($attributes | 
                    Where-Object { $_ -match 'username =' } | 
                    ForEach-Object { $_ -match 'username = (.*)$'; $Matches[1] })
                
                # Check if username was found
                if ([string]::IsNullOrEmpty($username)) {
                    $null
                    break
                }
                
                # Use PowerShell 7 credential creation syntax
                $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
                [System.Management.Automation.PSCredential]::new($username.Trim(), $securePassword)
            }
            catch {
                Write-Error "Failed to retrieve credential: $_" -ErrorAction Continue
                $null
            }
        }
        'Set' {
            try {
                # Use null check with improved exception handling
                if ($null -eq $Credential) {
                    throw [System.ArgumentNullException]::new('Credential', "Credential parameter is required for Set operation")
                }
                
                $username = $Credential.UserName
                $password = $Credential.GetNetworkCredential().Password
                
                # Remove existing credential if it exists - use the PowerShell 7 pipe chain operator to ignore errors
                Invoke-LinuxKeyring -Operation Remove -Target $Target -ErrorAction SilentlyContinue | Out-Null
                
                # Store the password with metadata - use modern error handling
                $password | secret-tool store --label="PSCredentialStore: $Target" application $appName target "$Target" username "$username" 2>&1 | Out-Null
                
                # Check result with PowerShell 7's automatic $? variable
                if (-not $?) {
                    throw "Failed to save credential to Linux keyring"
                }
                
                $true
            }
            catch {
                Write-Error "Failed to save credential: $_" -ErrorAction Continue
                $false
            }
        }
        'Remove' {
            try {
                # Use PowerShell 7's improved command execution and error handling
                $null = secret-tool clear application $appName target "$Target" 2>&1
                $true
            }
            catch {
                Write-Error "Failed to remove credential: $_" -ErrorAction Continue
                $false
            }
        }
        'List' {
            # Enumerate all stored targets via secret-tool
            $lines = secret-tool search application PSCredentialStore 2>$null
            if ($?) {
                $lines | ForEach-Object {
                    if ($_ -match '^target\s*=\s*"?(.*)"?$') { $Matches[1] }
                } | Select-Object -Unique
            } else {
                @()
            }
        }
    })
}