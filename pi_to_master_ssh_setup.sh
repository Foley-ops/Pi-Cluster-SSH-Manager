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

for alias in "${!WORKERS[@]}"; do
    ip="${WORKERS[$alias]}"
    echo "===== Configuring worker at $alias ($ip) ====="

    # 1) Generate SSH key on the WORKER only if it doesn't exist
    sshpass -p "$WORKER_PASSWORD" ssh -o StrictHostKeyChecking=no "$WORKER_USERNAME@$ip" \
        "if [ -f ~/.ssh/id_ed25519 ]; then
           echo 'SSH key already exists, skipping generation.'
         else
           ssh-keygen -t ed25519 -C 'pi_n' -N '' -f ~/.ssh/id_ed25519
         fi"

    # 2) Copy the WORKER's newly created key to the MASTER (without password prompt)
    sshpass -p "$WORKER_PASSWORD" ssh-copy-id -f -i ~/.ssh/id_ed25519.pub -o StrictHostKeyChecking=no "$WORKER_USERNAME@$ip"

    # 3) Add the WORKER info to MASTER's ~/.ssh/config only if not present
    SSH_CONFIG_ENTRY=$(cat <<EOF

Host ${alias}
  HostName $ip
  User $WORKER_USERNAME
EOF
    )

    if ! grep -q "Host ${alias}" ~/.ssh/config; then
        echo "Updating MASTER .ssh/config for ${alias}..."
        echo "$SSH_CONFIG_ENTRY" >> ~/.ssh/config
    else
        echo ".ssh/config already up-to-date for ${alias}."
    fi

    # 4) Add the WORKER to MASTER's /etc/hosts only if not present
    HOSTS_ENTRY="$ip ${alias}"

    if ! grep -q "$HOSTS_ENTRY" /etc/hosts; then
        echo "Updating MASTER /etc/hosts for ${alias}..."
        echo "$HOSTS_ENTRY" | sudo -S tee -a /etc/hosts > /dev/null
    else
        echo "/etc/hosts already contains entry for ${alias}."
    fi

    echo ""
    echo "===== Finished configuring worker at $alias ($ip) ====="
done

# 5) Display the MASTER's .ssh/config and /etc/hosts
echo ""
echo ".ssh/config (below):"
cat ~/.ssh/config

echo ""
echo "/etc/hosts (below):"
cat /etc/hosts
