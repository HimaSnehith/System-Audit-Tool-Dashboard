# Detect Windows version
$osInfo = Get-WmiObject -Class Win32_OperatingSystem
$osName = $osInfo.Caption
$osVersion = [System.Environment]::OSVersion.Version

# Function to display formatted output
function Write-ColorOutput {
    param(
        [string]$Text,
        [string]$Status,
        [int]$IndentLevel = 0
    )
    
    $indent = "    " * $IndentLevel
    $statusColor = switch ($Status) {
        "OK" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "White" }
    }
    
    Write-Host "$indent$Text" -ForegroundColor $statusColor
}

# Function to fetch password policy settings
function Get-PasswordPolicy {
    Write-ColorOutput "Password Policy Settings:" "OK"
    Write-ColorOutput "=========================" "OK"
    $netAccounts = net accounts
    foreach ($line in $netAccounts) {
        if ($line -match '^(Force user logoff how long\?|Minimum password age|Maximum password age|Minimum password length|Length of password history|Lockout threshold|Lockout duration|Lockout observation window).*') {
            Write-ColorOutput $line "OK" 1
        }
    }
}

# Check local user account security settings
Write-ColorOutput "System Information:" "OK"
Write-ColorOutput "Operating System: $osName" "OK" 1
Write-ColorOutput "Version: $($osInfo.Version)" "OK" 1

Write-ColorOutput "`nChecking Local User Accounts:" "OK"
Write-ColorOutput "================================" "OK"

$users = Get-LocalUser | Sort-Object Name
Write-Output "RECOMMENDATION: Enforce password expiration and complexity policy for local accounts." 
foreach ($user in $users) {
    Write-ColorOutput "`nUser Account: $($user.Name)" "OK"
    Write-ColorOutput "------------------------" "OK"
    
    # Password Required Status
    $passwordStatus = if ($user.PasswordRequired) { "Yes" } else { "No" }
    Write-ColorOutput "Password Required: $passwordStatus" $(if ($user.PasswordRequired) { "OK" } else { "Warning" }) 1
    
    # Password Expiry
    $expiryStatus = if ($user.PasswordNeverExpires) { "Yes" } else { "No" }
    Write-ColorOutput "Password Never Expires: $expiryStatus" $(if ($user.PasswordNeverExpires) { "Warning" } else { "OK" }) 1
    
    # Account Enabled Status
    Write-ColorOutput "Account Enabled: $($user.Enabled)" $(if ($user.Enabled) { "OK" } else { "Warning" }) 1
}

# Get system-wide password policies
Get-PasswordPolicy

Write-ColorOutput "`nRecommendations:" "OK"
Write-ColorOutput "================" "OK"
Write-ColorOutput "1. Enforce strong password policies for all user accounts" "Warning" 1
Write-ColorOutput "2. Set password expiration policies for all accounts" "Warning" 1
Write-ColorOutput "3. Regularly review inactive accounts and disable them" "Warning" 1
Write-ColorOutput "4. Ensure guest accounts are disabled" "Warning" 1
