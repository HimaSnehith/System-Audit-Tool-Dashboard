# Wi-Fi Profile Security Audit Script
# CIS Benchmark Compliance Check for Windows Systems
# Author: Security Audit Team
# Version: 2.0

param(
    [switch]$Detailed,
    [switch]$ExportCSV,
    [string]$OutputPath = ".\WiFi_Audit_Report.csv"
)

# Initialize variables
$results = @()
$securityIssues = @()

Write-Host "`nWi-Fi Profile Security Audit" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Analyzing saved Wi-Fi profiles for security compliance..." -ForegroundColor Yellow
Write-Host "CIS Controls: 1.7, 4.1, 12.1 - Wireless Network Security" -ForegroundColor Green
Write-Host ""

# Function to evaluate security risk
function Get-SecurityRisk {
    param($auth, $encryption, $connectionMode)
    
    $riskLevel = "LOW"
    $issues = @()
    
    # Check authentication method
    if ($auth -match "Open") {
        $riskLevel = "CRITICAL"
        $issues += "Open authentication (no security)"
    }
    elseif ($auth -match "WEP") {
        $riskLevel = "HIGH"
        $issues += "WEP authentication (deprecated)"
    }
    elseif ($auth -match "WPA-Personal") {
        $riskLevel = "MEDIUM"
        $issues += "WPA (consider upgrading to WPA2/WPA3)"
    }
    
    # Check encryption
    if ($encryption -match "None") {
        $riskLevel = "CRITICAL"
        $issues += "No encryption"
    }
    elseif ($encryption -match "WEP") {
        $riskLevel = "HIGH"
        $issues += "WEP encryption (easily breakable)"
    }
    elseif ($encryption -match "TKIP") {
        $riskLevel = "MEDIUM"
        $issues += "TKIP encryption (consider AES)"
    }
    
    # Check connection mode
    if ($connectionMode -match "Connect automatically") {
        $issues += "Auto-connect enabled"
    }
    
    return @{
        Risk = $riskLevel
        Issues = $issues
    }
}

try {
    # Check if wireless service is running
    $wlanService = Get-Service -Name "WlanSvc" -ErrorAction SilentlyContinue
    if ($wlanService -eq $null -or $wlanService.Status -ne "Running") {
        Write-Host "WARNING: WLAN AutoConfig service is not running. Starting audit with limited capabilities..." -ForegroundColor Yellow
    }

    # Get all saved Wi-Fi profiles
    Write-Host "Discovering Wi-Fi profiles..." -ForegroundColor White
    $profilesOutput = netsh wlan show profiles 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to access Wi-Fi profiles. Ensure you have administrator privileges."
    }
    
    $profiles = $profilesOutput | Select-String "All User Profile" | ForEach-Object {
        if ($_ -match "All User Profile\s*:\s*(.+)") {
            $matches[1].Trim()
        }
    }
    
    if (!$profiles -or $profiles.Count -eq 0) {
        Write-Host "SUCCESS: No saved Wi-Fi profiles found on this system." -ForegroundColor Green
        Write-Host "This reduces wireless attack surface area." -ForegroundColor Green
    }
    else {
        Write-Host "Found $($profiles.Count) saved Wi-Fi profile(s)" -ForegroundColor White
        Write-Host "=" * 80 -ForegroundColor Gray
        
        $profileCount = 0
        foreach ($profile in $profiles) {
            $profileCount++
            Write-Host "`n[$profileCount/$($profiles.Count)] Analyzing: $profile" -ForegroundColor Cyan
            
            try {
                # Fetch detailed profile information
                $profileDetails = netsh wlan show profile name="$profile" key=clear 2>&1
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "   ERROR: Unable to retrieve details for profile: $profile" -ForegroundColor Red
                    continue
                }
                
                # Parse profile details with better regex
                $ssid = ($profileDetails | Select-String "SSID name" | Select-Object -First 1) -replace ".*SSID name\s*:\s*", "" -replace '"', ''
                $auth = ($profileDetails | Select-String "Authentication\s*:" | Select-Object -First 1) -replace ".*Authentication\s*:\s*", ""
                $encryption = ($profileDetails | Select-String "Encryption\s*:" | Select-Object -First 1) -replace ".*Encryption\s*:\s*", ""
                $connectionMode = ($profileDetails | Select-String "Connection mode\s*:" | Select-Object -First 1) -replace ".*Connection mode\s*:\s*", ""
                $autoConnect = ($profileDetails | Select-String "Connect automatically\s*:" | Select-Object -First 1) -replace ".*Connect automatically\s*:\s*", ""
                
                # Security assessment
                $securityAssessment = Get-SecurityRisk -auth $auth -encryption $encryption -connectionMode $autoConnect
                
                # Display results
                Write-Host "   SSID              : $ssid" -ForegroundColor White
                Write-Host "   Authentication    : $auth" -ForegroundColor White
                Write-Host "   Encryption        : $encryption" -ForegroundColor White
                Write-Host "   Auto-Connect      : $autoConnect" -ForegroundColor White
                
                # Security status with color coding
                $riskColor = switch ($securityAssessment.Risk) {
                    "CRITICAL" { "Red" }
                    "HIGH" { "DarkRed" }
                    "MEDIUM" { "Yellow" }
                    "LOW" { "Green" }
                    default { "White" }
                }
                
                Write-Host "   Security Risk     : $($securityAssessment.Risk)" -ForegroundColor $riskColor
                
                if ($securityAssessment.Issues.Count -gt 0) {
                    Write-Host "   Security Issues   :" -ForegroundColor Yellow
                    foreach ($issue in $securityAssessment.Issues) {
                        Write-Host "      * $issue" -ForegroundColor Yellow
                    }
                    $securityIssues += [PSCustomObject]@{
                        Profile = $profile
                        SSID = $ssid
                        Risk = $securityAssessment.Risk
                        Issues = ($securityAssessment.Issues -join "; ")
                    }
                }
                
                # Store results for export
                $results += [PSCustomObject]@{
                    ProfileName = $profile
                    SSID = $ssid
                    Authentication = $auth
                    Encryption = $encryption
                    AutoConnect = $autoConnect
                    SecurityRisk = $securityAssessment.Risk
                    SecurityIssues = ($securityAssessment.Issues -join "; ")
                    RecommendedAction = if ($securityAssessment.Risk -in @("CRITICAL", "HIGH")) { "DELETE IMMEDIATELY" } 
                                       elseif ($securityAssessment.Risk -eq "MEDIUM") { "REVIEW AND UPGRADE" } 
                                       else { "MONITOR" }
                }
                
                Write-Host "   " + ("-" * 60) -ForegroundColor Gray
                
            }
            catch {
                Write-Host "   ERROR: Error processing profile '$profile': $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}
catch {
    Write-Host "CRITICAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   * Run as Administrator" -ForegroundColor Yellow
    Write-Host "   * Ensure WLAN AutoConfig service is running" -ForegroundColor Yellow
    Write-Host "   * Check if wireless adapter is enabled" -ForegroundColor Yellow
}

# Summary and Recommendations
Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
Write-Host "SECURITY SUMMARY & CIS BENCHMARK RECOMMENDATIONS" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan

if ($securityIssues.Count -gt 0) {
    Write-Host "`nSECURITY ISSUES DETECTED: $($securityIssues.Count)" -ForegroundColor Red
    
    $criticalIssues = $securityIssues | Where-Object { $_.Risk -eq "CRITICAL" }
    $highIssues = $securityIssues | Where-Object { $_.Risk -eq "HIGH" }
    $mediumIssues = $securityIssues | Where-Object { $_.Risk -eq "MEDIUM" }
    
    if ($criticalIssues.Count -gt 0) {
        Write-Host "`nCRITICAL RISK PROFILES (DELETE IMMEDIATELY):" -ForegroundColor Red
        foreach ($issue in $criticalIssues) {
            Write-Host "   * $($issue.Profile) - $($issue.Issues)" -ForegroundColor Red
            Write-Host "     Command: netsh wlan delete profile name='$($issue.Profile)'" -ForegroundColor White
        }
    }
    
    if ($highIssues.Count -gt 0) {
        Write-Host "`nHIGH RISK PROFILES:" -ForegroundColor DarkRed
        foreach ($issue in $highIssues) {
            Write-Host "   * $($issue.Profile) - $($issue.Issues)" -ForegroundColor DarkRed
        }
    }
    
    if ($mediumIssues.Count -gt 0) {
        Write-Host "`nMEDIUM RISK PROFILES:" -ForegroundColor Yellow
        foreach ($issue in $mediumIssues) {
            Write-Host "   * $($issue.Profile) - $($issue.Issues)" -ForegroundColor Yellow
        }
    }
}
else {
    Write-Host "`nSUCCESS: No critical security issues detected in Wi-Fi profiles." -ForegroundColor Green
}

Write-Host "`nCIS BENCHMARK COMPLIANCE RECOMMENDATIONS:" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Green
Write-Host "1. DELETE UNUSED PROFILES" -ForegroundColor White
Write-Host "   Command: netsh wlan delete profile name='<profile_name>'" -ForegroundColor Gray
Write-Host "   Rationale: Reduces automatic connection attack surface" -ForegroundColor Gray

Write-Host "`n2. ENFORCE STRONG ENCRYPTION" -ForegroundColor White
Write-Host "   * Require WPA3 (preferred) or WPA2 with AES encryption" -ForegroundColor Gray
Write-Host "   * Prohibit WEP, Open, and TKIP configurations" -ForegroundColor Gray

Write-Host "`n3. DISABLE AUTO-CONNECT FOR UNTRUSTED NETWORKS" -ForegroundColor White
Write-Host "   * Only enable auto-connect for verified corporate/home networks" -ForegroundColor Gray
Write-Host "   * Manual connection required for public/guest networks" -ForegroundColor Gray

Write-Host "`n4. WIRELESS ADAPTER MANAGEMENT" -ForegroundColor White
Write-Host "   * Disable Wi-Fi when not required (use wired connections)" -ForegroundColor Gray
Write-Host "   * Implement Group Policy to control wireless settings" -ForegroundColor Gray

Write-Host "`n5. REGULAR AUDIT SCHEDULE" -ForegroundColor White
Write-Host "   * Monthly Wi-Fi profile audits" -ForegroundColor Gray
Write-Host "   * Log and monitor wireless connection attempts" -ForegroundColor Gray

Write-Host "`n6. ENTERPRISE SECURITY CONTROLS" -ForegroundColor White
Write-Host "   * Implement 802.1X authentication where possible" -ForegroundColor Gray
Write-Host "   * Use certificate-based authentication for corporate networks" -ForegroundColor Gray

# Export results if requested
if ($ExportCSV -and $results.Count -gt 0) {
    try {
        $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Host "`nResults exported to: $OutputPath" -ForegroundColor Green
    }
    catch {
        Write-Host "`nERROR: Failed to export results: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nWi-Fi Security Audit Complete" -ForegroundColor Cyan
Write-Host "Run with -ExportCSV to save detailed results" -ForegroundColor Gray
Write-Host ("=" * 80) -ForegroundColor Cyan