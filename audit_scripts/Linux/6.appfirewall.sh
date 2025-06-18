#!/bin/bash

echo -e "\e[96mLinux Firewall Application & Connection Audit\e[0m"

# Check firewall status
echo -e "\n\e[93mFirewall Status:\e[0m"
sudo ufw status verbose

# Get allowed applications
echo -e "\n\e[92mAllowed Applications Through Firewall:\e[0m"
sudo ufw app list

# Get all blocked rules
echo -e "\n\e[91mBlocked Rules:\e[0m"
sudo ufw status numbered | grep "DENY"

# List open ports and associated processes
echo -e "\n\e[96mActive Connections & Open Ports:\e[0m"
ss -tulnp 2>/dev/null | awk '{print $1, $2, $3, $4, $5, $6}' | column -t

# Firewall logging status
echo -e "\n\e[95mFirewall Logging Status:\e[0m"
sudo ufw status | grep "Logging"

echo -e "\n\e[92mFirewall Audit Completed.\e[0m"

