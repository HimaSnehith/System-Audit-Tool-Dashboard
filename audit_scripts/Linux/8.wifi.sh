#!/bin/bash

# Define common trusted public DNS servers
TRUSTED_PUBLIC_DNS=("8.8.8.8" "8.8.4.4" "1.1.1.1" "9.9.9.9")

echo -e "\n[Network Interface & Wi-Fi Status Audit]"
echo "=========================================="

# --- Section 1: Network Interfaces Overview ---
echo -e "\n[Network Interfaces Overview]"
echo "-----------------------------"
if ! command -v ip &> /dev/null; then
    echo "❌ 'ip' command not found. Cannot retrieve network interface details. Please install 'iproute2'."
else
    ip -br a | awk '{print "Interface:", $1, "| State:", $2, "| IP(s):", $3, "| MAC:", $4}'
    echo # Newline for readability
fi

# --- Section 2: Connected Wi-Fi Details ---
echo -e "\n[Connected Wi-Fi Details]"
echo "-------------------------"
if ! command -v nmcli &> /dev/null; then
    echo "❌ 'nmcli' command not found. Cannot retrieve Wi-Fi details. Please install 'network-manager' package."
else
    wifi_ssid=$(nmcli -t -f ACTIVE,SSID dev wifi | awk -F: '$1=="yes" {print $2}')

    if [[ -n "$wifi_ssid" ]]; then
        echo "Connected Wi-Fi SSID: $wifi_ssid"
        
        security_type=$(nmcli -t -f SECURITY dev wifi | grep -m1 "$wifi_ssid" | cut -d':' -f2 | xargs) # xargs to trim whitespace
        bssid=$(nmcli -t -f BSSID dev wifi | grep -m1 "$wifi_ssid" | cut -d':' -f2 | xargs)
        
        echo "Security Type: ${security_type:-Unknown}"
        echo "MAC Address (BSSID): ${bssid:-Unknown}"

        if [[ "$security_type" == *"WEP"* || "$security_type" == *"none"* ]]; then
            echo "⚠ WARNING: This network is insecure! (WEP/Open)"
        else
            echo "✅ Secure network detected."
        fi
    else
        echo "No active Wi-Fi connection detected."
    fi
fi

# --- Section 3: Saved Wi-Fi Networks ---
echo -e "\n[Saved Wi-Fi Networks Audit]"
echo "----------------------------"
if ! command -v nmcli &> /dev/null; then
    echo "❌ 'nmcli' command not found. Cannot list saved Wi-Fi networks."
else
    saved_connections=$(nmcli -t -f NAME,TYPE,AUTOCONNECT,SECURITY connection show --active=no --type=wifi)

    if [[ -z "$saved_connections" ]]; then
        echo "✅ No saved Wi-Fi profiles found."
    else
        echo "Saved Wi-Fi Profiles:"
        echo "$saved_connections" | while IFS=':' read -r name type autoconnect security; do
            # Remove any leading/trailing whitespace
            name=$(echo "$name" | xargs)
            security=$(echo "$security" | xargs)
            autoconnect=$(echo "$autoconnect" | xargs)

            echo "  - Profile Name: $name"
            echo "    Auto-Connect: $autoconnect"
            echo "    Security: ${security:-None/Unknown}"
            
            if [[ "$security" == *"WEP"* || "$security" == *"none"* ]]; then
                echo "    ⚠ WARNING: This saved profile uses insecure encryption (WEP/Open)."
            fi
            echo "------------------------------"
        done
    fi
fi

# --- Section 4: Current DNS Servers ---
echo -e "\n[Current DNS Servers]"
echo "---------------------"
if ! command -v nmcli &> /dev/null; then
    echo "❌ 'nmcli' command not found. Cannot retrieve DNS servers."
else
    dns_servers=$(nmcli dev show | grep 'IP4.DNS' | awk '{print $2}')
    if [[ -z "$dns_servers" ]]; then
        echo "No DNS servers configured via NetworkManager."
    else
        for dns in $dns_servers; do
            echo "- $dns"
            is_trusted_public=false
            for trusted_dns in "${TRUSTED_PUBLIC_DNS[@]}"; do
                if [[ "$dns" == "$trusted_dns" ]]; then
                    is_trusted_public=true
                    break
                fi
            done

            if [[ "$dns" =~ ^(127\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.) ]]; then
                echo "  ✅ Private/Local DNS detected (e.g., router, internal DNS)."
            elif $is_trusted_public; then
                echo "  ✅ Trusted public DNS detected."
            else
                echo "  ⚠ WARNING: Unknown or potentially untrusted DNS server detected!"
            fi
        done
    fi
fi

# --- Section 5: Firewall Status (UFW/Firewalld) ---
echo -e "\n[Firewall Status]"
echo "-----------------"

if command -v ufw &> /dev/null; then
    firewall_status_ufw=$(sudo ufw status | grep -i "Status:")
    echo "$firewall_status_ufw"
    if [[ "$firewall_status_ufw" == *"inactive"* ]]; then
        echo "⚠ WARNING: UFW Firewall is disabled!"
    else
        echo "✅ UFW Firewall is enabled."
    fi
    # Also check service status
    if systemctl is-active --quiet ufw; then
        echo "UFW Service Status: Active (Running)"
    else
        echo "UFW Service Status: Inactive"
    fi
elif command -v firewall-cmd &> /dev/null; then
    firewall_status_firewalld=$(sudo firewall-cmd --state)
    echo "Firewalld Status: $firewall_status_firewalld"
    if [[ "$firewall_status_firewalld" == "running" ]]; then
        echo "✅ Firewalld Firewall is enabled."
    else
        echo "⚠ WARNING: Firewalld Firewall is disabled!"
    fi
    if systemctl is-active --quiet firewalld; then
        echo "Firewalld Service Status: Active (Running)"
    else
        echo "Firewalld Service Status: Inactive"
    fi
else
    echo "❌ Neither 'ufw' nor 'firewall-cmd' found. Cannot determine firewall status. Please install a firewall management tool (e.g., ufw or firewalld)."
fi

# --- Section 6: Network Interface Promiscuous Mode Audit ---
echo -e "\n[Promiscuous Mode Audit]"
echo "------------------------"
if ! command -v ip &> /dev/null; then
    echo "❌ 'ip' command not found. Cannot check promiscuous mode."
else
    # Look for interfaces in PROMISC mode
    promisc_interfaces=$(ip link show | grep PROMISC | awk -F: '{print $2}' | xargs)
    if [[ -z "$promisc_interfaces" ]]; then
        echo "✅ No network interfaces found in promiscuous mode."
    else
        echo "⚠ WARNING: The following interfaces are in promiscuous mode:"
        for iface in $promisc_interfaces; do
            echo " - $iface"
        done
        echo "  Promiscuous mode allows capturing all network traffic, which could indicate a sniffing attack."
    fi
fi


echo -e "\nRecommendations (CIS Benchmark Aligned):"
echo "=========================================="
echo "1. Enable and Configure Firewall: Ensure a firewall (like UFW or Firewalld) is active and properly configured to block unauthorized inbound connections. Default deny, explicit allow."
echo "2. Review Saved Wi-Fi Profiles: Delete any unused or unrecognized Wi-Fi profiles. Each saved profile can be a potential automatic connection risk."
echo "3. Enforce Strong Wi-Fi Security: Only connect to and save profiles for networks using strong encryption (WPA2/WPA3). Avoid WEP or open networks entirely."
echo "4. Limit Auto-Connect: Configure 'Connect automatically' only for highly trusted and essential networks. Avoid this for public or less secure Wi-Fi hotspots."
echo "5. Verify DNS Servers: Ensure your system is using trusted DNS servers (e.g., internal DNS, well-known public DNS like Google/Cloudflare). Investigate any unknown DNS servers immediately."
echo "6. Disable Wi-Fi/Bluetooth when Not in Use: Turn off wireless adapters when not actively being used to reduce exposure to wireless attacks."
echo "7. Monitor Promiscuous Mode: Regularly audit network interfaces for promiscuous mode. If detected without justification, it could indicate a sniffing attack or malicious software."
echo "8. Regular Network Audits: Periodically review overall network configurations, open ports, and active connections for unauthorized activity."