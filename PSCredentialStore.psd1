@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'PSCredentialStore.psm1'
    
    # Version number of this module.
    ModuleVersion = '0.1.0'
    
    # ID used to uniquely identify this module
    GUID = 'e3a94f17-0dc2-4f55-baf1-1bfdc21ee6d0'
    
    # Author of this module
    Author = 'Your Name'
    
    # Company or vendor of this module
    CompanyName = 'Your Company'
    
    # Copyright statement for this module
    Copyright = '(c) 2025. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'PowerShell module that provides cross-platform credential management using native OS credential stores'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'
    
    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()
    
    # Functions to export from this module; list explicitly for performance
    FunctionsToExport = @(
        'Get-StoredCredential',
        'Set-StoredCredential',
        'Remove-StoredCredential',
        'Test-StoredCredential'
    )
    
    # Cmdlets to export from this module; none
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = '*'
    
    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry
    AliasesToExport = @()

    # Compatible PSEditions
    CompatiblePSEditions = @('Core')
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Credential', 'Security', 'KeyChain', 'CredentialManager', 'KeyRing', 'CrossPlatform', 'PSEdition_Core', 'PowerShell7')
            
            # A URL to the license for this module.
            LicenseUri = ''
            
            # A URL to the main website for this project.
            ProjectUri = ''
            
            # A URL to an icon representing this module.
            # IconUri = ''
            
            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release of PSCredentialStore module. Requires PowerShell 7.'
            
            # PSData compatibility flags
            Compatibility = @{
                PowerShell = @{
                    Minimum = '7.0'
                    Maximum = ''
                }
            }
        }
    }
}