Write-Output "`nWindows Driver Status & Integrity Audit"
Write-Output "========================================"

try {
    # Get all Plug and Play signed drivers using Get-CimInstance (faster than Get-WmiObject)
    $allDrivers = Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop

    # --- Section 1: Drivers with Detected Problems ---
    Write-Output "`n[Audit Result: Drivers with Detected Problems]"
    Write-Output "------------------------------------------------"
    
    $problematicDrivers = $allDrivers | Where-Object { $_.ProblemCode -ne 0 }

    if ($problematicDrivers.Count -eq 0) {
        Write-Output "✅ No drivers reported with active problems."
    } else {
        Write-Output "⚠ The following $($problematicDrivers.Count) drivers have reported issues:"
        $problematicDrivers | ForEach-Object {
            $problemCode = if ($_.ProblemCode -ne $null) { $_.ProblemCode } else { "No detected issues" }
            $infFile = if ($_.InfFilename -ne $null) { $_.InfFilename } else { "Not available" }

            Write-Output " - Device: $($_.DeviceName)"
            Write-Output "   Manufacturer: $($_.Manufacturer)"
            Write-Output "   Driver Version: $($_.DriverVersion)"
            Write-Output "   Problem Code: $problemCode"
            Write-Output "   INF File: $infFile"
            Write-Output "------------------------------------"
        }
    }
    
    # --- Section 2: Unsigned Drivers Audit ---
    Write-Output "`n[Audit Result: Unsigned Drivers]"
    Write-Output "--------------------------------"
    
    $unsignedDrivers = $allDrivers | Where-Object { -not $_.DriverSigned -and $_.ProblemCode -eq 0 }

    if ($unsignedDrivers.Count -eq 0) {
        Write-Output "✅ No unsigned drivers found."
    } else {
        Write-Output "⚠ WARNING: The following $($unsignedDrivers.Count) active drivers are NOT digitally signed:"
        $unsignedDrivers | ForEach-Object {
            $infFile = if ($_.InfFilename -ne $null) { $_.InfFilename } else { "Not available" }
            $signer = if ($_.Signer -ne $null) { $_.Signer } else { "Unknown Signer (Requires verification)" }

            Write-Output " - Device: $($_.DeviceName)"
            Write-Output "   Manufacturer: $($_.Manufacturer)"
            Write-Output "   Driver Version: $($_.DriverVersion)"
            Write-Output "   INF File: $infFile"
            Write-Output "   Signer: $signer"
            Write-Output "------------------------------------"
        }
        Write-Output "⚠ Unsigned drivers can pose a security risk and should be investigated."
    }

} catch {
    Write-Output "⚠️ Error checking driver status: $($_.Exception.Message)"
    Write-Output "Please run PowerShell as Administrator for a full audit."
    return
}

Write-Output "`nRecommendations (CIS Benchmark Aligned):"
Write-Output "==========================================="
Write-Output "1. Resolve Problematic Drivers: Investigate drivers reporting a 'Problem Code'. Update, reinstall, or disable them."
Write-Output "2. Enforce Driver Signing: Enable Windows driver signature verification via Group Policy."
Write-Output "3. Remove Unsigned Drivers: Ensure all drivers are properly signed by trusted vendors."
Write-Output "4. Update Drivers Regularly: Keep drivers up-to-date to prevent security vulnerabilities."
Write-Output "5. Source Drivers from Trusted Vendors: Avoid third-party sources, use OEM downloads."
Write-Output "6. Periodic Audits: Conduct regular scans for unsigned or faulty drivers."