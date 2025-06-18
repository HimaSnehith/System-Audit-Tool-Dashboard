#!/bin/bash

echo -e "\n[Linux User Account Security Audit]"
echo "==================================="

# --- Check for necessary commands ---
if ! command -v lastlog &> /dev/null; then
    echo "--- 'lastlog' command not found. Cannot retrieve last login times. ---"
    echo "--- Please ensure 'util-linux' or similar package is installed. ---"
fi
if ! command -v chage &> /dev/null; then
    echo "--- 'chage' command not found. Cannot retrieve password expiry information. ---"
    echo "--- Please ensure 'shadow' package is installed. ---"
fi
if ! command -v groups &> /dev/null; then
    echo "--- 'groups' command not found. Cannot check user group memberships. ---"
    echo "--- Please ensure 'coreutils' or similar package is installed. ---"
fi

echo -e "\n[Audit Result: Local User Accounts]"
echo "-----------------------------------"

# Loop through all local user accounts
# Fields from /etc/passwd: username:password:UID:GID:comment:home_directory:shell
while IFS=: read -r username _ uid gid comment home_dir shell; do
    # Ignore system accounts (UID < 1000) and common service accounts
    if [[ "$uid" -ge 1000 && "$shell" != "/usr/sbin/nologin" && "$shell" != "/bin/false" && "$username" != "nobody" ]]; then
        echo "User: $username (UID: $uid)"
        echo "--------------------------------------"
        echo "  Full Name/Comment  : ${comment:-N/A}"
        echo "  Primary GID        : $gid"
        echo "  Home Directory     : $home_dir"
        echo "  Login Shell        : $shell"

        # Check if account is designed for interactive login (not disabled shell)
        if [[ "$shell" == "/usr/sbin/nologin" || "$shell" == "/bin/false" ]]; then
            echo "  Account Status     : DISABLED (Login Shell: $shell)"
            echo "    Audit Status     : [OK] - Account is appropriately restricted."
        else
            echo "  Account Status     : ENABLED (Interactive Login)"
            echo "    Audit Status     : [INFO] - Account is active."
        fi

        # Check if user is an administrator (member of sudo or wheel group)
        if command -v groups &> /dev/null && groups "$username" &>/dev/null; then
            if groups "$username" | grep -qE "\b(sudo|wheel)\b"; then
                echo "  Administrator      : YES (Member of sudo/wheel group)"
                echo "    Audit Status     : [WARNING] - Privileged account detected. Ensure necessity."
            else
                echo "  Administrator      : NO"
                echo "    Audit Status     : [OK] - Non-privileged account."
            fi
        else
            echo "  Administrator      : UNKNOWN (Failed to check groups)"
            echo "    Audit Status     : [INFO] - Could not verify admin status."
        fi

        # Check for guest-like accounts (simple check based on username)
        if [[ "$username" == "guest" || "$username" =~ ^anon ]]; then
            echo "  Guest/Anonymous Account: YES"
            echo "    Audit Status     : [WARNING] - Guest account detected. Review necessity and permissions."
        else
            echo "  Guest/Anonymous Account: NO"
            echo "    Audit Status     : [OK]"
        fi

        # Get Last Logon Time
        if command -v lastlog &> /dev/null; then
            last_logon_info=$(sudo lastlog -u "$username" | awk 'NR==2 {print $4, $5, $6, $7, $8}') # Include all fields for full date
            if [[ -z "$last_logon_info" || "$last_logon_info" =~ "Never" ]]; then
                echo "  Last Logon         : Never Logged In"
                echo "    Audit Status     : [WARNING] - Possible dormant account. Review if still needed."
            else
                echo "  Last Logon         : $last_logon_info"
                echo "    Audit Status     : [OK]"
            fi
        else
            echo "  Last Logon         : UNKNOWN ('lastlog' command not found)"
            echo "    Audit Status     : [INFO] - Could not verify last logon."
        fi

        # Check password expiry and last changed
        if command -v chage &> /dev/null; then
            password_expiry=$(sudo chage -l "$username" | grep "Password expires" | awk -F": " '{print $2}')
            password_last_changed=$(sudo chage -l "$username" | grep "Last password change" | awk -F": " '{print $2}')

            echo "  Password Expires   : $password_expiry"
            if [[ "$password_expiry" == "never" ]]; then
                echo "    Audit Status     : [WARNING] - Password never expires. Enforce password aging."
            else
                echo "    Audit Status     : [OK]"
            fi
            echo "  Password Last Changed: $password_last_changed"
            if [[ -z "$password_last_changed" || "$password_last_changed" == "never" ]]; then
                echo "    Audit Status     : [WARNING] - Password not changed or unknown. Enforce initial password change."
            else
                # Calculate days since last password change (requires GNU date)
                if command -v date &> /dev/null && date --version 2>&1 | grep -q "GNU coreutils"; then
                    current_date_sec=$(date +%s)
                    last_changed_date_sec=$(date -d "$password_last_changed" +%s 2>/dev/null)
                    if [[ -n "$last_changed_date_sec" ]]; then
                        days_ago=$(( (current_date_sec - last_changed_date_sec) / 86400 ))
                        echo "    (Changed $days_ago days ago)"
                        if [[ "$days_ago" -gt 90 ]]; then # Example threshold: 90 days
                            echo "    Audit Status     : [WARNING] - Password changed over 90 days ago. Review policy."
                        else
                            echo "    Audit Status     : [OK]"
                        fi
                    fi
                fi
            fi
        else
            echo "  Password Policy    : UNKNOWN ('chage' command not found)"
            echo "    Audit Status     : [INFO] - Could not verify password policy."
        fi
        echo "" # Blank line for readability between users
    fi
done < /etc/passwd

echo -e "\nAudit Completed: Local User Accounts."

---

## Recommendations (CIS Benchmark Aligned)

1.  Disable Unused Accounts: Regularly review and disable or remove user accounts that are no longer needed (e.g., for terminated employees, expired projects). Dormant accounts are a prime target for attackers. (CIS Control 4.1 - Establish and Maintain a Secure Configuration Process, 5.1 - Inventory of Authorized Accounts).
2.  Enforce Password Complexity and Aging: Implement and enforce a strong password policy that requires complexity, minimum length, and regular password changes (e.g., every 60-90 days). Avoid "password never expires" settings. (CIS Control 5.2 - Manage User Accounts, 5.3 - Manage Account Passwords).
3.  Minimize Administrator Privileges: Adhere to the principle of least privilege. Grant administrative access (e.g., `sudo` or `wheel` group membership) only to users who absolutely require it for their job functions, and only for the duration needed. (CIS Control 5.4 - Manage Privileged Access).
4.  Review Last Logon Times: Audit `lastlog` entries to identify accounts that haven't logged in for an extended period. These could be dormant accounts or indicators of compromise if they suddenly become active after a long dormancy. (CIS Control 5.6 - Establish and Maintain an Account Monitoring Capability).
5.  Restrict Guest/Anonymous Accounts: If present, ensure guest or anonymous accounts are disabled or severely restricted in their capabilities. These accounts pose a significant security risk if not properly managed.
6.  Secure Shell Configuration: For non-interactive service accounts, ensure their shell is set to `/usr/sbin/nologin`, `/bin/false`, or a similar shell that prevents interactive logins.
7.  Monitor Account Creation/Modification: Implement logging and alerting for new user account creation, privilege escalations, or account modifications. (CIS Control 6.4 - Audit Log Review, 6.5 - Central Log Management).