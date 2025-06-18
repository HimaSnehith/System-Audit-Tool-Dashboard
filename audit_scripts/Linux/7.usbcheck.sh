#!/bin/bash

echo -e "\n[Linux USB and Port Audit]"
echo "============================"

# --- Check for necessary commands ---
if ! command -v lsusb &> /dev/null; then
    echo "--- 'lsusb' command not found. Please install 'usbutils' package. ---"
    exit 1
fi
if ! command -v udevadm &> /dev/null; then
    echo "--- 'udevadm' command not found. Please ensure 'udev' or 'systemd' package is installed. ---"
    exit 1
fi
if ! command -v modprobe &> /dev/null; then
    echo "--- 'modprobe' command not found. Cannot manage kernel modules. ---"
    exit 1
fi

echo -e "\n[Audit Result: Detected USB Devices]"
echo "------------------------------------"

# List detected USB devices using lsusb -v for verbose output (more details)
# Piping to grep to filter out empty lines and ensure relevant output
if ! lsusb -v 2>/dev/null | grep -q 'Bus [0-9][0-9][0-9] Device [0-9][0-9][0-9]: ID'; then
    echo "No USB devices detected."
else
    lsusb_output=$(lsusb) # Get basic list first

    echo "Summary of Connected USB Devices:"
    echo "$lsusb_output"
    echo ""

    echo "Detailed Information for Each USB Device:"
    echo "-----------------------------------------"

    # Iterate through each USB device found by lsusb for detailed information
    # Extract Bus and Device numbers to construct the udevadm path
    echo "$lsusb_output" | while IFS= read -r line; do
        if [[ "$line" =~ Bus\ ([0-9]+)\ Device\ ([0-9]+):\ ID\ ([0-9a-fA-F]{4}:[0-9a-fA-F]{4})\ (.*) ]]; then
            bus_num="${BASH_REMATCH[1]}"
            dev_num="${BASH_REMATCH[2]}"
            vendor_product_id="${BASH_REMATCH[3]}"
            description="${BASH_REMATCH[4]}"

            echo "Device: $description (ID: $vendor_product_id)"
            echo "  Bus: $bus_num, Device: $dev_num"

            # Use udevadm for more detailed properties
            # Construct the path for udevadm info
            udev_path="/dev/bus/usb/${bus_num}/${dev_num}"
            if [[ -c "$udev_path" ]]; then # Check if the device node exists
                # Limit udevadm output to relevant security/identification fields
                udevadm info --query=property --name="$udev_path" | grep -E '^(ID_VENDOR_ID|ID_MODEL_ID|ID_VENDOR|ID_MODEL|ID_REVISION|ID_SERIAL_SHORT|DEVTYPE|DRIVER|PRODUCT)' | while IFS= read -r udev_line; do
                    echo "    ${udev_line}"
                done
            else
                echo "    Note: Device node '$udev_path' not found or inaccessible for udevadm details."
            fi
            echo "-----------------------------------------"
        fi
    done
fi


echo -e "\n[Audit Result: USB Storage Module Status]"
echo "-----------------------------------------"

# Check if usb_storage module is loaded
if lsmod | grep -q "^usb_storage"; then
    echo "USB Storage Module (usb_storage): [STATUS] Loaded"
    USB_STORAGE_LOADED="yes"
else
    echo "USB Storage Module (usb_storage): [STATUS] Not Loaded"
    USB_STORAGE_LOADED="no"
fi

# --- USB Storage Management ---
echo -e "\n[Action: Manage USB Storage Access]"
echo "---------------------------------"

if [[ "$USB_STORAGE_LOADED" == "yes" ]]; then
    read -p "USB storage module is currently loaded. Do you want to disable USB storage devices? (Y/N): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        echo "Attempting to disable USB Storage..."
        if sudo modprobe -r usb_storage; then
            echo "USB storage devices are now disabled. Module 'usb_storage' unloaded."
        else
            echo "WARNING: Failed to unload 'usb_storage' module. It might be in use or have dependencies."
            echo "Consider rebooting or investigating processes using USB storage."
        fi
    else
        echo "USB storage will remain enabled."
    fi
else
    read -p "USB storage module is currently not loaded. Do you want to enable USB storage devices? (Y/N): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        echo "Attempting to enable USB Storage..."
        if sudo modprobe usb_storage; then
            echo "USB storage devices are now enabled. Module 'usb_storage' loaded."
        else
            echo "WARNING: Failed to load 'usb_storage' module. Check system logs for details."
        fi
    else
        echo "USB storage will remain disabled."
    fi
fi

echo -e "\nUSB and Port audit complete."

---

## Recommendations (CIS Benchmark Aligned)

1.  Restrict USB Device Usage: Implement policies to restrict or disable the use of unauthorized USB storage devices. This significantly reduces the risk of malware introduction and data exfiltration. (CIS Control 3.5 - Secure Configurations for Wireless, Wired, and Network Devices, 10.4 - Data Protection).
2.  Disable `usb_storage` Module: If USB storage devices are not required for normal operations, disable the `usb_storage` kernel module by blacklisting it in `/etc/modprobe.d/` to prevent its loading at boot.
    * To blacklist: `echo "blacklist usb_storage" | sudo tee /etc/modprobe.d/blacklist-usb-storage.conf`
    * Then update initramfs: `sudo update-initramfs -u` (Debian/Ubuntu) or `sudo dracut -f` (RHEL/CentOS).
3.  Monitor USB Activity: Regularly review system logs (e.g., `journalctl`, `/var/log/syslog`) for `usb` related entries, especially for new device connections, and investigate any unauthorized or suspicious activity. (CIS Control 6.4 - Audit Log Review).
4.  Control Physical Access: Implement physical security measures to prevent unauthorized personnel from connecting devices to USB ports. (CIS Control 12.1 - Physical Access Control).
5.  Use Device Whitelisting: For environments requiring USB devices, implement a whitelisting solution that only allows pre-approved devices based on Vendor ID (VID) and Product ID (PID).
6.  Educate Users: Inform users about the risks associated with untrusted USB devices ("USB dropping" attacks) and the importance of only using authorized equipment.

---

This improved script gives you more insight into your USB landscape and provides practical steps for managing this common attack vector. Would you like to explore any other aspects of your Linux system's security?