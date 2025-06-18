Write-Output "`nWindows Local User Account Audit"
Write-Output "=================================="

try {
    $users = Get-LocalUser -ErrorAction Stop

    if ($users.Count -eq 0) {
        Write-Output "`n✅ No local user accounts found on this system."
    } else {
        Write-Output "`nDetails for $($users.Count) Local User Accounts:"
        Write-Output "----------------------------------------------"

        foreach ($user in $users) {
            Write-Output "`nUser: $($user.Name)"
            Write-Output "  SID: $($user.SID.Value)"
            Write-Output "  Description: $($user.Description)"
            Write-Output "  Enabled: $($user.Enabled)"
            Write-Output "  Password Required: $($user.PasswordRequired)"
            Write-Output "  Password Changeable: $($user.PasswordChangeable)"
            Write-Output "  Password Expires: $($user.PasswordExpires)"

            # Handle Last Logon
            $lastLogon = if ($user.LastLogon -and $user.LastLogon -ne [datetime]'1601-01-01 05:30:00') {
                $user.LastLogon.ToString("yyyy-MM-dd HH:mm:ss")
            } else {
                "Never Logged In / N/A"
            }
            Write-Output "  Last Logon: $lastLogon"

            # Handle Password Last Set
            $passwordSet = if ($user.PasswordLastSet -and $user.PasswordLastSet -ne [datetime]'1601-01-01 05:30:00') {
                $user.PasswordLastSet.ToString("yyyy-MM-dd HH:mm:ss")
            } else {
                "Never Set / N/A"
            }
            Write-Output "  Password Last Set: $passwordSet"

            # Group Membership
            $groups = Get-LocalGroup | Where-Object {
                (Get-LocalGroupMember $_.Name -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $user.Name })
            }

            if ($groups) {
                Write-Output "  Member of Groups:"
                foreach ($group in $groups) {
                    Write-Output "    - $($group.Name)"
                }
            } else {
                Write-Output "  Member of Groups: None"
            }

            Write-Output "----------------------------------------------"
        }
    }
} catch {
    Write-Output "`n⚠️ Error fetching local user accounts: $($_.Exception.Message)"
    Write-Output "This may indicate insufficient privileges."
    Write-Output "➡️ Run PowerShell as **Administrator**."
}

# Recommendations
Write-Output "`nRecommendations (CIS Benchmark Aligned):"
Write-Output "==========================================="
Write-Output "1. Disable inactive accounts to reduce attack surface."
Write-Output "2. Ensure all accounts have meaningful, identifying descriptions."
Write-Output "3. Enforce strong password policies (min. 14 characters, complexity, expiration)."
Write-Output "4. Monitor privileged group memberships (Administrators, etc.) regularly."
Write-Output "5. Avoid shared accounts; assign unique credentials per user."
Write-Output "6. Confirm all accounts require passwords and have expiry policies enforced."
