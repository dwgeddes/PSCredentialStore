[CmdletBinding()]
param (
    [Parameter()]
    [switch]$SkipIntegrationTests,
    
    [Parameter()]
    [switch]$CodeCoverage
)

# Check for PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "This module requires PowerShell 7 or later. Current version: $($PSVersionTable.PSVersion)"
    exit 1
}

# Ensure Pester is installed with proper version for PS7
if (-not (Get-Module -Name Pester -ListAvailable | Where-Object { $_.Version -ge '5.0' })) {
    Write-Host "Compatible Pester module not found. Installing latest Pester..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser -MinimumVersion 5.0
}

# Import Pester
Import-Module Pester -MinimumVersion 5.0 -Force

# Set Pester configuration with PS7 improvements
$PesterConfig = [PesterConfiguration]::Default
$PesterConfig.Run.Path = "$PSScriptRoot"
$PesterConfig.Run.Exit = $true
$PesterConfig.TestResult.Enabled = $true
$PesterConfig.TestResult.OutputPath = "$PSScriptRoot/TestResults.xml"
$PesterConfig.Output.Verbosity = "Detailed"

# Handle integration tests
if ($SkipIntegrationTests) {
    Write-Host "Skipping integration tests..." -ForegroundColor Yellow
    $PesterConfig.Filter.Tag = @("!Integration")
}

# Set up code coverage if requested, using PS7's improved collection functionality
if ($CodeCoverage) {
    $ModulePath = $PSScriptRoot | Split-Path -Parent
    $AllFunctions = Get-ChildItem -Path @("$ModulePath/Public", "$ModulePath/Private") -Filter "*.ps1" -Recurse

    $PesterConfig.CodeCoverage.Enabled = $true
    $PesterConfig.CodeCoverage.Path = $AllFunctions.FullName
    $PesterConfig.CodeCoverage.OutputPath = "$PSScriptRoot/Coverage.xml"
    $PesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
}

# Run the tests using PS7's improved Pester integration
Invoke-Pester -Configuration $PesterConfig