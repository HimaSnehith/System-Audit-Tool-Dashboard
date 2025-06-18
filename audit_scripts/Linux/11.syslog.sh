#!/bin/bash

echo -e "\n[🔍 System Log Analysis]"
echo "========================="

# Define time window for analysis (e.g., last 7 days)
DAYS_TO_ANALYZE=7
TIME_FILTER_JOURNALCTL="--since=\"${DAYS_TO_ANALYZE} days ago\""
# For grep, e.g., "Jun 14". This is less precise for traditional logs, but best effort.
TIME_FILTER_GREP=$(date -d "${DAYS_TO_ANALYZE} days ago" +"%b %_d")

# Determine log analysis method (journalctl vs. traditional log files)
LOG_TOOL=""
if command -v journalctl &> /dev/null; then
    LOG_TOOL="journalctl"
    echo "Using 'journalctl' for log analysis (systemd-based system)."
elif [[ -f "/var/log/auth.log" || -f "/var/log/secure" || -f "/var/log/syslog" ]]; then
    LOG_TOOL="grep_files"
    echo "Using 'grep' on traditional log files for analysis."
    # Define common log file locations (adjust if necessary for your distro)
    # Ubuntu/Debian: /var/log/auth.log, /var/log/syslog
    # RHEL/CentOS/Fedora: /var/log/secure, /var/log/messages
    COMMON_LOG_FILES=("/var/log/auth.log" "/var/log/syslog" "/var/log/secure" "/var/log/messages")
    LOG_FILES_TO_SCAN=()
    for log_file in "${COMMON_LOG_FILES[@]}"; do
        if [[ -f "$log_file" ]]; then
            LOG_FILES_TO_SCAN+=("$log_file")
        fi
    done
    if [[ ${#LOG_FILES_TO_SCAN[@]} -eq 0 ]]; then
        echo "No common log files found to scan. Please check '/var/log/' directory."
        LOG_TOOL="" # Disable analysis if no files found
    fi
else
    echo "No suitable log analysis tool (journalctl or common log files) found."
    echo "Skipping detailed log analysis."
fi

# Function to extract logs based on tool and pattern
get_logs() {
    local pattern="$1"
    if [[ "$LOG_TOOL" == "journalctl" ]]; then
        journalctl --no-pager "$TIME_FILTER_JOURNALCTL" --priority=info --output=short-iso --grep="$pattern"
    elif [[ "$LOG_TOOL" == "grep_files" ]]; then
        # Use 'awk' or 'gawk' preference if available
        AWK_CMD="awk"
        if command -v gawk &> /dev/null; then
            AWK_CMD="gawk"
        fi

        # The AWK script is now a single string to avoid syntax issues with shell parsing
        AWK_SCRIPT="BEGIN { \
            split(start_date_str, sd_arr, \" \"); \
            start_month_str = sd_arr[1]; \
            start_day = sd_arr[2] + 0; \
            months[\"Jan\"]=1; months[\"Feb\"]=2; months[\"Mar\"]=3; months[\"Apr\"]=4; \
            months[\"May\"]=5; months[\"Jun\"]=6; months[\"Jul\"]=7; months[\"Aug\"]=8; \
            months[\"Sep\"]=9; months[\"Oct\"]=10; months[\"Nov\"]=11; months[\"Dec\"]=12; \
            start_month_num = months[start_month_str]; \
        } \
        { \
            log_month_str = \$1; \
            log_day = \$2 + 0; \
            log_month_num = months[log_month_str]; \
            if (log_month_num > start_month_num || (log_month_num == start_month_num && log_day >= start_day)) { \
                print \$0; \
            } \
        }"

        for log_file in "${LOG_FILES_TO_SCAN[@]}"; do
            # The awk script is passed directly. Note the use of backticks or command substitution here
            # for piping the grep output into awk.
            grep -E "$pattern" "$log_file" | "$AWK_CMD" -v start_date_str="$TIME_FILTER_GREP" "$AWK_SCRIPT"
        done
    fi
}

if [[ -n "$LOG_TOOL" ]]; then
    echo "Analyzing logs from the last $DAYS_TO_ANALYZE days."

    # --- Section: Failed Login Attempts ---
    echo -e "\n[Audit Result: Failed Login Attempts]"
    echo "-------------------------------------"
    FAILED_LOGIN_PATTERNS="Failed password|authentication failure|Invalid user"
    failed_logins=$(get_logs "$FAILED_LOGIN_PATTERNS")

    if [[ -z "$failed_logins" ]]; then
        echo "No failed login attempts detected in the last $DAYS_TO_ANALYZE days."
    else
        echo "Top 10 Failed Login Attempts (Count by User/IP):"
        echo "$failed_logins" | grep -oP '(for|from) \K[^ ]+|Invalid user \K[^ ]+ from \K[^ ]+' | sort | uniq -c | sort -nr | head -n 10
        echo -e "\nRecent Failed Login Attempts (Last 5 detailed lines):"
        echo "$failed_logins" | tail -n 5
    fi

    # --- Section: Successful Logins ---
    echo -e "\n[Audit Result: Successful Logins]"
    echo "-------------------------------"
    SUCCESS_LOGIN_PATTERNS="Accepted password|session opened for user|logged in|userauth_pubkey"
    successful_logins=$(get_logs "$SUCCESS_LOGIN_PATTERNS")

    if [[ -z "$successful_logins" ]]; then
        echo "No successful login events detected in the last $DAYS_TO_ANALYZE days."
    else
        echo "Top 10 Successful Logins (Count by User/Source):"
        echo "$successful_logins" | grep -oP '(for user|from) \K[^ ]+' | sort | uniq -c | sort -nr | head -n 10
        echo -e "\nRecent Successful Logins (Last 5 detailed lines):"
        echo "$successful_logins" | tail -n 5
    fi

    # --- Section: Privilege Escalations (sudo/su) ---
    echo -e "\n[Audit Result: Privilege Escalations (sudo/su)]"
    echo "-----------------------------------------------"
    SUDO_PATTERNS="(sudo:|su:)"
    priv_escalations=$(get_logs "$SUDO_PATTERNS")

    if [[ -z "$priv_escalations" ]]; then
        echo "No 'sudo' or 'su' attempts detected in the last $DAYS_TO_ANALYZE days."
    else
        echo "Top 10 Privilege Escalation Attempts (Count by User/Command):"
        echo "$priv_escalations" | grep -oP '(USER=|COMMAND=|TTY=|PWD=|CWD=|session opened for user) \K[^ ]+' | sort | uniq -c | sort -nr | head -n 10
        echo -e "\nRecent Privilege Escalation Attempts (Last 5 detailed lines):"
        echo "$priv_escalations" | tail -n 5
    fi

    # --- Section: User/Group Management Changes ---
    echo -e "\n[Audit Result: User/Group Management Changes]"
    echo "-------------------------------------------"
    USER_GROUP_PATTERNS="(useradd|userdel|groupadd|groupdel|usermod|groupmod|new group|new user)"
    user_group_changes=$(get_logs "$USER_GROUP_PATTERNS")

    if [[ -z "$user_group_changes" ]]; then
        echo "No user or group management changes detected in the last $DAYS_TO_ANALYZE days."
    else
        echo "Top 10 User/Group Changes:"
        echo "$user_group_changes" | grep -oP '(useradd|userdel|groupadd|groupdel|usermod|groupmod): \K.*' | sort | uniq -c | sort -nr | head -n 10
        echo -e "\nRecent User/Group Changes (Last 5 detailed lines):"
        echo "$user_group_changes" | tail -n 5
    fi

    # --- Section: System Reboots/Shutdowns ---
    echo -e "\n[Audit Result: System Reboots/Shutdowns]"
    echo "----------------------------------------"
    REBOOT_PATTERNS="(reboot|shutdown|systemd-logind.*powering off|systemd.*reboot)"
    reboot_events=$(get_logs "$REBOOT_PATTERNS")

    if [[ -z "$reboot_events" ]]; then
        echo "No system reboots or shutdowns detected in the last $DAYS_TO_ANALYZE days."
    else
        echo "Top 10 System Reboot/Shutdown Events:"
        echo "$reboot_events" | grep -oP '(reboot|shutdown|systemd-logind.*powering off|systemd.*reboot)' | sort | uniq -c | sort -nr | head -n 10
        echo -e "\nRecent System Reboots/Shutdowns (Last 5 detailed lines):"
        echo "$reboot_events" | tail -n 5
    fi

else
    echo "Log analysis could not be performed due to missing tools or log files."
    echo "Ensure 'journalctl' is available or common log files in '/var/log/' exist."
fi

echo -e "\nLog Scan Completed."

echo -e "\nRecommendations (CIS Benchmark Aligned):"
echo "========================================="
echo "1. Centralized Log Management: Implement a centralized log management solution (e.g., rsyslog to a SIEM/ELK stack) to aggregate, store, and analyze logs from all systems. This provides a single pane of glass for security monitoring. (CIS Control 6.1, 6.2)."
echo "2. Monitor Failed Login Attempts: Regularly review logs for repeated failed login attempts, especially from unfamiliar IP addresses or for privileged accounts (e.g., root). High numbers can indicate brute-force attacks. (CIS Control 6.4, 6.5)."
echo "3. Audit Privilege Escalation: Closely monitor 'sudo' and 'su' attempts. Investigate any unauthorized or suspicious privilege escalations, paying attention to the user, command, and context. (CIS Control 6.4, 6.5)."
echo "4. Track User/Group Changes: Audit all additions, deletions, or modifications to user accounts and groups. Unauthorized changes can indicate account compromise or misconfiguration. (CIS Control 6.4, 6.5)."
echo "5. Review System Uptime/Reboots: Monitor unexpected system reboots or shutdowns, as these could indicate system instability, power issues, or malicious activity (e.g., kernel exploits leading to crashes or an attacker attempting to cover tracks). (CIS Control 6.4)."
echo "6. Retain Logs Appropriately: Ensure logs are retained for a sufficient period (e.g., 90 days for operational analysis, 1 year for audit and forensics) as per organizational policy and compliance requirements. (CIS Control 6.3)."
echo "7. Automated Alerts: Configure automated alerts for critical log events (e.g., multiple failed logins from the same source, root login, firewall changes, unauthorized access attempts). (CIS Control 6.5)."
echo "8. Implement File Integrity Monitoring (FIM): Use FIM tools (e.g., AIDE, Tripwire) to monitor critical system files and directories for unauthorized changes. While not directly a log analysis point, FIM generates logs that should be monitored. (CIS Control 6.6)."