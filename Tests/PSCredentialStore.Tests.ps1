BeforeAll {
    # Import the module for testing
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module "$ModulePath/PSCredentialStore.psd1" -Force
    
    # Check PS7 requirement
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "These tests require PowerShell 7 or later. Current version: $($PSVersionTable.PSVersion)"
    }
}

Describe "PSCredentialStore Module" {
    Context "Module Structure" {
        It "Module manifest should be valid and require PowerShell 7+" {
            $ModulePath = Split-Path -Parent $PSScriptRoot
            $manifest = Test-ModuleManifest -Path "$ModulePath/PSCredentialStore.psd1"
            $manifest | Should -Not -BeNullOrEmpty
            $manifest.PowerShellVersion.Major | Should -BeGreaterOrEqual 7
        }
        
        It "Should export the required functions" {
            # Use PowerShell 7's improved pipeline processing
            @('Get-StoredCredential', 'Set-StoredCredential', 'Remove-StoredCredential', 'Test-StoredCredential') | 
                ForEach-Object {
                    Get-Command -Module PSCredentialStore -Name $_ | Should -Not -BeNullOrEmpty
                }
        }
    }

    Context "Platform Detection" {
        It "Should detect the current platform correctly using automatic variables" {
            InModuleScope PSCredentialStore {
                $platform = Get-OSPlatform
                
                # Use PS7's ternary operator for cleaner conditionals
                $expectedPlatform = $IsWindows ? "Windows" : ($IsMacOS ? "MacOS" : ($IsLinux ? "Linux" : "Unknown"))
                $platform | Should -Be $expectedPlatform
            }
        }
    }

    Context "Credential Management" -Tag "Integration" {
        # These tests modify the system credential store - only run them in a controlled environment
        BeforeEach {
            # Generate a unique ID for testing to avoid conflicts
            $script:credentialId = "PSCredentialStoreTest_$(Get-Random)"
            $script:testUser = "testuser"
            $script:testPassword = ConvertTo-SecureString "TestP@ssword123" -AsPlainText -Force
            
            # Use PS7's credential creation syntax
            $script:testCred = [System.Management.Automation.PSCredential]::new($script:testUser, $script:testPassword)
        }
        
        AfterEach {
            # Clean up any leftover credentials
            Remove-StoredCredential -Id $script:credentialId -Force -ErrorAction SilentlyContinue
        }
        
        It "Should store a credential" -Skip:([bool]$env:CI) {
            # Store a credential
            $result = Set-StoredCredential -Id $script:credentialId -Credential $script:testCred
            $result | Should -Not -BeNullOrEmpty
            $result.Id | Should -Be $script:credentialId
            
            # Verify it was stored correctly
            $exists = Test-StoredCredential -Id $script:credentialId
            $exists | Should -BeTrue
        }
        
        It "Should retrieve a credential" -Skip:([bool]$env:CI) {
            # Store a credential
            Set-StoredCredential -Id $script:credentialId -Credential $script:testCred | Should -Not -BeNullOrEmpty
            
            # Verify it was stored correctly
            $retrievedCred = Get-StoredCredential -Id $script:credentialId
            $retrievedCred | Should -Not -BeNullOrEmpty
            $retrievedCred.Id | Should -Be $script:credentialId
            $retrievedCred.UserName | Should -Be $script:testUser
            
            # On macOS the username might be stored differently depending on how security is implemented
            # So we'll test that we can at least retrieve a credential and the password is correct
            $retrievedCred.Credential.GetNetworkCredential().Password | Should -Be "TestP@ssword123"
        }
        
        It "Should remove a credential" -Skip:([bool]$env:CI) {
            # Store a credential first
            Set-StoredCredential -Id $script:credentialId -Credential $script:testCred | Should -Not -BeNullOrEmpty
            Test-StoredCredential -Id $script:credentialId | Should -BeTrue
            
            # Remove it
            $result = Remove-StoredCredential -Id $script:credentialId -Force
            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be "Success"
            
            # Verify it's gone
            Test-StoredCredential -Id $script:credentialId | Should -BeFalse
        }
    }
    
    Context "Function Mocking" {
        # Pure unit tests with mocks that don't touch the actual credential store
        BeforeAll {
            # Mock the platform detection to test each platform handler
            Mock -ModuleName PSCredentialStore Get-OSPlatform { return "Windows" }
            
            # Create test credential
            $script:testUser = "mockuser"
            $script:testPassword = ConvertTo-SecureString "MockP@ssword123" -AsPlainText -Force
            $script:testCred = New-Object System.Management.Automation.PSCredential($script:testUser, $script:testPassword)
        }
        
        It "Should use Windows credential manager when on Windows" {
            Mock -ModuleName PSCredentialStore Invoke-WindowsCredentialManager { return $true }
            
            Set-StoredCredential -Id "MockTest" -Credential $script:testCred
            
            Should -Invoke -ModuleName PSCredentialStore -CommandName Invoke-WindowsCredentialManager -Times 1
        }
        
        It "Should use MacOS keychain when on MacOS" {
            # Change mock to return "MacOS" instead
            Mock -ModuleName PSCredentialStore Get-OSPlatform { return "MacOS" }
            Mock -ModuleName PSCredentialStore Invoke-MacOSKeychain { return $true }
            
            Set-StoredCredential -Id "MockTest" -Credential $script:testCred
            
            Should -Invoke -ModuleName PSCredentialStore -CommandName Invoke-MacOSKeychain -Times 1
        }
        
        It "Should use Linux keyring when on Linux" {
            # Change mock to return "Linux" instead
            Mock -ModuleName PSCredentialStore Get-OSPlatform { return "Linux" }
            Mock -ModuleName PSCredentialStore Invoke-LinuxKeyring { return $true }
            
            Set-StoredCredential -Id "MockTest" -Credential $script:testCred
            
            Should -Invoke -ModuleName PSCredentialStore -CommandName Invoke-LinuxKeyring -Times 1
        }
        
        Context "Credential Listing" {
            It "Should list credentials on MacOS" {
                InModuleScope PSCredentialStore {
                    Mock -ModuleName PSCredentialStore Get-OSPlatform { "MacOS" }
                    Mock -CommandName Test-Path { return $true }
                    Mock -CommandName Get-Content { return '{"foo":{},"bar":{}}' }
                    Mock -ModuleName PSCredentialStore Invoke-MacOSKeychain {
                        param($Operation, $Target)
                        [PSCredential]::new("user_$Target", (ConvertTo-SecureString "pass_$Target" -AsPlainText -Force))
                    }
                    $result = Get-StoredCredential
                    $result.Id | Should -Be "foo","bar"
                    $result.Credential.GetNetworkCredential().Password | Should -Be "pass_foo","pass_bar"
                }
            }

            It "Should list credentials on Linux" {
                InModuleScope PSCredentialStore {
                    Mock -ModuleName PSCredentialStore Get-OSPlatform { "Linux" }
                    # Mock Get-LinuxTargets to simulate secret-tool output
                    Mock -ModuleName PSCredentialStore Get-LinuxTargets { @('foo','bar') }
                    Mock -ModuleName PSCredentialStore Invoke-LinuxKeyring {
                        param($Operation, $Target)
                        [PSCredential]::new("user_$Target", (ConvertTo-SecureString "pass_$Target" -AsPlainText -Force))
                    }
                    $result = Get-StoredCredential
                    $result.Id | Should -Be "foo","bar"
                    $result.Credential.GetNetworkCredential().Password | Should -Be "pass_foo","pass_bar"
                }
            }
        }
    }
}