#!/bin/bash

# This script assumes it is run with sufficient privileges (e.g., as root or via sudo from an already elevated process like your Flask app).

echo -e "\n[Linux Account Lockout & Login Policy Audit]"
echo "=========================================="

# --- Check for necessary commands ---
if ! command -v grep &> /dev/null; then echo "--- 'grep' command not found. Exiting. ---"; exit 1; fi
if ! command -v awk &> /dev/null; then echo "--- 'awk' command not found. Exiting. ---"; exit 1; fi
if ! command -v getent &> /dev/null; then echo "--- 'getent' command not found. Exiting. ---"; exit 1; fi

echo -e "\n[Audit Result: Account Lockout Policy]"
echo "--------------------------------------"

LOCKOUT_THRESHOLD="Not Configured"
LOCKOUT_DURATION="Not Configured"

# Prioritize pam_faillock configuration
if command -v faillock &> /dev/null; then
    # Attempt to read from faillock.conf first
    if [[ -f "/etc/security/faillock.conf" ]]; then
        LOCKOUT_THRESHOLD=$(grep -E '^\s*deny\s*=' /etc/security/faillock.conf 2>/dev/null | awk -F'=' '{print $2}' | xargs)
        LOCKOUT_DURATION=$(grep -E '^\s*unlock_time\s*=' /etc/security/faillock.conf 2>/dev/null | awk -F'=' '{print $2}' | xargs)
    fi

    # If not found in faillock.conf, check pam.d configuration directly for pam_faillock
    if [[ -z "$LOCKOUT_THRESHOLD" ]] || [[ -z "$LOCKOUT_DURATION" ]]; then
        PAM_FAILLOCK_CONFIG=$(grep -RE "pam_faillock.so" /etc/pam.d/common-auth /etc/pam.d/system-auth /etc/pam.d/login /etc/pam.d/sshd 2>/dev/null | head -n 1)
        if [[ -n "$PAM_FAILLOCK_CONFIG" ]]; then
            # Extract deny=N
            DENY_MATCH=$(echo "$PAM_FAILLOCK_CONFIG" | grep -oP 'deny=\K\d+')
            if [[ -n "$DENY_MATCH" ]]; then
                LOCKOUT_THRESHOLD="$DENY_MATCH"
            fi
            # Extract unlock_time=N
            UNLOCK_TIME_MATCH=$(echo "$PAM_FAILLOCK_CONFIG" | grep -oP 'unlock_time=\K\d+')
            if [[ -n "$UNLOCK_TIME_MATCH" ]]; then
                LOCKOUT_DURATION="$UNLOCK_TIME_MATCH"
            fi
        fi
    fi
else
    echo "--- 'faillock' command not found. Checking pam_tally2 if available. ---"
    # Check pam_tally2 if faillock is not the primary tool
    PAM_TALLY2_CONFIG=$(grep -RE "pam_tally2.so" /etc/pam.d/common-auth /etc/pam.d/system-auth /etc/pam.d/login /etc/pam.d/sshd 2>/dev/null | head -n 1)
    if [[ -n "$PAM_TALLY2_CONFIG" ]]; then
        DENY_MATCH=$(echo "$PAM_TALLY2_CONFIG" | grep -oP 'deny=\K\d+')
        if [[ -n "$DENY_MATCH" ]]; then
            LOCKOUT_THRESHOLD="$DENY_MATCH"
        fi
        RESET_MATCH=$(echo "$PAM_TALLY2_CONFIG" | grep -oP 'reset=\K\d+')
        # pam_tally2 does not have a direct unlock_time, 'reset' is often used
        if [[ -n "$RESET_MATCH" ]]; then
            LOCKOUT_DURATION="Reset after $RESET_MATCH seconds (manual reset if not in a set time)"
        fi
    fi
fi

LOCKOUT_THRESHOLD_STATUS="[WARNING]"
if [[ -n "$LOCKOUT_THRESHOLD" && "$LOCKOUT_THRESHOLD" -le 5 ]]; then # CIS recommends <=5
    LOCKOUT_THRESHOLD_STATUS="[OK]"
fi
echo "Lockout Threshold   : ${LOCKOUT_THRESHOLD:-Not Configured} attempts ($LOCKOUT_THRESHOLD_STATUS)"
echo "  Recommendation    : Set to 5 or fewer attempts."

LOCKOUT_DURATION_STATUS="[WARNING]"
if [[ -n "$LOCKOUT_DURATION" && "$LOCKOUT_DURATION" -ge 900 ]]; then # CIS recommends >=900 seconds (15 minutes)
    LOCKOUT_DURATION_STATUS="[OK]"
fi
echo "Lockout Duration    : ${LOCKOUT_DURATION:-Not Configured} seconds ($LOCKOUT_DURATION_STATUS)"
echo "  Recommendation    : Set to 900 seconds (15 minutes) or more."


echo -e "\n[Audit Result: Guest Account Local Login (Graphical)]"
echo "---------------------------------------------------"
GUEST_LOGIN_ENABLED="Not Applicable/Unknown"
GUEST_STATUS_MSG=""

# Check LightDM (common for Ubuntu/Mint)
if [[ -f "/etc/lightdm/lightdm.conf" ]]; then
    if grep -qE '^\s*allow-guest=true' /etc/lightdm/lightdm.conf; then
        GUEST_LOGIN_ENABLED="Yes (WARNING)"
        GUEST_STATUS_MSG="LightDM allows guest sessions. This should generally be disabled for security."
    else
        GUEST_LOGIN_ENABLED="No (OK)"
        GUEST_STATUS_MSG="LightDM guest sessions appear to be disabled."
    fi
# Add checks for other display managers if necessary (e.g., GDM, SDDM)
# For GDM3, check if 'guest-session-enabled' is false via dconf/gsettings or a configuration file.
# e.g., 'grep -r "guest-session-enabled" /etc/gdm3' or 'sudo -u gdm gsettings get org.gnome.login-screen guest-session-enabled'
# This requires more complex logic and user context.
elif command -v gsettings &> /dev/null && sudo -u "$SUDO_USER" gsettings get org.gnome.login-screen disable-user-list &> /dev/null; then # Basic check for GDM presence
    GDM_GUEST_ENABLED=$(sudo -u "$SUDO_USER" gsettings get org.gnome.login-screen guest-session-enabled 2>/dev/null)
    if [[ "$GDM_GUEST_ENABLED" == "true" ]]; then
        GUEST_LOGIN_ENABLED="Yes (WARNING)"
        GUEST_STATUS_MSG="GDM allows guest sessions. This should generally be disabled for security."
    else
        GUEST_LOGIN_ENABLED="No (OK)"
        GUEST_STATUS_MSG="GDM guest sessions appear to be disabled."
    fi
else
    GUEST_STATUS_MSG="No specific graphical guest login configuration detected (e.g., LightDM/GDM)."
fi

echo "Guest Account Local Login: $GUEST_LOGIN_ENABLED"
echo "  Details              : $GUEST_STATUS_MSG"
echo "  Recommendation       : Disable graphical guest login if not explicitly required."


echo -e "\n[Audit Result: Remote Login Access]"
echo "-----------------------------------"

# Check SSH daemon configuration for AllowedUsers/AllowGroups
SSH_CONFIG_FILE="/etc/ssh/sshd_config"
if [[ -f "$SSH_CONFIG_FILE" ]]; then
    SSH_ALLOW_USERS=$(grep -E '^\s*AllowUsers\s+' "$SSH_CONFIG_FILE" | awk '{$1=""; print $0}' | xargs)
    SSH_ALLOW_GROUPS=$(grep -E '^\s*AllowGroups\s+' "$SSH_CONFIG_FILE" | awk '{$1=""; print $0}' | xargs)
    SSH_DENY_USERS=$(grep -E '^\s*DenyUsers\s+' "$SSH_CONFIG_FILE" | awk '{$1=""; print $0}' | xargs)
    SSH_DENY_GROUPS=$(grep -E '^\s*DenyGroups\s+' "$SSH_CONFIG_FILE" | awk '{$1=""; print $0}' | xargs)
    SSH_ROOT_LOGIN=$(grep -E '^\s*PermitRootLogin\s+' "$SSH_CONFIG_FILE" | awk '{print $2}' | xargs)

    echo "SSH Remote Login Configuration ($SSH_CONFIG_FILE):"
    echo "  PermitRootLogin  : ${SSH_ROOT_LOGIN:-Yes (Default if not specified)}"
    if [[ "$SSH_ROOT_LOGIN" == "yes" ]]; then
        echo "    Audit Status   : [WARNING] - Direct root login via SSH is enabled. Recommend 'no' or 'prohibit-password'."
    elif [[ "$SSH_ROOT_LOGIN" == "prohibit-password" ]]; then
        echo "    Audit Status   : [OK] - Root login via SSH is restricted to key-based authentication."
    elif [[ "$SSH_ROOT_LOGIN" == "no" ]]; then
        echo "    Audit Status   : [OK] - Direct root login via SSH is disabled."
    fi

    echo "  Allowed Users    : ${SSH_ALLOW_USERS:-All (if no DenyUsers/Groups)} (configured in sshd_config)"
    echo "  Allowed Groups   : ${SSH_ALLOW_GROUPS:-All (if no DenyUsers/Groups)} (configured in sshd_config)"
    echo "  Denied Users     : ${SSH_DENY_USERS:-None} (configured in sshd_config)"
    echo "  Denied Groups    : ${SSH_DENY_GROUPS:-None} (configured in sshd_config)"

    if [[ -z "$SSH_ALLOW_USERS" ]] && [[ -z "$SSH_ALLOW_GROUPS" ]]; then
        echo "    Audit Status   : [WARNING] - No explicit AllowUsers/AllowGroups. Access controlled by DenyUsers/Groups or defaults. Consider explicit allowance for clarity."
    else
        echo "    Audit Status   : [OK] - Explicit AllowUsers/AllowGroups configured."
    fi
else
    echo "SSH Daemon configuration file ($SSH_CONFIG_FILE) not found. Cannot audit SSH access."
    echo "  Audit Status     : [INFO] - SSH access audit skipped."
fi

# Check for other remote login services (e.g., Telnet, FTP - though deprecated/insecure)
echo -e "\nOther Remote Services (Basic Check):"
echo "  Telnet: $(systemctl is-active telnetd 2>/dev/null || echo "Not installed or inactive")"
echo "  FTP   : $(systemctl is-active vsftpd 2>/dev/null || systemctl is-active proftpd 2>/dev/null || echo "Not installed or inactive")"
echo "  RSH   : $(systemctl is-active rshd 2>/dev/null || echo "Not installed or inactive")"
echo "  Recommendation: Disable insecure remote services (Telnet, RSH, FTP) if active."


echo -e "\nAudit Completed: Account Lockout & Login Policy."

---

### Recommendations (CIS Benchmark Aligned)

1.  Configure Account Lockout Threshold: Set the account lockout threshold to a low number (e.g., 3-5 failed attempts) to mitigate brute-force attacks against user accounts. (CIS Control 5.3 - Manage Account Passwords).
2.  Set Account Lockout Duration: Configure a lockout duration (e.g., 15 minutes or 900 seconds) after the lockout threshold is met. This provides a temporary block, preventing continuous attempts while not permanently denying legitimate users. (CIS Control 5.3).
3.  Disable Guest Accounts: For enhanced security, disable all guest and anonymous login accounts, especially for graphical desktop environments, to prevent unauthorized access. (CIS Control 5.1 - Inventory of Authorized Accounts).
4.  Restrict Remote Login (SSH):
    * Disable Direct Root Login: Configure `PermitRootLogin no` or `PermitRootLogin prohibit-password` in `/etc/ssh/sshd_config` to prevent direct root login via SSH. Always use a regular user account and then `sudo` for administrative tasks. (CIS Control 5.4 - Manage Privileged Access).
    * Limit SSH Access to Specific Users/Groups: Use `AllowUsers` or `AllowGroups` directives in `sshd_config` to explicitly define which users or groups are permitted to log in via SSH. Avoid `DenyUsers` and `DenyGroups` as `Allow*` is more secure by default.
    * Use Key-Based Authentication: Prefer SSH key-based authentication over password authentication for remote logins. Disable `PasswordAuthentication yes` in `sshd_config`. (CIS Control 13.1 - Network Device Authentication).
5.  Disable Insecure Remote Services: Ensure that insecure and deprecated remote login services like Telnet, FTP, and RSH are disabled or uninstalled. Use secure alternatives like SSH and SFTP. (CIS Control 2.1 - Software Inventory, 9.2 - Implement and Manage Network Access Controls).
6.  Monitor Failed Login Attempts: Implement logging and alerting for repeated failed login attempts, which can indicate ongoing attacks. Integrate these logs with a centralized logging solution. (CIS Control 6.4 - Audit Log Review, 6.5 - Central Log Management).