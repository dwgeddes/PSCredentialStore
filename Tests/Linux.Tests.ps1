BeforeAll {
    # Import the module for testing
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module "$ModulePath/PSCredentialStore.psd1" -Force
}

# Linux Keyring Implementation
Describe "Linux Keyring Implementation" -Tag "Linux" -Skip:(((-not ($PSVersionTable.PSVersion.Major -ge 6 ? $IsLinux : (uname) -match 'Linux'))) -or (-not (Get-Command -Name 'secret-tool' -ErrorAction SilentlyContinue))) {
    BeforeAll {
        # Create test credential
        $script:testUser = "linuxtestuser"
        $script:testPassword = ConvertTo-SecureString "LinuxTest123!" -AsPlainText -Force
        $script:testCred = New-Object System.Management.Automation.PSCredential($script:testUser, $script:testPassword)
    }
    
    BeforeEach {
        # Generate a unique target name for testing
        $script:targetName = "PSCredentialStoreLinuxTest_$(Get-Random)"
    }
    
    AfterEach {
        # Clean up
        InModuleScope PSCredentialStore {
            Invoke-LinuxKeyring -Operation Remove -Target $script:targetName -ErrorAction SilentlyContinue
        }
    }
    
    It "Should store a credential directly with Invoke-LinuxKeyring" {
        InModuleScope PSCredentialStore {
            $result = Invoke-LinuxKeyring -Operation Set -Target $script:targetName -Credential $script:testCred
            $result | Should -BeTrue
        }
    }
    
    It "Should retrieve a credential directly with Invoke-LinuxKeyring" {
        InModuleScope PSCredentialStore {
            # First store the credential
            Invoke-LinuxKeyring -Operation Set -Target $script:targetName -Credential $script:testCred | Should -BeTrue
            
            # Then retrieve it
            $cred = Invoke-LinuxKeyring -Operation Get -Target $script:targetName
            $cred | Should -Not -BeNullOrEmpty
            $cred.UserName | Should -Be $script:testUser
            $cred.GetNetworkCredential().Password | Should -Be "LinuxTest123!"
        }
    }
    
    It "Should remove a credential directly with Invoke-LinuxKeyring" {
        InModuleScope PSCredentialStore {
            # First store the credential
            Invoke-LinuxKeyring -Operation Set -Target $script:targetName -Credential $script:testCred | Should -BeTrue
            
            # Then remove it
            $result = Invoke-LinuxKeyring -Operation Remove -Target $script:targetName
            $result | Should -BeTrue
            
            # Verify it's gone
            $cred = Invoke-LinuxKeyring -Operation Get -Target $script:targetName
            $cred | Should -BeNullOrEmpty
        }
    }
}