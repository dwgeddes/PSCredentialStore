# PSCredentialStore

A cross-platform PowerShell module for securely storing and retrieving credentials using the operating system's native credential store.

## Features

- Securely store and retrieve credentials across different platforms
- Uses native OS credential stores:
  - Windows: Windows Credential Manager
  - macOS: Keychain
  - Linux: Secret Service API (GNOME Keyring, KWallet)
- Simple, consistent PowerShell interface across all platforms
- Safely handles secure credentials without exposing sensitive information

## Requirements

- PowerShell 5.1 or later
- For Linux: `libsecret-tools` package (provides `secret-tool` command)

## Installation

### From PowerShell Gallery (Recommended)

```powershell
Install-Module -Name PSCredentialStore -Scope CurrentUser
```

### Manual Installation

1. Download or clone this repository
2. Copy the PSCredentialStore folder to a location in your `$PSModulePath`
3. Import the module with `Import-Module PSCredentialStore`

## Usage

### Storing a credential

```powershell
# Prompt for credentials and store them
$cred = Get-Credential
Set-StoredCredential -Target "MyApplication" -Credential $cred

# Or create and store credentials directly
Set-StoredCredential -Target "DatabaseServer" -UserName "dbuser" -Password (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force)
```

### Retrieving a credential

```powershell
# Get a stored credential
$cred = Get-StoredCredential -Target "MyApplication"

# Use the credential
$username = $cred.UserName
$password = $cred.GetNetworkCredential().Password  # Only use this in secure contexts!
```

### Listing all credentials

```powershell
# List all stored credentials
Get-StoredCredential

# Store the results for further processing
$allCreds = Get-StoredCredential
foreach ($item in $allCreds) {
    Write-Host "Target: $($item.Target), Username: $($item.Credential.UserName)"
}
```

### Removing a credential

```powershell
# Remove a stored credential
Remove-StoredCredential -Target "MyApplication"
```

### Testing if a credential exists

```powershell
if (Test-StoredCredential -Target "MyApplication") {
    Write-Host "Credential exists!"
} else {
    Write-Host "Credential not found."
}
```

## Commands

| Command | Description |
|---------|-------------|
| `Set-StoredCredential` | Stores a credential in the OS credential store |
| `Get-StoredCredential` | Retrieves a credential from the OS credential store or lists all credentials when called without parameters |
| `Remove-StoredCredential` | Removes a credential from the OS credential store |
| `Test-StoredCredential` | Tests if a credential exists in the OS credential store |

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.