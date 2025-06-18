#!/bin/bash

echo -e "\n[Bluetooth Audit]"
echo "==================="

# --- Section 1: Bluetooth Service Status ---
echo -e "\n[Bluetooth Service Status]"
echo "--------------------------"
# Check if systemctl command exists
if ! command -v systemctl &> /dev/null; then
    echo "--- 'systemctl' command not found. Cannot check Bluetooth service status. ---"
else
    bluetooth_service_status=$(systemctl is-active bluetooth)
    if [[ "$bluetooth_service_status" == "active" ]]; then
        echo "Bluetooth Service: [OK] Active (Running)"
    else
        echo "Bluetooth Service: [FAIL] Inactive (Not Running)"
        echo "Recommendation: Consider enabling Bluetooth service only when needed."
    fi
fi

# --- Section 2: Bluetooth Adapter Status ---
echo -e "\n[Bluetooth Adapter Status]"
echo "--------------------------"
# Check if bluetoothctl command exists
if ! command -v bluetoothctl &> /dev/null; then
    echo "--- 'bluetoothctl' command not found. Cannot check Bluetooth adapter status. Please install 'bluez' package. ---"
else
    adapter_info=$(bluetoothctl show)
    
    # Extract details. Using grep and awk is robust for specific fields.
    adapter_name=$(echo "$adapter_info" | grep "Name:" | awk '{print $2}')
    adapter_mac=$(echo "$adapter_info" | grep "Address:" | awk '{print $2}')
    adapter_powered=$(echo "$adapter_info" | grep "Powered:" | awk '{print $2}')
    adapter_discoverable=$(echo "$adapter_info" | grep "Discoverable:" | awk '{print $2}')
    adapter_pairable=$(echo "$adapter_info" | grep "Pairable:" | awk '{print $2}')

    if [[ -z "$adapter_mac" ]]; then
        echo "No Bluetooth adapter found or accessible via bluetoothctl."
    else
        echo "Adapter Name: ${adapter_name:-N/A}"
        echo "MAC Address: $adapter_mac"
        
        if [[ "$adapter_powered" == "yes" ]]; then
            echo "Status: [OK] Powered On"
        else
            echo "Status: [FAIL] Powered Off"
            echo "Recommendation: Turn off Bluetooth adapter when not in use."
        fi

        if [[ "$adapter_discoverable" == "yes" ]]; then
            echo "Discoverable Mode: [WARN] Enabled (Visible to other devices)"
            echo "Recommendation: Disable discoverable mode when not pairing."
        else
            echo "Discoverable Mode: [OK] Disabled"
        fi

        if [[ "$adapter_pairable" == "yes" ]]; then
            echo "Pairable Mode: [WARN] Enabled (Ready for new connections)"
            echo "Recommendation: Disable pairable mode when not pairing."
        else
            echo "Pairable Mode: [OK] Disabled"
        fi
    fi
fi

# --- Section 3: Paired External Bluetooth Devices ---
echo -e "\n[Paired External Bluetooth Devices]"
echo "-----------------------------------"
if ! command -v bluetoothctl &> /dev/null; then
    echo "--- 'bluetoothctl' command not found. Cannot list paired devices. ---"
else
    # Get MAC addresses of paired devices
    paired_device_macs=$(bluetoothctl devices | awk '{print $2}') 

    if [[ -z "$paired_device_macs" ]]; then
        echo "No paired external Bluetooth devices found."
    else
        echo "Found paired devices:"
        for device_mac in $paired_device_macs; do
            # Get detailed info for each paired device
            device_info=$(bluetoothctl info "$device_mac")
            
            # Extract details using grep and awk (more robust than cutting fixed columns)
            device_name=$(echo "$device_info" | grep "Name:" | awk '{$1=""; print $0}' | xargs) # Get full name, remove "Name:"
            device_trusted=$(echo "$device_info" | grep "Trusted:" | awk '{print $2}' | xargs)
            device_connected=$(echo "$device_info" | grep "Connected:" | awk '{print $2}' | xargs)
            
            echo "  - Device Name: ${device_name:-Unknown}"
            echo "    MAC Address: $device_mac"
            echo "    Connected: ${device_connected:-Unknown}"
            
            if [[ "$device_trusted" == "yes" ]]; then
                echo "    Trusted: [OK] Yes (Device is trusted for auto-connect/services)"
            else
                echo "    Trusted: [WARN] No (Device is not explicitly trusted for auto-connect)"
                echo "    Recommendation: Review if this device truly needs to be paired or trusted."
            fi
            echo "-----------------------------------"
        done
    fi
fi

echo -e "\nRecommendations (CIS Benchmark Aligned):"
echo "=========================================="
echo "1. Disable Bluetooth When Not in Use: Turn off the Bluetooth service and adapter when not actively using Bluetooth devices to reduce the attack surface. (CIS Control 8.1 - Malware Defenses, 3.4 - Secure Configurations for Wireless)."
echo "2. Keep Bluetooth Software Updated: Ensure your Bluetooth drivers and software (e.g., BlueZ package) are regularly updated to patch known vulnerabilities. (CIS Control 7.1 - Continuous Vulnerability Management)."
echo "3. Monitor for Unexpected Connections: Be vigilant for any unexpected Bluetooth connection attempts or connections to unknown devices, which could indicate unauthorized access."