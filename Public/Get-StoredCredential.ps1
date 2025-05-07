function Get-StoredCredential {
    <#
    .SYNOPSIS
        Retrieves credential(s) from the operating system's native credential store
    .DESCRIPTION
        Gets a previously saved credential from the Windows Credential Manager, MacOS Keychain, 
        or Linux Keyring/Secret Service depending on the platform.
        
        When run without a Target parameter, returns a list of all stored credentials.
    .PARAMETER Target
        A unique identifier for the credential to retrieve. If not specified, all credentials will be listed.
    .EXAMPLE
        $cred = Get-StoredCredential -Target "MyApp"
        # Retrieves the stored credential for "MyApp"
    .EXAMPLE
        Get-StoredCredential
        # Lists all stored credentials
    .OUTPUTS
        [System.Management.Automation.PSCredential] if a specific credential is requested
        [PSObject[]] with Target and Credential properties when listing all credentials
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCredential], [PSObject[]])]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$Target
    )
    
    # If Target is provided, get a specific credential
    if ($Target) {
        # Detect platform and use appropriate implementation using PowerShell 7 switch expressions
        $credential = switch (Get-OSPlatform) {
            'Windows' { Invoke-WindowsCredentialManager -Operation Get -Target $Target }
            'MacOS'   { Invoke-MacOSKeychain -Operation Get -Target $Target }
            'Linux'   { Invoke-LinuxKeyring -Operation Get -Target $Target }
        }
        
        # Return the credential with appropriate verbose message
        if ($null -ne $credential) {
            Write-Verbose "Successfully retrieved credential for target '$Target'"
            return $credential
        } else {
            Write-Verbose "No credential found for target '$Target'"
            return $null
        }
    }
    # Otherwise, list all credentials
    else {
        Write-Verbose "Listing all stored credentials"
        switch (Get-OSPlatform) {
            'Windows' {
                # Load CredApi P/Invoke definitions if not already loaded
                Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct CREDENTIAL {
    public uint Flags;
    public uint Type;
    public string TargetName;
    public string Comment;
    public FILETIME LastWritten;
    public uint CredentialBlobSize;
    public IntPtr CredentialBlob;
    public uint Persist;
    public uint AttributeCount;
    public IntPtr Attributes;
    public string TargetAlias;
    public string UserName;
}

public static class CredApi {
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CredEnumerate(string filter, uint flags, out uint count, out IntPtr pCredentials);
    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern void CredFree(IntPtr buffer);
}
"@ -ErrorAction SilentlyContinue

                $count = 0
                $ptr = [IntPtr]::Zero
                if ([CredApi]::CredEnumerate('*', 0, [ref]$count, [ref]$ptr)) {
                    for ($i = 0; $i -lt $count; $i++) {
                        $currentPtr = [Runtime.InteropServices.Marshal]::ReadIntPtr($ptr, $i * [IntPtr]::Size)
                        $credStruct = [Runtime.InteropServices.Marshal]::PtrToStructure($currentPtr, [Type][CREDENTIAL])
                        if ($credStruct.Type -eq 1) {
                            $pwd = if ($credStruct.CredentialBlobSize -gt 0) { [Runtime.InteropServices.Marshal]::PtrToStringUni($credStruct.CredentialBlob, $credStruct.CredentialBlobSize/2) } else { '' }
                            $securePwd = ConvertTo-SecureString $pwd -AsPlainText -Force
                            $pscred = [PSCredential]::new($credStruct.UserName, $securePwd)
                            [PSCustomObject]@{ Target = $credStruct.TargetName; Credential = $pscred }
                        }
                    }
                    [CredApi]::CredFree($ptr)
                }
            }
            'MacOS' {
                # Use metadata file to list stored targets
                $metadataFile = Join-Path $env:HOME '.pscredstore_metadata'
                if (Test-Path $metadataFile) {
                    try {
                        $data = ConvertFrom-Json (Get-Content $metadataFile -Raw) -ErrorAction Stop
                        foreach ($target in $data.PSObject.Properties.Name) {
                            $cred = Invoke-MacOSKeychain -Operation Get -Target $target
                            [PSCustomObject]@{ Target = $target; Credential = $cred }
                        }
                    }
                    catch {
                        Write-Warning "Failed to read metadata: $_"
                    }
                }
            }
            'Linux' {
                # Enumerate items via secret-tool
                $targets = Get-LinuxTargets
                foreach ($target in $targets) {
                    $cred = Invoke-LinuxKeyring -Operation Get -Target $target
                    [PSCustomObject]@{ Target = $target; Credential = $cred }
                }
            }
        }
    }
}

# Helper to invoke secret-tool command, so it can be mocked in tests
function Invoke-SecretTool {
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        $Args
    )
    & secret-tool @Args
}

# Add helper to gather Linux targets, allowing mocking
function Get-LinuxTargets {
    # Use Invoke-SecretTool to search for application keywords (allows mocking)
    $attrs = Invoke-SecretTool search application PSCredentialStore 2>$null
    if ($?) {
        return $attrs | ForEach-Object {
            if ($_ -match '^target\s*=\s*"?(.*)"?$') { $Matches[1] }
        } | Select-Object -Unique
    }
    return @()
}