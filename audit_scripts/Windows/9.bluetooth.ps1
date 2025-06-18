Write-Output "`nBluetooth Device Audit"
Write-Output "========================"

try {
    # Get all Bluetooth devices
    $bluetoothDevices = Get-PnpDevice -Class Bluetooth | Sort-Object Status, FriendlyName

    if (!$bluetoothDevices -or $bluetoothDevices.Count -eq 0) {
        Write-Output "✅ No Bluetooth devices found on this system."
    } else {
        foreach ($device in $bluetoothDevices) {
            Write-Output "Device Name         : $($device.FriendlyName)"
            Write-Output "Instance ID         : $($device.InstanceId)"
            Write-Output "Status              : $($device.Status)"
            Write-Output "Driver              : $($device.Driver)}"
            Write-Output "Problem Code        : $($device.Problem)"
            Write-Output "Manufacturer        : $($device.Manufacturer)"
            Write-Output "---------------------------------------------"
        }
    }
} catch {
    Write-Output "⚠️ Error fetching Bluetooth device information: $($_.Exception.Message)"
}

Write-Output "`nRecommendations (CIS Benchmark Aligned):"
Write-Output "=========================================="
Write-Output "1. Disable Bluetooth when not in use to minimize wireless attack surface (CIS Control 3.6)."
Write-Output "2. Uninstall unnecessary Bluetooth drivers or services."
Write-Output "3. Use Group Policy or MDM to disable Bluetooth on systems where it is not explicitly required."
Write-Output "4. Audit device state regularly to detect unauthorized Bluetooth hardware."
Write-Output "5. Restrict user permissions to prevent enabling Bluetooth without administrative rights."
Write-Output "6. Ensure driver signing enforcement is enabled to block unverified Bluetooth drivers."