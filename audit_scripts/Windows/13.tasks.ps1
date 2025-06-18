Write-Output "Scheduled Tasks Audit"
Write-Output "======================"

try {
    $tasks = Get-ScheduledTask | Where-Object { $_.State -eq "Ready" -and $_.TaskPath -notlike "\Microsoft*" }
Write-Output "RECOMMENDATION: Review scheduled tasks and disable those not required." 

    if ($tasks.Count -eq 0) {
        Write-Output "✅ No suspicious scheduled tasks found."
    } else {
        Write-Output "Custom Scheduled Tasks:"
        foreach ($task in $tasks) {
            Write-Output "- $($task.TaskName) ($($task.TaskPath))"
        }
    }
} catch {
    Write-Output "⚠️ Error fetching scheduled tasks: $_"
}

Write-Output "`nRecommendations:"
Write-Output "=================="
Write-Output "1. Review non-Microsoft tasks for legitimacy."
