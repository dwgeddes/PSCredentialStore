BeforeAll {
    # Import the module for testing
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module "$ModulePath/PSCredentialStore.psd1" -Force
}

# Windows Credential Manager Implementation
# Determine if running on Windows
$runningOnWindows = $PSVersionTable.PSVersion.Major -ge 6 ? $IsWindows : $env:OS -eq "Windows_NT"
# Use boolean for Skip parameter
Describe "Windows Credential Manager Implementation" -Tag "Windows" -Skip:(-not $runningOnWindows) {
    BeforeAll {
        # Create test credential
        $script:testUser = "windowstestuser"
        $script:testPassword = ConvertTo-SecureString "WindowsTest123!" -AsPlainText -Force
        $script:testCred = New-Object System.Management.Automation.PSCredential($script:testUser, $script:testPassword)
    }
    
    BeforeEach {
        # Generate a unique target name for testing
        $script:targetName = "PSCredentialStoreWindowsTest_$(Get-Random)"
    }
    
    AfterEach {
        # Clean up
        InModuleScope PSCredentialStore {
            Invoke-WindowsCredentialManager -Operation Remove -Target $script:targetName -ErrorAction SilentlyContinue
        }
    }
    
    It "Should store a credential directly with Invoke-WindowsCredentialManager" {
        InModuleScope PSCredentialStore {
            $result = Invoke-WindowsCredentialManager -Operation Set -Target $script:targetName -Credential $script:testCred
            $result | Should -BeTrue
        }
    }
    
    It "Should retrieve a credential directly with Invoke-WindowsCredentialManager" {
        InModuleScope PSCredentialStore {
            # First store the credential
            Invoke-WindowsCredentialManager -Operation Set -Target $script:targetName -Credential $script:testCred | Should -BeTrue
            
            # Then retrieve it
            $cred = Invoke-WindowsCredentialManager -Operation Get -Target $script:targetName
            $cred | Should -Not -BeNullOrEmpty
            $cred.UserName | Should -Be $script:testUser
            $cred.GetNetworkCredential().Password | Should -Be "WindowsTest123!"
        }
    }
    
    It "Should remove a credential directly with Invoke-WindowsCredentialManager" {
        InModuleScope PSCredentialStore {
            # First store the credential
            Invoke-WindowsCredentialManager -Operation Set -Target $script:targetName -Credential $script:testCred | Should -BeTrue
            
            # Then remove it
            $result = Invoke-WindowsCredentialManager -Operation Remove -Target $script:targetName
            $result | Should -BeTrue
            
            # Verify it's gone
            $cred = Invoke-WindowsCredentialManager -Operation Get -Target $script:targetName
            $cred | Should -BeNullOrEmpty
        }
    }
}