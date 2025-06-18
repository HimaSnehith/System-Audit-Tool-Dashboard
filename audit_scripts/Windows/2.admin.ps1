Write-Output "Windows Administrative Privileges Audit"
Write-Output "==========================================="

try {
    # List users in Administrators group
    $adminGroup = [ADSI]"WinNT://./Administrators,group"
    $members = @($adminGroup.psbase.Invoke("Members"))
    
    if ($members.Count -eq 0) {
        Write-Output "No users found in Administrators group. (OK)"
    } else {
        Write-Output "Users with Admin Privileges:"
        foreach ($member in $members) {
            $memberName = $member.GetType().InvokeMember("Name", 'GetProperty', $null, $member, $null)
            Write-Output "- $memberName"
        }
    }
} catch {
    Write-Output "⚠️ Error fetching Administrator group members: $_"
}

Write-Output "`nRecommendations:"
Write-Output "=================="
Write-Output "1. Ensure only authorized personnel have administrative access."
Write-Output "2. Regularly review and audit admin group memberships."
