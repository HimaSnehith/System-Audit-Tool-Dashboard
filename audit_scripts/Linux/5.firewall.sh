#!/bin/bash

# This script assumes it is run with sufficient privileges (e.g., as root or via sudo from an already elevated process like your Flask app).
# The 'exec sudo bash "$0"' line has been removed to avoid interactive password prompts in a dashboard environment.

echo -e "\n[Linux Firewall Security Audit]"
echo "=================================="

# --- Section 1: Determine Active Firewall System ---
echo -e "\n[Identifying Active Firewall System]"
echo "------------------------------------"

FIREWALL_TOOL=""
FIREWALL_TOOL_NAME=""

if command -v ufw &> /dev/null; then
    FIREWALL_TOOL="ufw"
    FIREWALL_TOOL_NAME="UFW (Uncomplicated Firewall)"
    echo "Active Firewall System: UFW (Uncomplicated Firewall)"
elif command -v firewall-cmd &> /dev/null; then
    FIREWALL_TOOL="firewalld"
    FIREWALL_TOOL_NAME="Firewalld (NetworkManager Firewall Daemon)"
    echo "Active Firewall System: Firewalld"
elif command -v iptables &> /dev/null; then
    FIREWALL_TOOL="iptables"
    FIREWALL_TOOL_NAME="iptables (Netfilter)"
    echo "Active Firewall System: iptables (Legacy/Direct Netfilter Management)"
else
    echo "--- No common firewall management tool (ufw, firewalld, iptables) found. ---"
    echo "--- Basic firewall audit cannot be performed. ---"
    echo "--- Please ensure a firewall management package is installed (e.g., ufw, firewalld). ---"
    exit 1 # Exit if no firewall tool is available
fi

echo -e "\n[Audit Result: Firewall Status]"
echo "-------------------------------"

case "$FIREWALL_TOOL" in
    "ufw")
        ufw_status=$(sudo ufw status verbose)
        echo "$ufw_status"
        if echo "$ufw_status" | grep -q "Status: inactive"; then
            echo "STATUS: [WARNING] UFW Firewall is currently inactive."
        else
            echo "STATUS: [OK] UFW Firewall is active."
        fi
        ;;
    "firewalld")
        firewalld_status=$(sudo firewall-cmd --state)
        echo "Firewalld State: $firewalld_status"
        if [[ "$firewalld_status" == "running" ]]; then
            echo "STATUS: [OK] Firewalld is active."
        else
            echo "STATUS: [WARNING] Firewalld is currently inactive."
        fi
        # Check active zones
        echo -e "\nActive Firewalld Zones:"
        sudo firewall-cmd --get-active-zones
        ;;
    "iptables")
        echo "--- iptables rules are displayed directly. ---"
        sudo iptables -L -v -n
        ;;
esac

# --- Section 3: Allowed Services / Open Ports ---
echo -e "\n[Audit Result: Allowed Services / Open Ports]"
echo "-------------------------------------------"

case "$FIREWALL_TOOL" in
    "ufw")
        echo "UFW Application List (Profiles):"
        # Ensure sudo is used for ufw app list as well
        sudo ufw app list
        echo -e "\nUFW Rules Allowing Incoming Connections:"
        # Ensure sudo is used for ufw status numbered
        sudo ufw status numbered | grep "ALLOW IN"
        ;;
    "firewalld")
        echo "Firewalld Enabled Services (Permanent):"
        sudo firewall-cmd --list-all --permanent
        echo -e "\nFirewalld Enabled Ports (Permanent):"
        sudo firewall-cmd --list-ports --permanent
        ;;
    "iptables")
        echo "Open Ports (Listening Services - requires netstat/ss):"
        if command -v ss &> /dev/null; then
            sudo ss -tuln
        elif command -v netstat &> /dev/null; then
            sudo netstat -tulnp
        else
            echo "--- Neither 'ss' nor 'netstat' found. Cannot list open ports. ---"
            echo "--- Please install 'iproute2' (for ss) or 'net-tools' (for netstat). ---"
        fi
        echo -e "\niptables INPUT Chain Rules (Allowing incoming traffic):"
        sudo iptables -L INPUT -v -n
        ;;
esac

# --- Section 4: Firewall Logging Settings ---
echo -e "\n[Audit Result: Firewall Logging Settings]"
echo "-----------------------------------------"

case "$FIREWALL_TOOL" in
    "ufw")
        # Corrected: Use 'sudo ufw status verbose' to get logging status or 'sudo ufw show logging'
        # The 'ufw show logging' command should work. Let's make sure it's prefixed with sudo.
        ufw_logging=$(sudo ufw show logging)
        echo "$ufw_logging"
        if echo "$ufw_logging" | grep -q "logging: on"; then
            echo "UFW Logging: [OK] Enabled."
        else
            echo "UFW Logging: [WARNING] Disabled. Enable for better audit trails."
        fi
        ;;
    "firewalld")
        # Firewalld logging is configured via rules (e.g., --add-rich-rule with 'log' action)
        # Checking if any rules have logging enabled is complex for a simple script.
        echo "Firewalld logging is rule-specific. Basic check for 'log' rules:"
        sudo firewall-cmd --list-all | grep "log prefix"
        if [[ $? -eq 0 ]]; then
            echo "Firewalld Logging: [OK] Some logging rules detected."
        else
            echo "Firewalld Logging: [WARNING] No explicit logging rules found."
        fi
        ;;
    "iptables")
        echo "iptables logging is rule-specific. Checking for LOG rules in chains:"
        sudo iptables -L -v -n | grep "LOG"
        if [[ $? -eq 0 ]]; then
            echo "iptables Logging: [OK] Some logging rules detected."
        else
            echo "iptables Logging: [WARNING] No explicit LOG rules found."
        fi
        ;;
esac

echo -e "\nFirewall Audit Completed."

echo -e "\nRecommendations (CIS Benchmark Aligned):"
echo "=========================================="
echo "1. Enable and Activate Firewall: Ensure the firewall service is enabled at boot and active. A disabled firewall leaves the system vulnerable. (CIS Control 3.4 - Secure Network Configurations)."
echo "2. Default Deny Policy: Configure default firewall policies to block all inbound and outbound traffic unless explicitly allowed by specific rules. This implements the principle of least privilege. (CIS Control 9.1 - Network Segmentation and Defense)."
echo "3. Minimize Open Ports/Services: Only allow necessary ports and services. Regularly review and remove rules for applications or services no longer in use. (CIS Control 2.1 - Software Inventory, 9.2 - Implement and Manage Network Access Controls)."
echo "4. Enable Firewall Logging: Configure the firewall to log dropped packets and (optionally) accepted connections. This logging is critical for security monitoring, incident response, and troubleshooting. (CIS Control 6.4 - Audit Log Review)."
echo "5. Monitor Firewall Logs: Regularly review firewall logs for suspicious activity, unauthorized connection attempts, and policy violations. Integrate logs with a centralized logging solution if possible. (CIS Control 6.5 - Central Log Management)."
echo "6. Specific Rules for Services: Create specific firewall rules for each service, limiting access to only necessary source IPs/networks and destinations. Avoid broad 'ALLOW ALL' rules."
echo "7. Utilize Firewall Zones/Profiles: If using Firewalld, properly configure and utilize zones to separate network interfaces and apply appropriate rule sets based on trust levels (e.g., public, home, internal)."
echo "8. Implement Egress Filtering: While often overlooked, implement outbound filtering to prevent malware from phoning home or exfiltrating data. (CIS Control 9.3 - Implement and Manage Network Access Controls)."
