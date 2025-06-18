Write-Output "Windows Account Lockout & Login Policy Audit"
Write-Output "============================================="

try {
    $lockoutThreshold = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\Netlogon\Parameters").LockoutThreshold
    $lockoutDuration = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\Netlogon\Parameters").LockoutDuration
    $resetLockout = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\Netlogon\Parameters").ResetCount

    Write-Output "Account Lockout Policy:"
    Write-Output "------------------------"
    Write-Output "Lockout Threshold: $lockoutThreshold attempts"
    Write-Output "Lockout Duration: $lockoutDuration minutes"
    Write-Output "Reset Lockout Counter After: $resetLockout minutes"
} catch {
    Write-Output "⚠️ Error fetching Account Lockout Policy: $_"
}

Write-Output "`nRecommendations:"
Write-Output "=================="
Write-Output "1. Lockout threshold should be set to 5-10 attempts."
Write-Output "2. Lockout duration should be at least 15 minutes."
Write-Output "3. Reset counter should match security policy requirements."
