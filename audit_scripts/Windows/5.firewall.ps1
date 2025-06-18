Write-Output "Windows Firewall Status Audit"
Write-Output "=============================="

try {
    # Get all network firewall profiles
    $profiles = Get-NetFirewallProfile -ErrorAction Stop

    if ($profiles.Count -eq 0) {
        Write-Output "⚠️ No firewall profiles found on this system. This is unexpected."
    } else {
        Write-Output "Details for Firewall Profiles:"
        Write-Output "----------------------------------------"

        foreach ($profile in $profiles) {
            Write-Output "Profile: $($profile.Name)"
            Write-Output "  Enabled: $($profile.Enabled)"

            # Determine the status text based on enabled state
            if ($profile.Enabled) {
                Write-Output "    Status: ✅ Active"
            } else {
                Write-Output "    Status: ❌ Disabled"
            }

            Write-Output "  Default Inbound Action: $($profile.DefaultInboundAction)"
            Write-Output "  Default Outbound Action: $($profile.DefaultOutboundAction)"
            Write-Output "  Allow Unicast Response To Multicast: $($profile.AllowUnicastResponseToMulticast)" # Relevant security setting
            Write-Output "  Allow Local Policy Merge: $($profile.AllowLocalPolicyMerge)"                 # Important for enterprise environments
            Write-Output "----------------------------------------"
        }

        # --- Audit Firewall Logging Settings ---
        Write-Output "`n[Firewall Logging Settings]"
        Write-Output "---------------------------"

        $logSettings = Get-NetFirewallSetting -ErrorAction Stop
        
        Write-Output "Log File Location: $($logSettings.LogFileName)"
        Write-Output "Log Max Size (KB): $($logSettings.LogMaxSizeKilobytes)"
        
        $inboundLoggingEnabled = $false
        $outboundLoggingEnabled = $false

        # Check logging settings for each profile
        foreach ($profile in $profiles) {
            $currentProfileSettings = (Get-NetFirewallProfile -Name $profile.Name -ErrorAction SilentlyContinue).Log
            if ($currentProfileSettings) {
                if ($currentProfileSettings.LogBlocked -eq 'True') { $inboundLoggingEnabled = $true }
                if ($currentProfileSettings.LogSuccessful -eq 'True') { $outboundLoggingEnabled = $true }
            }
        }
        
        if ($inboundLoggingEnabled) {
            Write-Output "Inbound Dropped Packets Logging: ✅ Enabled (on at least one profile)"
        } else {
            Write-Output "Inbound Dropped Packets Logging: ⚠ WARNING: Disabled (for all profiles)"
        }

        if ($outboundLoggingEnabled) {
            Write-Output "Successful Connections Logging: ✅ Enabled (on at least one profile)"
        } else {
            Write-Output "Successful Connections Logging: ⚠ WARNING: Disabled (for all profiles)"
        }
    }

} catch {
    Write-Output "⚠️ Error fetching firewall profile settings: $($_.Exception.Message)"
    Write-Output "Please ensure PowerShell is run with Administrator privileges."
}

Write-Output "`nRecommendations (CIS Benchmark Aligned):"
Write-Output "==========================================="
Write-Output "1. Enable All Profiles: Ensure that all Windows Firewall profiles (Domain, Private, Public) are enabled (`Set-NetFirewallProfile -Name <ProfileName> -Enabled True`)."
Write-Output "2. Default Inbound Action (Block): Configure the default inbound action for all profiles to 'Block' to prevent unsolicited incoming connections (`Set-NetFirewallProfile -Name <ProfileName> -DefaultInboundAction Block`)."
Write-Output "3. Default Outbound Action (Allow): The default outbound action can typically remain 'Allow', but for high-security environments, it may be set to 'Block' with explicit outbound rules."
Write-Output "4. Enable Logging for Dropped Packets: Configure Windows Firewall to log dropped packets for all profiles (`Set-NetFirewallProfile -Name <ProfileName> -LogBlocked True`). This is crucial for security monitoring and troubleshooting."
Write-Output "5. Consider Logging Successful Connections: For more comprehensive auditing, consider enabling logging for successful connections, though this can generate a large volume of logs (`Set-NetFirewallProfile -Name <ProfileName> -LogSuccessful True`)."
Write-Output "6. Log File Size & Location: Review and adjust the firewall log file size and location as needed to ensure sufficient retention and storage space."
Write-Output "7. Monitor Firewall Logs: Regularly monitor and analyze Windows Firewall logs for suspicious activity, unauthorized connection attempts, and policy violations."
Write-Output "8. Restrict Remote Management: Ensure that remote management of Windows Firewall is appropriately restricted or disabled if not actively used, as per CIS Benchmark recommendations."