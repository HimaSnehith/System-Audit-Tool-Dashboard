#!/bin/bash

# Ensure script runs as root
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[31mThis script must be run as root!\e[0m"
    exec sudo bash "$0"
    exit 1
fi

# Function to print colored output
function write_color_output {
    case "$2" in
        "OK") color="\e[32m" ;;      # Green
        "Warning") color="\e[33m" ;; # Yellow
        "Error") color="\e[31m" ;;   # Red
        *) color="\e[0m" ;;          # Default (white)
    esac
    echo -e "${color}$1\e[0m"
}

write_color_output "Fetching User Account Details..." "OK"
write_color_output "================================" "OK"

# Get all local users
while IFS=: read -r username _ uid _ home shell; do
    [[ "$uid" -ge 1000 && "$username" != "nobody" ]] || continue  # Ignore system accounts
    write_color_output "\nUser: $username" "OK"
    write_color_output "----------------------" "OK"

    # Account Status (Check if account is locked)
    if passwd -S "$username" 2>/dev/null | grep -q "L"; then
        accStatus="Locked (Warning)"
    else
        accStatus="Active (OK)"
    fi
    write_color_output "Account Status: $accStatus" "$accStatus"

    # Password Expiry Info
    passExpire=$(chage -l "$username" | grep "Password expires" | awk -F": " '{print $2}')
    write_color_output "Password Expires: $passExpire" $( [[ "$passExpire" == "never" ]] && echo "Warning" || echo "OK" )

    # Last Logon
    lastLogon=$(lastlog -u "$username" | awk 'NR==2 {print $4, $5, $6, $7}')
    lastLogon=${lastLogon:-"Never Logged In"}
    write_color_output "Last Logon: $lastLogon" "OK"

    # Check if User is in sudo (admin) group
    if id -nG "$username" | grep -qw "sudo"; then
        isAdmin="Yes (Warning)"
    else
        isAdmin="No (OK)"
    fi
    write_color_output "Administrator: $isAdmin" "$isAdmin"

done < /etc/passwd

write_color_output "\nUser Account Audit Completed!" "OK"
echo -e "\nPress any key to exit..."
read -n 1 -s

