Write-Output "Windows Downloaded Files Audit"
Write-Output "=============================="

try {
    $downloadFolder = "$env:USERPROFILE\Downloads"
    Write-Output "Scanning Download folder: $downloadFolder"

    # Check if the downloads folder exists
    if (-not (Test-Path $downloadFolder -PathType Container)) {
        Write-Output "⚠️ Error: Downloads folder not found at '$downloadFolder'."
        Write-Output "Please ensure the user profile and Downloads directory exist."
        # Exit script cleanly if folder doesn't exist
        return
    }

    $files = Get-ChildItem -Path $downloadFolder -File -ErrorAction SilentlyContinue

    if ($files.Count -eq 0) {
        Write-Output "✅ No files found in the Downloads folder."
    } else {
        Write-Output "Files found in Downloads ($($files.Count) files):"
        foreach ($file in $files) {
            # Format file size for better readability (Bytes, KB, MB)
            $displaySize = ""
            if ($file.Length -ge 1GB) {
                $displaySize = "$([Math]::Round($file.Length / 1GB, 2)) GB"
            } elseif ($file.Length -ge 1MB) {
                $displaySize = "$([Math]::Round($file.Length / 1MB, 2)) MB"
            } elseif ($file.Length -ge 1KB) {
                $displaySize = "$([Math]::Round($file.Length / 1KB, 2)) KB"
            } else {
                $displaySize = "$($file.Length) Bytes"
            }

            Write-Output "- $($file.Name) | Last Modified: $($file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")) | Size: $displaySize"
        }
    }
} catch {
    Write-Output "⚠️ Error scanning downloaded files: $_"
}

Write-Output "`nRecommendations:"
Write-Output "=================="
Write-Output "1. Regular Cleanup: Regularly clean up the Downloads folder to reduce potential attack surface and free up disk space."
Write-Output "2. Execution Caution: Avoid executing files directly from the Downloads folder without prior inspection and verification."
Write-Output "3. Antivirus Scan: Always scan downloaded files with a reputable antivirus solution before opening or executing them."
Write-Output "4. Content Review: Be cautious of unexpected file types, unusually large files, or files from unknown sources, as they may indicate malicious activity."
Write-Output "5. Browser Settings: Configure your web browser to prompt for a download location instead of automatically saving to Downloads."