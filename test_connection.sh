#!/bin/bash

# Load environment variables from .env file
source .env

# Load worker aliases and IPs from workers.txt into an associative array
unset WORKERS
declare -A WORKERS

while IFS='=' read -r alias ip; do
    [[ -n "$alias" && -n "$ip" ]] && WORKERS["$alias"]="$ip"
done < workers.txt

# Formatting
separator="=================================================="

echo -e "\n$separator"
echo "        Raspberry Pis Connectivity to MASTER"
echo -e "$separator\n"

# Column headers
printf "%-15s | %-15s | %-10s | %-15s | %-25s\n" "Alias" "IP Address" "Status" "SSH Status" "MASTER Communication"
echo "$separator"

for alias in "${!WORKERS[@]}"; do
    ip="${WORKERS[$alias]}"

    if ping -c 2 -W 1 "$ip" >/dev/null; then
        online_status="✅ Online"
        
        if ssh -o BatchMode=yes -o ConnectTimeout=3 "$WORKER_USERNAME@$ip" "echo SSH OK" 2>/dev/null; then
            ssh_status="✅ Connected"
        else
            ssh_status="❌ FAILED"
        fi
        
        if ssh "$WORKER_USERNAME@$ip" "ping -c 2 -W 1 $MASTER >/dev/null" 2>/dev/null; then
            master_comm="✅ Reachable"
        else
            master_comm="❌ FAILED"
        fi
    else
        online_status="❌ Offline"
        ssh_status="N/A"
        master_comm="N/A"
    fi
    
    printf "%-15s | %-15s | %-10s | %-15s | %-25s\n" "$alias" "$ip" "$online_status" "$ssh_status" "$master_comm"
done

echo -e "\n$separator"
echo "Check complete."
echo "$separator"
