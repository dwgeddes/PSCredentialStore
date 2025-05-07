function Invoke-WindowsCredentialManager {
    <#
    .SYNOPSIS
        Interacts with the Windows Credential Manager
    .DESCRIPTION
        Internal function that manages credentials in the Windows Credential Manager
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
    
    # Check if we're on Windows (PS7 built-in $IsWindows)
    if (-not $IsWindows) {
        throw "Invoke-WindowsCredentialManager can only be used on Windows"
    }
    
    Add-Type -AssemblyName System.Security
    
    return $(switch ($Operation) {
        'Get' {
            try {
                $nativeCred = [CredentialManager.CredentialManager]::GetCredentials($Target)
                if ($nativeCred) {
                    # Create a PowerShell credential object
                    $securePassword = ConvertTo-SecureString $nativeCred.Password -AsPlainText -Force
                    [System.Management.Automation.PSCredential]::new($nativeCred.UserName, $securePassword)
                } else {
                    $null
                }
            }
            catch {
                Write-Error "Failed to retrieve credential: $_" -ErrorAction Continue
                $null
            }
        }
        'Set' {
            try {
                # Check for required credential parameter
                if ($null -eq $Credential) {
                    throw [System.ArgumentNullException]::new('Credential', "Credential parameter is required for Set operation")
                }
                
                # Get password as plain text for native API
                $password = $Credential.GetNetworkCredential().Password
                
                # Save credential and return result
                [CredentialManager.CredentialManager]::SaveCredentials($Target, $Credential.UserName, $password)
            }
            catch {
                Write-Error "Failed to save credential: $_" -ErrorAction Continue
                $false
            }
        }
        'Remove' {
            try {
                [CredentialManager.CredentialManager]::DeleteCredentials($Target)
            }
            catch {
                Write-Error "Failed to remove credential: $_" -ErrorAction Continue
                $false
            }
        }
        'List' {
            # Enumerate all generic credentials in Windows Credential Manager
            Add-Type -TypeDefinition @'
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
'@ -ErrorAction SilentlyContinue
            $count = 0; $ptr = [IntPtr]::Zero
            if ([CredApi]::CredEnumerate('*', 0, [ref]$count, [ref]$ptr)) {
                $names = for ($i = 0; $i -lt $count; $i++) {
                    $currentPtr = [Runtime.InteropServices.Marshal]::ReadIntPtr($ptr, $i * [IntPtr]::Size)
                    $cs = [Runtime.InteropServices.Marshal]::PtrToStructure($currentPtr, [Type][CREDENTIAL])
                    $cs.TargetName
                }
                [CredApi]::CredFree($ptr)
                return ,$names
            }
            return @()
        }
    })
}

# Define the internal C# class for Windows Credential Manager operations
if (-not ([System.Management.Automation.PSTypeName]'CredentialManager.CredentialManager').Type) {
    # Use .NET Core compatible method to load the C# code
    Add-Type @'
        using System;
        using System.Runtime.InteropServices;
        using System.Text;
        
        namespace CredentialManager {
            public class CredentialManager {
                [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
                private static extern bool CredRead(string target, int type, int reservedFlag, out IntPtr credentialPtr);
                
                [DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
                private static extern bool CredWrite(ref CREDENTIAL credential, UInt32 flags);
                
                [DllImport("advapi32.dll", EntryPoint = "CredDeleteW", CharSet = CharSet.Unicode, SetLastError = true)]
                private static extern bool CredDelete(string target, int type, int flags);
                
                [DllImport("advapi32.dll", EntryPoint = "CredFree", SetLastError = true)]
                private static extern void CredFree(IntPtr buffer);
                
                [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
                private struct CREDENTIAL {
                    public int Flags;
                    public int Type;
                    public string TargetName;
                    public string Comment;
                    public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
                    public int CredentialBlobSize;
                    public IntPtr CredentialBlob;
                    public int Persist;
                    public int AttributeCount;
                    public IntPtr Attributes;
                    public string TargetAlias;
                    public string UserName;
                }
                
                private const int CRED_TYPE_GENERIC = 1;
                private const int CRED_PERSIST_LOCAL_MACHINE = 2;
                
                public static Credential GetCredentials(string target) {
                    IntPtr credPtr;
                    if (!CredRead(target, CRED_TYPE_GENERIC, 0, out credPtr)) {
                        return null;
                    }
                    
                    try {
                        CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(credPtr, typeof(CREDENTIAL));
                        string password = null;
                        
                        if (cred.CredentialBlobSize > 0) {
                            password = Marshal.PtrToStringUni(cred.CredentialBlob, cred.CredentialBlobSize / 2);
                        }
                        
                        return new Credential {
                            UserName = cred.UserName,
                            Password = password,
                            Target = cred.TargetName
                        };
                    }
                    finally {
                        CredFree(credPtr);
                    }
                }
                
                public static bool SaveCredentials(string target, string userName, string password) {
                    CREDENTIAL cred = new CREDENTIAL();
                    cred.Type = CRED_TYPE_GENERIC;
                    cred.TargetName = target;
                    cred.UserName = userName;
                    cred.CredentialBlob = Marshal.StringToCoTaskMemUni(password);
                    cred.CredentialBlobSize = password.Length * 2;
                    cred.Persist = CRED_PERSIST_LOCAL_MACHINE;
                    
                    bool result = CredWrite(ref cred, 0);
                    Marshal.FreeCoTaskMem(cred.CredentialBlob);
                    return result;
                }
                
                public static bool DeleteCredentials(string target) {
                    return CredDelete(target, CRED_TYPE_GENERIC, 0);
                }
            }
            
            public class Credential {
                public string UserName { get; set; }
                public string Password { get; set; }
                public string Target { get; set; }
            }
        }
'@ 
}