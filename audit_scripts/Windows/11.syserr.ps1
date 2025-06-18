Write-Output "System Event Log Audit"
Write-Output "========================"

try {
    $recentErrors = Get-EventLog -LogName System -EntryType Error -Newest 10
Write-Output "RECOMMENDATION: Investigate and resolve repeated system errors to ensure stability." 

    if ($recentErrors.Count -eq 0) {
        Write-Output "✅ No recent critical system errors found."
    } else {
        Write-Output "Recent System Errors:"
        foreach ($eventError in $recentErrors) { # Renamed variable to $eventError
            Write-Output "- [$($eventError.TimeGenerated)] $($eventError.Source): $($eventError.Message)"
        }
    }
} catch {
    Write-Output "⚠️ Error fetching system logs: $_"
}

Write-Output "`nRecommendations:"
Write-Output "=================="
Write-Output "1. Regularly monitor the System Event Logs for errors."