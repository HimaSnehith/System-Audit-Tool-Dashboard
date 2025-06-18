Write-Output "Windows Account Lockout & Password Policy Audit"
Write-Output "================================================"

try {
    # Execute 'net accounts' command and capture its output as an array of lines
    $netAccountsOutputLines = (net accounts | Out-String).Split([System.Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)

    Write-Output "Account Policies (Effective Local Policy):"
    Write-Output "------------------------------------------"

    # Define a hash table to store parsed values
    $policySettings = @{
        "LockoutThreshold" = "Not Configured/Unknown"
        "LockoutDuration" = "Not Configured/Unknown"
        "LockoutObservationWindow" = "Not Configured/Unknown"
        "MinimumPasswordLength" = "Not Configured/Unknown"
        "MaximumPasswordAge" = "Not Configured/Unknown"
        "MinimumPasswordAge" = "Not Configured/Unknown"
        "PasswordHistory" = "Not Configured/Unknown"
    }

    # Parse the output line by line
    foreach ($line in $netAccountsOutputLines) {
        $trimmedLine = $line.Trim() # Trim leading/trailing whitespace from the line

        if ($trimmedLine -match "^Lockout threshold:\s+(\S.*)") {
            $policySettings["LockoutThreshold"] = $matches[1].Trim()
        } elseif ($trimmedLine -match "^Lockout duration \(minutes\):\s+(\S.*)") {
            $policySettings["LockoutDuration"] = $matches[1].Trim()
        } elseif ($trimmedLine -match "^Lockout observation window \(minutes\):\s+(\S.*)") {
            $policySettings["LockoutObservationWindow"] = $matches[1].Trim()
        } elseif ($trimmedLine -match "^Minimum password length:\s+(\S.*)") {
            $policySettings["MinimumPasswordLength"] = $matches[1].Trim()
        } elseif ($trimmedLine -match "^Maximum password age \(days\):\s+(\S.*)") {
            $policySettings["MaximumPasswordAge"] = $matches[1].Trim()
        } elseif ($trimmedLine -match "^Minimum password age \(days\):\s+(\S.*)") {
            $policySettings["MinimumPasswordAge"] = $matches[1].Trim()
        } elseif ($trimmedLine -match "^Password history maintained:\s+(\S.*)") {
            $policySettings["PasswordHistory"] = $matches[1].Trim()
        }
    }

    # Display the parsed policies with clean labels
    Write-Output "Lockout Threshold: $($policySettings.LockoutThreshold -replace 'None', 'Not Configured') attempts"
    Write-Output "Lockout Duration: $($policySettings.LockoutDuration -replace 'UNLIMITED', 'Unlimited') minutes"
    Write-Output "Reset Lockout Counter After: $($policySettings.LockoutObservationWindow -replace 'UNLIMITED', 'Unlimited') minutes"
    Write-Output "Minimum Password Length: $($policySettings.MinimumPasswordLength -replace '0', 'Not Configured') characters"
    Write-Output "Maximum Password Age: $($policySettings.MaximumPasswordAge -replace 'UNLIMITED', 'Unlimited') days"
    Write-Output "Minimum Password Age: $($policySettings.MinimumPasswordAge -replace '0', 'Not Configured') days"
    Write-Output "Password History: $($policySettings.PasswordHistory -replace 'None', '0') passwords"


} catch {
    Write-Output "⚠️ An error occurred during policy retrieval: $_"
    Write-Output "Error details: $($_.Exception.Message)"
    Write-Output "Please ensure 'net accounts' command is available and executable."
}

Write-Output "`nRecommendations (CIS Benchmark Aligned):"
Write-Output "=========================================="
Write-Output "1. Account Lockout Threshold: Set to a value between 5-10 invalid logon attempts (e.g., 5). This prevents brute-force attacks while allowing for legitimate user error."
Write-Output "2. Account Lockout Duration: Set to at least 15 minutes. This ensures a lockout period that discourages attackers."
Write-Output "3. Reset Account Lockout Counter After: Should be set to match the lockout duration (e.g., 15 minutes). This determines how long an account remains locked out."
Write-Output "4. Minimum Password Length: Enforce a minimum length of at least 14 characters for strong passwords."
Write-Output "5. Maximum Password Age: Set to 90 days or less. This forces regular password changes to reduce the risk of compromised credentials."
Write-Output "6. Minimum Password Age: Set to at least 1 day. This prevents users from immediately changing their password back to a previous one."
Write-Output "7. Password History: Maintain a history of at least 24 remembered passwords. This prevents users from reusing recent passwords."
Write-Output "8. Password Complexity: Ensure password complexity requirements are enabled and enforced (e.g., requiring a mix of uppercase, lowercase, numbers, and symbols). This is typically configured via Group Policy."