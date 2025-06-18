#!/bin/bash

echo -e "\n🔍 [Linux Service Audit]"

# List all running services
echo -e "\n✅ Running Services:"
systemctl list-units --type=service --state=running | awk '{print $1}' | tail -n +2 | head -n -7

# Check recently installed services (last 7 days)
echo -e "\n⏳ [Recently Installed Services (Last 7 Days)]"
find /etc/systemd/system /lib/systemd/system -type f -ctime -7 2>/dev/null

# Check for services running outside standard locations
echo -e "\n⚠️ [Services Running from Unusual Locations]"
for service in $(systemctl list-units --type=service --state=running | awk '{print $1}' | tail -n +2 | head -n -7); do
    path=$(systemctl show -p ExecStart "$service" 2>/dev/null | cut -d= -f2 | awk '{print $1}')
    if [[ "$path" != "/usr/bin/"* && "$path" != "/bin/"* && "$path" != "/sbin/"* && "$path" != "/usr/sbin/"* ]]; then
        echo -e "❌ Suspicious Service: $service -> $path"
    fi
done

echo -e "\n✅ Service Audit Complete!"
  
