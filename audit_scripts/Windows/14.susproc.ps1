Write-Output "System Process Audit"
Write-Output "======================"

try {
    $suspiciousProcesses = Get-Process | Where-Object { $_.Path -and ($_.Path -like "*temp*" -or $_.Path -like "*AppData*") }
Write-Output "RECOMMENDATION: Scan suspicious processes running from Temp/AppData with Defender." 

    if ($suspiciousProcesses.Count -eq 0) {
        Write-Output "✅ No suspicious processes found running from Temp or AppData."
    } else {
        Write-Output "Suspicious Processes:"
        foreach ($proc in $suspiciousProcesses) {
            Write-Output "- $($proc.ProcessName) ($($proc.Path))"
        }
    }
} catch {
    Write-Output "⚠️ Error fetching process information: $_"
}

Write-Output "`nRecommendations:"
Write-Output "=================="
Write-Output "1. Investigate processes running from unusual locations."
