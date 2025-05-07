function Invoke-MacOSKeychain {
    <#
    .SYNOPSIS
        Interacts with the MacOS Keychain
    .DESCRIPTION
        Internal function that manages credentials in the MacOS Keychain
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
    
    # Check if we're on macOS (PS7 built-in $IsMacOS)
    if (-not $IsMacOS) {
        throw "Invoke-MacOSKeychain can only be used on macOS"
    }
    
    # Use Id if provided, otherwise fall back to Target for backward compatibility
    $credentialId = if ($Id) { $Id } else { $Target }
    
    $serviceName = "PSCredentialStore:$credentialId"
    $metadataFile = Join-Path $env:HOME ".pscredstore_metadata"
    
    return $(switch ($Operation) {
        'Get' {
            try {
                # First, check if the password exists
                $passwordOutput = $null
                try {
                    $passwordOutput = security find-generic-password -s "$serviceName" -a "$credentialId" -w 2>$null
                }
                catch {
                    # An exception likely means the credential wasn't found
                    return $null
                }
                
                # If we didn't get a password, return null
                if (-not $passwordOutput) {
                    return $null
                }
                
                # Get the username from our metadata file if possible
                $username = $credentialId # Default to using the id as username
                if (Test-Path $metadataFile) {
                    try {
                        $metadataContent = Get-Content $metadataFile -Raw -ErrorAction SilentlyContinue
                        if ($metadataContent) {
                            $metadata = ConvertFrom-Json $metadataContent -ErrorAction SilentlyContinue
                            if ($metadata."$credentialId") {
                                $username = $metadata."$credentialId"
                            }
                        }
                    }
                    catch {
                        Write-Verbose "Could not read metadata file, using id as username"
                    }
                }
                
                # Create and return the credential
                $securePassword = ConvertTo-SecureString $passwordOutput -AsPlainText -Force
                [System.Management.Automation.PSCredential]::new($username, $securePassword)
            }
            catch {
                Write-Verbose "Failed to retrieve credential: $_"
                return $null
            }
        }
        'Set' {
            try {
                if ($null -eq $Credential) {
                    throw [System.ArgumentNullException]::new('Credential', "Credential parameter is required for Set operation")
                }
                
                $username = $Credential.UserName
                $password = $Credential.GetNetworkCredential().Password
                
                # Remove any existing entry first - ignore errors
                security delete-generic-password -s "$serviceName" -a "$credentialId" 2>&1 > $null
                
                # Add the entry with the password
                $result = security add-generic-password -s "$serviceName" -a "$credentialId" -w "$password" -U -T /usr/bin/security 2>&1
                $exitCode = $?
                
                if (-not $exitCode) {
                    throw "Failed to save credential: $result"
                }
                
                # Store username in metadata file
                if (-not (Test-Path $metadataFile)) {
                    $metadata = @{}
                }
                else {
                    try {
                        $metadataContent = Get-Content $metadataFile -Raw -ErrorAction SilentlyContinue
                        if ($metadataContent) {
                            $metadata = ConvertFrom-Json $metadataContent -AsHashtable -ErrorAction SilentlyContinue
                            if (-not $metadata) { $metadata = @{} }
                        }
                        else {
                            $metadata = @{}
                        }
                    }
                    catch {
                        $metadata = @{}
                    }
                }
                
                $metadata[$credentialId] = $username
                $metadataJson = ConvertTo-Json $metadata -Compress
                Set-Content -Path $metadataFile -Value $metadataJson -Force
                
                $true
            }
            catch {
                Write-Error "Failed to save credential: $_" -ErrorAction Continue
                $false
            }
        }
        'Remove' {
            try {
                # Try to delete the credential - ignore the return value
                # Note: security will exit with non-zero if item doesn't exist
                try {
                    security delete-generic-password -s "$serviceName" -a "$credentialId" 2>$null
                }
                catch {
                    # Ignore errors during deletion attempt
                }
                
                # Also remove from metadata if it exists
                if (Test-Path $metadataFile) {
                    try {
                        $metadataContent = Get-Content $metadataFile -Raw -ErrorAction SilentlyContinue
                        if ($metadataContent) {
                            $metadata = ConvertFrom-Json $metadataContent -AsHashtable -ErrorAction SilentlyContinue
                            if ($metadata.ContainsKey($credentialId)) {
                                $metadata.Remove($credentialId)
                                $metadataJson = ConvertTo-Json $metadata -Compress
                                Set-Content -Path $metadataFile -Value $metadataJson -Force
                            }
                        }
                    }
                    catch {
                        # Ignore metadata errors on removal
                    }
                }
                
                # Verify it's actually gone by trying to retrieve the password
                # This is more reliable than checking if the delete command succeeded
                try {
                    $check = security find-generic-password -s "$serviceName" -a "$credentialId" -w 2>$null
                    if ($check) {
                        Write-Verbose "Credential still exists after deletion attempt. Trying one more time."
                        # Try one more delete with more force
                        security delete-generic-password -s "$serviceName" -a "$credentialId" -D 2>$null
                        
                        # Check again
                        $checkAgain = security find-generic-password -s "$serviceName" -a "$credentialId" -w 2>$null
                        if ($checkAgain) {
                            return $false
                        }
                    }
                }
                catch {
                    # An error here means the credential is gone (couldn't be found), which is what we want
                }
                
                # If we get here, the credential is gone
                return $true
            }
            catch {
                Write-Verbose "Error in Remove operation: $_"
                # Always return true for removal operation - being gone is the goal
                # and we don't want to fail if it was already gone
                return $true
            }
        }
        'List' {
            # Return all stored targets from metadata file
            $metadataFile = Join-Path $env:HOME ".pscredstore_metadata"
            if (Test-Path $metadataFile) {
                try {
                    $metadata = ConvertFrom-Json (Get-Content $metadataFile -Raw) -ErrorAction Stop
                    return $metadata.PSObject.Properties.Name
                }
                catch {
                    return @()
                }
            }
            return @()
        }
    })
}