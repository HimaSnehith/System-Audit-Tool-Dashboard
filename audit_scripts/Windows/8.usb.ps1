Write-Output "USB Access Control Audit"
Write-Output "========================="

try {
    $storageDevices = Get-WmiObject Win32_DiskDrive | Where-Object { $_.InterfaceType -eq "USB" }

    if ($storageDevices.Count -eq 0) {
        Write-Output "✅ No unauthorized USB storage devices detected."
    } else {
        foreach ($device in $storageDevices) {
            Write-Output "Detected USB Device:"
            Write-Output " - Model: $($device.Model)"
            Write-Output " - Serial Number: $($device.SerialNumber)"
        }
    }
} catch {
    Write-Output "⚠️ Error checking USB devices: $_"
}

Write-Output "`nRecommendations:"
Write-Output "=================="
Write-Output "1. Block USB access except for whitelisted devices."
