Write-Output "`nApplication-Level Firewall Rules Audit"
Write-Output "========================================="

try {
    $firewallRules = Get-NetFirewallRule -PolicyStore ActiveStore | Where-Object {
        $_.Enabled -eq $true
    }

    $appRules = foreach ($rule in $firewallRules) {
        $appFilter = Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $rule -ErrorAction SilentlyContinue
        if ($appFilter -and $appFilter.Program -and $appFilter.Program -ne "Any") {
            [PSCustomObject]@{
                Name      = $rule.Name
                Program   = $appFilter.Program
                Action    = $rule.Action
                Direction = $rule.Direction
            }
        }
    }

    if (!$appRules -or $appRules.Count -eq 0) {
        Write-Output "✅ No specific application-level firewall rules found or all are system defaults."
    } else {
        foreach ($rule in $appRules) {
            Write-Output "Rule Name : $($rule.Name)"
            Write-Output "Program   : $($rule.Program)"
            Write-Output "Action    : $($rule.Action)"
            Write-Output "Direction : $($rule.Direction)"
            Write-Output "----------------------------------------"
        }
    }
}
catch {
    Write-Output "⚠️ Error fetching application firewall rules: $($_.Exception.Message)"
}

Write-Output "`nRecommendations (CIS Aligned):"
Write-Output "==============================="
Write-Output "1. Remove unused or unnecessary application-level firewall rules."
Write-Output "2. Ensure rules are properly scoped to limit exposure."
Write-Output "3. Review rules that allow outbound access for unknown apps."
Write-Output "4. Replace 'Any' program rules with specific application paths wherever possible."
Write-Output "5. Periodically audit all auto-generated rules added by installers."