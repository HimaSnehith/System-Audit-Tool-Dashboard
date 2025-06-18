#!/bin/bash

echo -e "\n[Linux Kernel Modules Audit]"
echo "=============================="

# Check for necessary commands
if ! command -v lsmod &> /dev/null; then
    echo "--- 'lsmod' command not found. Cannot list loaded kernel modules. ---"
    echo "Please ensure 'kmod' package is installed."
    exit 1
fi
if ! command -v modinfo &> /dev/null; then
    echo "--- 'modinfo' command not found. Cannot retrieve module details. ---"
    echo "Please ensure 'kmod' package is installed."
    exit 1
fi
if ! command -v awk &> /dev/null; then
    echo "--- 'awk' command not found. This script requires 'awk'. ---"
    echo "Please ensure 'gawk' or 'mawk' package is installed."
    exit 1
fi
if ! command -v grep &> /dev/null; then
    echo "--- 'grep' command not found. This script requires 'grep'. ---"
    echo "Please ensure 'grep' package is installed."
    exit 1
fi


echo -e "\n[Audit Result: Loaded Kernel Modules]"
echo "-------------------------------------"

# Get a list of loaded kernel modules and their basic info from lsmod
# Exclude the header line from lsmod output
loaded_modules=$(lsmod | tail -n +2)

if [[ -z "$loaded_modules" ]]; then
    echo "--- No kernel modules currently loaded (this is highly unusual for a running system). ---"
else
    echo "Details for Loaded Kernel Modules:"
    echo "---------------------------------"
    
    # Process each module line from lsmod
    echo "$loaded_modules" | while IFS= read -r line; do
        module_name=$(echo "$line" | awk '{print $1}')
        module_size=$(echo "$line" | awk '{print $2}')
        module_used_by=$(echo "$line" | awk '{print $4}')

        echo "Module Name       : $module_name"
        echo "  Size            : $module_size bytes"
        echo "  Used By         : ${module_used_by:-None}"

        # Fetch detailed info using modinfo
        modinfo_output=$(modinfo "$module_name" 2>/dev/null) # Redirect stderr to dev/null for cleaner output

        # Extract specific fields from modinfo output
        description=$(echo "$modinfo_output" | grep -i "description:" | awk -F": " '{print $2}' | xargs)
        license=$(echo "$modinfo_output" | grep -i "license:" | awk -F": " '{print $2}' | xargs)
        author=$(echo "$modinfo_output" | grep -i "author:" | awk -F": " '{print $2}' | xargs)
        filename=$(echo "$modinfo_output" | grep -i "filename:" | awk -F": " '{print $2}' | xargs)
        signer=$(echo "$modinfo_output" | grep -i "signer:" | awk -F": " '{print $2}' | xargs)
        vermagic=$(echo "$modinfo_output" | grep -i "vermagic:" | awk -F": " '{print $2}' | xargs)

        echo "  Description     : ${description:-N/A}"
        echo "  License         : ${license:-N/A}"
        echo "  Author          : ${author:-N/A}"
        echo "  File Path       : ${filename:-N/A}"
        echo "  Kernel Version  : ${vermagic:-N/A}"

        # Determine signing status
        if [[ -z "$signer" ]]; then
            echo "  Signature Status: [WARNING] Unsigned/Unverified (No 'signer' info detected)"
            echo "    Recommendation: Investigate this module. Unsigned modules can be a security risk."
        else
            echo "  Signature Status: [OK] Signed by: $signer"
        fi
        echo "------------------------------------"
    done
fi

echo -e "\nAudit Completed: Loaded Kernel Modules."

echo -e "\nRecommendations (CIS Benchmark Aligned):"
echo "=========================================="
echo "1. Only Load Signed Modules: Configure the system to only allow digitally signed kernel modules to load. This prevents the loading of unauthorized or malicious code into the kernel. (CIS Control 3.1 - Secure Configurations for Hardware and Software)."
echo "2. Review Unsigned Modules: Promptly investigate any unsigned kernel modules detected. Verify their origin, purpose, and legitimacy. If unauthorized or suspicious, take immediate action to remove or block them."
echo "3. Disable Unnecessary Modules: Unload and disable any kernel modules that are not essential for system operation. This reduces the attack surface of the kernel. (CIS Control 2.1 - Software Inventory & Control)."
echo "4. Keep Kernel Updated: Ensure the Linux kernel is regularly updated to the latest stable version. Kernel updates frequently include security patches for known vulnerabilities in modules and the kernel itself. (CIS Control 7.1 - Continuous Vulnerability Management)."
echo "5. Secure Boot/Integrity Monitoring: Implement Secure Boot and/or kernel integrity monitoring (e.g., IMA/EVM) to ensure that the kernel and its modules have not been tampered with since boot. (CIS Control 3.1)."
echo "6. Audit Module Loading: Monitor system logs (e.g., dmesg, kernel ring buffer) for messages related to module loading, especially any failures or warnings about unsigned modules. (CIS Control 6.4 - Audit Log Review)."