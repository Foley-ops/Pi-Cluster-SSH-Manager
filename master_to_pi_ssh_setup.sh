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

    # 1) Copy the SSH key to each worker if not already present
    if ! ssh -o PasswordAuthentication=no "$WORKER_USERNAME@$ip" "echo SSH key already exists"; then
        echo "Copying SSH key to $alias ($ip)..."
        sshpass -p "$WORKER_PASSWORD" ssh-copy-id -f -i "$SSH_KEY" -o StrictHostKeyChecking=no "$WORKER_USERNAME@$ip"
    else
        echo "SSH key already exists on $alias ($ip), skipping."
    fi

    # 2) Add MASTER info to the worker's ~/.ssh/config if not already present
    SSH_CONFIG_ENTRY=$(cat <<EOF

Host MASTER
  HostName $MASTER_IP
  User $MASTER_USERNAME
EOF
    )

    if ! ssh "$WORKER_USERNAME@$ip" "grep -q 'Host MASTER' ~/.ssh/config"; then
        echo "Updating ~/.ssh/config on $alias ($ip)..."
        sshpass -p "$WORKER_PASSWORD" ssh -o StrictHostKeyChecking=no "$WORKER_USERNAME@$ip" \
            "mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
            echo '$SSH_CONFIG_ENTRY' >> ~/.ssh/config"
    else
        echo "$HOME/.ssh/config on $alias ($ip) already up-to-date."
    fi

    # 3) Add MASTER info to the worker's /etc/hosts if not already present
    HOSTS_ENTRY="$MASTER_IP MASTER"

    if ! ssh "$WORKER_USERNAME@$ip" "grep -q '$HOSTS_ENTRY' /etc/hosts"; then
        echo "Updating /etc/hosts on $alias ($ip)..."
        sshpass -p "$WORKER_PASSWORD" ssh -o StrictHostKeyChecking=no "$WORKER_USERNAME@$ip" \
            "echo $WORKER_PASSWORD | sudo -S bash -c \"echo '$HOSTS_ENTRY' >> /etc/hosts\""
    else
        echo "/etc/hosts on $alias ($ip) already contains the MASTER entry."
    fi

    # 4) Get the WORKER's hostname
    WORKER_HOSTNAME=$(sshpass -p "$WORKER_PASSWORD" ssh -o StrictHostKeyChecking=no "$WORKER_USERNAME@$ip" "hostname")

    # 5) Display final info in a neat format:
    echo ""
    echo "WORKER NAME           WORKER IP"
    echo "$WORKER_HOSTNAME               $ip"
    echo ""

    echo "=== === === === === .ssh/config === === === === ==="
    sshpass -p "$WORKER_PASSWORD" ssh -o StrictHostKeyChecking=no "$WORKER_USERNAME@$ip" "cat ~/.ssh/config"
    echo "=== === === === === .ssh/config === === === === ==="
    echo ""

    echo "=== === === === === /etc/hosts  === === === === ==="
    sshpass -p "$WORKER_PASSWORD" ssh -o StrictHostKeyChecking=no "$WORKER_USERNAME@$ip" cat /etc/hosts
    echo "=== === === === === /etc/hosts  === === === === ==="
    echo "======================================"
    echo ""
done
