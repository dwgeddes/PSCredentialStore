function Invoke-LinuxKeyring {
    <#
    .SYNOPSIS
        Interacts with the Linux Secret Service API (Keyring)
    .DESCRIPTION
        Internal function that manages credentials in the Linux keyring
    .PARAMETER Operation
        The operation to perform (Get, Set, Remove, List)
    .PARAMETER Target
        The identifier for the credential (legacy parameter)
    .PARAMETER Id
        The identifier for the credential (preferred parameter)
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
        
        [Parameter(Mandatory = $false)]
        [string]$Target,
        
        [Parameter(Mandatory = $false)]
        [string]$Id,
        
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
    
    # Use Id if provided, otherwise fall back to Target for backward compatibility
    $credentialId = if ($Id) { $Id } else { $Target }
    
    $appName = "PSCredentialStore"
    
    return $(switch ($Operation) {
        'Get' {
            try {
                # Get password using secret-tool with improved error handling
                $password = (secret-tool lookup application $appName id "$credentialId" 2>&1)
                
                # If not found with id, try legacy target attribute for backward compatibility
                if (-not $?) {
                    $password = (secret-tool lookup application $appName target "$credentialId" 2>&1)
                    if (-not $?) {
                        # Not found or error
                        $null
                        break
                    }
                }
                
                # Get username (stored as an attribute) - improved pipeline and regex
                $attributes = secret-tool search application $appName id "$credentialId" --all-attributes 2>&1
                if (-not $?) {
                    # Try legacy target attribute
                    $attributes = secret-tool search application $appName target "$credentialId" --all-attributes 2>&1
                }
                
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
                Invoke-LinuxKeyring -Operation Remove -Id $credentialId -ErrorAction SilentlyContinue | Out-Null
                
                # Store the password with metadata - use modern error handling
                # Use id attribute instead of target for new credentials
                $password | secret-tool store --label="PSCredentialStore: $credentialId" application $appName id "$credentialId" username "$username" 2>&1 | Out-Null
                
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
                # Try both id and target attributes for backward compatibility
                $null = secret-tool clear application $appName id "$credentialId" 2>&1
                $targetRemoved = $?
                
                # Also try to remove by target attribute for backward compatibility
                $null = secret-tool clear application $appName target "$credentialId" 2>&1
                
                $targetRemoved -or $?
            }
            catch {
                Write-Error "Failed to remove credential: $_" -ErrorAction Continue
                $false
            }
        }
        'List' {
            # Enumerate all stored credentials via secret-tool
            $lines = secret-tool search application PSCredentialStore 2>$null
            if ($?) {
                $lines | ForEach-Object {
                    if ($_ -match '^id\s*=\s*"?(.*)"?$') { $Matches[1] }
                    elseif ($_ -match '^target\s*=\s*"?(.*)"?$') { $Matches[1] } # For backward compatibility
                } | Select-Object -Unique
            } else {
                @()
            }
        }
    })
}