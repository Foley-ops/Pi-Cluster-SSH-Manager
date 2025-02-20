#!/bin/bash

# Load environment variables from .env file
source .env

# Load worker aliases and IPs from workers.txt into an associative array
unset WORKERS
declare -A WORKERS

while IFS='=' read -r alias ip; do
    alias=$(echo "$alias" | xargs)
    ip=$(echo "$ip" | xargs)
    [[ -n "$alias" && -n "$ip" ]] && WORKERS["$alias"]="$ip"
done < workers.txt

# Create a directory to store the configuration files
mkdir -p pi_configs

for alias in "${!WORKERS[@]}"; do
    ip="${WORKERS[$alias]}"
    echo "===== Gathering config files from $alias ($ip) ====="

    # Retrieve ~/.ssh/config
    echo "Fetching ~/.ssh/config from $alias ($ip)..."
    sshpass -p "$WORKER_PASSWORD" ssh -o StrictHostKeyChecking=no "$WORKER_USERNAME@$ip" \
        "cat ~/.ssh/config" > "pi_configs/${alias}_ssh_config.txt" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "Successfully retrieved ~/.ssh/config from $alias ($ip)."
    else
        echo "Failed to retrieve ~/.ssh/config from $alias ($ip) or file does not exist."
    fi

    # Retrieve /etc/hosts
    echo "Fetching /etc/hosts from $alias ($ip)..."
    sshpass -p "$WORKER_PASSWORD" ssh -o StrictHostKeyChecking=no "$WORKER_USERNAME@$ip" \
        "cat /etc/hosts" > "pi_configs/${alias}_hosts.txt" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "Successfully retrieved /etc/hosts from $alias ($ip)."
    else
        echo "Failed to retrieve /etc/hosts from $alias ($ip)."
    fi

    echo ""
done

# Display the collected files
echo "===== Displaying Collected Configuration Files ====="
for file in pi_configs/*; do
    echo "=== File: $file ==="
    cat "$file"
    echo ""
    echo "============================================="
    echo ""
done

echo "Config file gathering complete."
