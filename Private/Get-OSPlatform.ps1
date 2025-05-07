function Get-OSPlatform {
    <#
    .SYNOPSIS
        Detects the operating system platform.
    .DESCRIPTION
        Returns the current operating system platform (Windows, MacOS, or Linux).
    .EXAMPLE
        Get-OSPlatform
    .OUTPUTS
        String with value "Windows", "MacOS", or "Linux"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # PowerShell 7 has built-in platform detection via automatic variables
    switch ($true) {
        $IsWindows { $operatingSystem = "Windows" }
        $IsMacOS { $operatingSystem = "MacOS" }
        $IsLinux { $operatingSystem = "Linux" }
        default { throw "Unsupported operating system. This module requires PowerShell 7 on Windows, macOS, or Linux." }
    }
    return $operatingSystem
}