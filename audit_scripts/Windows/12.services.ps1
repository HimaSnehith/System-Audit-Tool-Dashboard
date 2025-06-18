Write-Output "Windows Services Audit"
Write-Output "======================="

try {
    $suspiciousServices = Get-Service | Where-Object { $_.StartType -eq "Automatic" -and $_.Status -ne "Running" }
Write-Output "RECOMMENDATION: Disable non-essential auto-start services that are not running." 

    if ($suspiciousServices.Count -eq 0) {
        Write-Output "✅ No suspicious services found."
    } else {
        Write-Output "Services set to start Automatically but not running:"
        foreach ($service in $suspiciousServices) {
            Write-Output "- $($service.Name) ($($service.DisplayName))"
        }
    }
} catch {
    Write-Output "⚠️ Error fetching service information: $_"
}

Write-Output "`nRecommendations:"
Write-Output "=================="
Write-Output "1. Investigate services that are set to start automatically but are not running."
