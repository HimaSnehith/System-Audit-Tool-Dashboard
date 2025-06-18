#!/bin/bash

# This script performs an audit of local user accounts and system-wide password policies.
# It assumes it is run with sufficient privileges (e.g., as root or via sudo from an already elevated process like your Flask app).

echo -e "\n[Linux User Account & Password Policy Audit]"
echo "==========================================="

# --- Check for necessary commands ---
if ! command -v grep &> /dev/null; then echo "--- 'grep' command not found. Exiting. ---"; exit 1; fi
if ! command -v awk &> /dev/null; then echo "--- 'awk' command not found. Exiting. ---"; exit 1; fi
if ! command -v chage &> /dev/null; then echo "--- 'chage' command not found. Cannot retrieve password expiry information. Please ensure 'shadow' package is installed. ---"; exit 1; fi
if ! command -v passwd &> /dev/null; then echo "--- 'passwd' command not found. Cannot check account lock status. ---"; exit 1; fi
if ! command -v getent &> /dev/null; then echo "--- 'getent' command not found. Exiting. ---"; exit 1; fi # Used for optional checks

# --- Section 1: System Information (from original script) ---
echo -e "\n[System Information]"
echo "--------------------"
os_name=$(cat /etc/os-release 2>/dev/null | grep -E '^PRETTY_NAME=' | cut -d '=' -f2 | tr -d '"' | xargs)
os_version=$(uname -r)

echo "Operating System: ${os_name:-N/A}"
echo "Kernel Version  : ${os_version:-N/A}"


# --- Section 2: System-Wide Password Policy Settings (from /etc/login.defs) ---
echo -e "\n[Audit Result: System-Wide Password Policy (login.defs)]"
echo "--------------------------------------------------------"

# Ensure /etc/login.defs exists
if [[ -f "/etc/login.defs" ]]; then
    MIN_LENGTH=$(grep -E '^\s*PASS_MIN_LEN' /etc/login.defs | awk '{print $2}' | xargs)
    MAX_DAYS=$(grep -E '^\s*PASS_MAX_DAYS' /etc/login.defs | awk '{print $2}' | xargs)
    MIN_DAYS=$(grep -E '^\s*PASS_MIN_DAYS' /etc/login.defs | awk '{print $2}' | xargs)
    WARN_DAYS=$(grep -E '^\s*PASS_WARN_AGE' /etc/login.defs | awk '{print $2}' | xargs)

    echo "  Minimum Password Length (PASS_MIN_LEN): ${MIN_LENGTH:-Not Set}"
    if [[ -n "$MIN_LENGTH" && "$MIN_LENGTH" -ge 14 ]]; then # CIS recommends >=14
        echo "    Audit Status: [OK] - Meets CIS recommendation."
    else
        echo "    Audit Status: [WARNING] - Less than 14 characters. Recommend increasing."
    fi

    echo "  Minimum Password Age (PASS_MIN_DAYS)  : ${MIN_DAYS:-Not Set} days"
    if [[ -n "$MIN_DAYS" && "$MIN_DAYS" -ge 7 ]]; then # CIS recommends >=7
        echo "    Audit Status: [OK] - Meets CIS recommendation (prevents immediate re-use)."
    else
        echo "    Audit Status: [WARNING] - Less than 7 days. Recommend increasing."
    fi

    echo "  Maximum Password Age (PASS_MAX_DAYS)  : ${MAX_DAYS:-Not Set} days"
    if [[ -n "$MAX_DAYS" && "$MAX_DAYS" -le 90 && "$MAX_DAYS" -ge 1 ]]; then # CIS recommends <=90 and >0
        echo "    Audit Status: [OK] - Meets CIS recommendation (ensures regular changes)."
    else
        echo "    Audit Status: [WARNING] - Exceeds 90 days or not set. Recommend 90 days."
    fi

    echo "  Password Warning Age (PASS_WARN_AGE)  : ${WARN_DAYS:-Not Set} days"
    if [[ -n "$WARN_DAYS" && "$WARN_DAYS" -ge 7 ]]; then # CIS recommends >=7
        echo "    Audit Status: [OK] - Users warned sufficiently in advance."
    else
        echo "    Audit Status: [WARNING] - Less than 7 days. Recommend increasing warning period."
    fi
else
    echo "  '/etc/login.defs' not found. Cannot determine system-wide password policy defaults."
    echo "    Audit Status: [INFO] - Manual verification recommended."
fi

# --- Section 3: Password Complexity Policy (from PAM) ---
echo -e "\n[Audit Result: Password Complexity Policy (PAM)]"
echo "----------------------------------------------"

PAM_PWQUALITY_CONFIG=$(grep -RE "pam_pwquality.so|pam_cracklib.so" /etc/pam.d/common-password /etc/pam.d/system-auth 2>/dev/null | grep "required" | head -n 1)

if [[ -n "$PAM_PWQUALITY_CONFIG" ]]; then
    echo "  PAM password complexity module found in:"
    echo "    $(echo "$PAM_PWQUALITY_CONFIG" | awk -F':' '{print $1}')" # Print file path

    # Extract common pwquality options
    LOWER_CASE_MIN=$(echo "$PAM_PWQUALITY_CONFIG" | grep -oP 'lcredit=\K-\d+' | tr -d '-' | xargs)
    UPPER_CASE_MIN=$(echo "$PAM_PWQUALITY_CONFIG" | grep -oP 'ucredit=\K-\d+' | tr -d '-' | xargs)
    DIGIT_MIN=$(echo "$PAM_PWQUALITY_CONFIG" | grep -oP 'dcredit=\K-\d+' | tr -d '-' | xargs)
    SPECIAL_MIN=$(echo "$PAM_PWQUALITY_CONFIG" | grep -oP 'ocredit=\K-\d+' | tr -d '-' | xargs)
    MIN_LEN_PAM=$(echo "$PAM_PWQUALITY_CONFIG" | grep -oP 'minlen=\K\d+' | xargs)
    RETRY_TIMES=$(echo "$PAM_PWQUALITY_CONFIG" | grep -oP 'retry=\K\d+' | xargs)
    REMEMBER_COUNT=$(grep -E '^\s*password\s+sufficient\s+pam_unix.so' /etc/pam.d/common-password /etc/pam.d/system-auth 2>/dev/null | grep -oP 'remember=\K\d+' | xargs)

    echo "  Minimum Lowercase (lcredit)  : ${LOWER_CASE_MIN:-Not Set}"
    if [[ -n "$LOWER_CASE_MIN" && "$LOWER_CASE_MIN" -ge 1 ]]; then
        echo "    Audit Status: [OK]"
    else
        echo "    Audit Status: [WARNING] - Recommend at least 1 lowercase character."
    fi

    echo "  Minimum Uppercase (ucredit)  : ${UPPER_CASE_MIN:-Not Set}"
    if [[ -n "$UPPER_CASE_MIN" && "$UPPER_CASE_MIN" -ge 1 ]]; then
        echo "    Audit Status: [OK]"
    else
        echo "    Audit Status: [WARNING] - Recommend at least 1 uppercase character."
    fi

    echo "  Minimum Digits (dcredit)     : ${DIGIT_MIN:-Not Set}"
    if [[ -n "$DIGIT_MIN" && "$DIGIT_MIN" -ge 1 ]]; then
        echo "    Audit Status: [OK]"
    else
        echo "    Audit Status: [WARNING] - Recommend at least 1 digit."
    fi

    echo "  Minimum Special Chars (ocredit): ${SPECIAL_MIN:-Not Set}"
    if [[ -n "$SPECIAL_MIN" && "$SPECIAL_MIN" -ge 1 ]]; then
        echo "    Audit Status: [OK]"
    else
        echo "    Audit Status: [WARNING] - Recommend at least 1 special character."
    fi

    echo "  Minimum Length (minlen)      : ${MIN_LEN_PAM:-Not Set}"
    if [[ -n "$MIN_LEN_PAM" && "$MIN_LEN_PAM" -ge 14 ]]; then
        echo "    Audit Status: [OK] - Meets CIS recommendation."
    else
        echo "    Audit Status: [WARNING] - Less than 14. Recommend at least 14."
    fi

    echo "  Password History (remember)  : ${REMEMBER_COUNT:-Not Set} passwords"
    if [[ -n "$REMEMBER_COUNT" && "$REMEMBER_COUNT" -ge 5 ]]; then # CIS recommends >=5
        echo "    Audit Status: [OK] - Meets CIS recommendation."
    else
        echo "    Audit Status: [WARNING] - Less than 5 or not set. Recommend 5."
    fi

    echo "  Password Retry Times (retry) : ${RETRY_TIMES:-Not Set} attempts"
    if [[ -n "$RETRY_TIMES" && "$RETRY_TIMES" -le 3 ]]; then # PAM attempts, not lockout attempts
        echo "    Audit Status: [OK]"
    else
        echo "    Audit Status: [INFO] - Check if too many password retries are allowed during set."
    fi
else
    echo "  PAM password quality/cracklib module not explicitly configured in common-password/system-auth."
    echo "    Audit Status: [WARNING] - Password complexity may not be enforced by PAM."
fi

# --- Section 4: Individual User Account Audits ---
echo -e "\n[Audit Result: Individual Local User Accounts]"
echo "---------------------------------------------"

# List all users from /etc/passwd
# Fields from /etc/passwd: username:password:UID:GID:comment:home_directory:shell
getent passwd | while IFS=: read -r username _ uid gid full_name home_dir shell; do
    # Ignore system accounts (UID < 1000) and common service/special accounts that don't log in
    if [[ "$uid" -ge 1000 && "$username" != "nobody" ]]; then # Filter typical user accounts
        echo "User: $username (UID: $uid)"
        echo "--------------------------------------"
        echo "  Full Name (Comment): ${full_name:-N/A}"
        echo "  Primary GID        : $gid"
        echo "  Home Directory     : $home_dir"
        echo "  Login Shell        : $shell"

        # Check account status (locked, active)
        ACCOUNT_STATUS=$(passwd -S "$username" 2>/dev/null | awk '{print $2}')
        case "$ACCOUNT_STATUS" in
            "L") # Locked (passwd -L)
                echo "  Account Status     : Locked"
                echo "    Audit Status     : [OK] - Account is explicitly locked."
                ;;
            "P") # Password in place
                echo "  Account Status     : Active (Password Set)"
                echo "    Audit Status     : [OK]"
                ;;
            "NP") # No password
                echo "  Account Status     : Active (No Password Set)"
                echo "    Audit Status     : [WARNING] - Account has no password. High risk!"
                ;;
            *)
                echo "  Account Status     : Unknown ($ACCOUNT_STATUS)"
                echo "    Audit Status     : [INFO] - Could not determine exact status."
                ;;
        esac

        # Check password expiry for individual users
        if command -v chage &> /dev/null; then
            password_expiry_date=$(sudo chage -l "$username" | grep "Password expires" | awk -F': ' '{print $2}')
            password_last_changed=$(sudo chage -l "$username" | grep "Last password change" | awk -F': ' '{print $2}')

            echo "  Password Expires   : ${password_expiry_date:-N/A}"
            if [[ "$password_expiry_date" == "never" ]]; then
                echo "    Audit Status     : [WARNING] - Password never expires. Enforce password aging."
            elif [[ -z "$password_expiry_date" || "$password_expiry_date" == "never" ]]; then # Handle cases where chage output isn't 'never' but still no expiry
                 echo "    Audit Status     : [WARNING] - Password expiry not set or 'never'. Enforce password aging."
            else
                echo "    Audit Status     : [OK]"
            fi

            echo "  Password Last Changed: ${password_last_changed:-N/A}"
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
                        if [[ "$days_ago" -gt 90 ]]; then # Example threshold: 90 days from CIS
                            echo "    Audit Status     : [WARNING] - Password changed over 90 days ago. Review policy."
                        else
                            echo "    Audit Status     : [OK]"
                        fi
                    fi
                fi
            fi
        else
            echo "  Password Policy    : UNKNOWN ('chage' command not found for detailed expiry)"
            echo "    Audit Status     : [INFO] - Could not verify individual password policy."
        fi

        echo "" # Blank line for readability between users
    fi
done

echo -e "\nAudit Completed: User Accounts & Password Policies."

---

### Recommendations (CIS Benchmark Aligned)

1.  Enforce Strong Password Policies System-Wide:
    * Minimum Length: Configure `PASS_MIN_LEN` in `/etc/login.defs` to at least 14 characters.
    * Complexity: Ensure PAM modules like `pam_pwquality.so` (or `pam_cracklib.so`) are correctly configured in `/etc/pam.d/common-password` (or `system-auth`) to enforce complexity (e.g., mix of uppercase, lowercase, digits, special characters).
    * Password History: Set `remember=5` or more in PAM configuration to prevent users from reusing recent passwords. (CIS Control 5.3 - Manage Account Passwords).
2.  Set Password Expiration Policies:
    * Configure `PASS_MAX_DAYS` in `/etc/login.defs` to 90 days or less.
    * Ensure `PASS_MIN_DAYS` is set to at least 7 days to prevent users from rapidly changing passwords to bypass history requirements.
    * Regularly verify that individual user accounts adhere to these expiry policies (e.g., using `chage -l`). (CIS Control 5.3).
3.  Disable Inactive/Dormant Accounts: Regularly audit and disable or remove user accounts that show no login activity for an extended period (e.g., 30-90 days). These accounts are common targets for attackers. (CIS Control 4.1 - Secure Configuration, 5.1 - Inventory of Authorized Accounts).
4.  Manage Account Lock Status: Actively lock user accounts using `passwd -L <username>` when appropriate (e.g., for terminated employees, compromised accounts) and ensure accounts without passwords (`NP` status) are not allowed.
5.  Review Guest Accounts: Ensure that all guest or temporary accounts are disabled by default and only enabled when absolutely necessary, with strict limitations. (CIS Control 5.1).
6.  Monitor Password Changes: Configure logging to capture password changes and failed login attempts. Regularly review these logs for suspicious activity. (CIS Control 6.4 - Audit Log Review).

---