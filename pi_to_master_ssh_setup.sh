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
    sshpass -p "$WORKER_PASSWORD" ssh -o StrictHostKeyChecking=no "$WORKER_USERNAME@$ip" \
        "cat ~/.ssh/id_ed25519.pub" | grep -v "^$" >> ~/.ssh/authorized_keys

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

# 5) Set up Pi-to-Pi connectivity
echo "===== Setting up Pi-to-Pi connections ====="

for source_alias in "${!WORKERS[@]}"; do
    source_ip="${WORKERS[$source_alias]}"
    
    echo "Setting up connections from $source_alias to all other Pis..."
    
    # For each potential target Pi
    for target_alias in "${!WORKERS[@]}"; do
        target_ip="${WORKERS[$target_alias]}"
        
        # Skip setting up connection to self
        if [ "$source_alias" != "$target_alias" ]; then
            echo "  Configuring $source_alias -> $target_alias connection..."
            
            # Add worker info to the source worker's SSH config
            SSH_WORKER_CONFIG=$(cat <<EOF

Host ${target_alias}
  HostName ${target_ip}
  User $WORKER_USERNAME
EOF
            )
            
            # Add to SSH config if not already present
            sshpass -p "$WORKER_PASSWORD" ssh -o StrictHostKeyChecking=no "$WORKER_USERNAME@$source_ip" \
                "if ! grep -q 'Host ${target_alias}' ~/.ssh/config; then 
                    echo '$SSH_WORKER_CONFIG' >> ~/.ssh/config; 
                    echo '    Added ${target_alias} to SSH config'; 
                 else
                    echo '    ${target_alias} already in SSH config';
                 fi"
            
            # Add to /etc/hosts if not already present
            HOSTS_WORKER_ENTRY="${target_ip} ${target_alias}"
            sshpass -p "$WORKER_PASSWORD" ssh -o StrictHostKeyChecking=no "$WORKER_USERNAME@$source_ip" \
                "if ! grep -q '$HOSTS_WORKER_ENTRY' /etc/hosts; then 
                    echo $WORKER_PASSWORD | sudo -S bash -c \"echo '$HOSTS_WORKER_ENTRY' >> /etc/hosts\"; 
                    echo '    Added ${target_alias} to /etc/hosts'; 
                 else
                    echo '    ${target_alias} already in /etc/hosts';
                 fi"
            
            # Copy SSH key from source to target for passwordless access
            echo "  Setting up passwordless SSH from $source_alias to $target_alias..."
            sshpass -p "$WORKER_PASSWORD" ssh -o StrictHostKeyChecking=no "$WORKER_USERNAME@$source_ip" \
                "cat ~/.ssh/id_ed25519.pub" | \
                sshpass -p "$WORKER_PASSWORD" ssh -o StrictHostKeyChecking=no "$WORKER_USERNAME@$target_ip" \
                "mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
                 cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && \
                 echo '    SSH key exchange complete'"
        fi
    done
    
    echo "  Finished setting up connections from $source_alias"
    echo ""
done

# 6) Display the MASTER's .ssh/config and /etc/hosts
echo ""
echo ".ssh/config (below):"
cat ~/.ssh/config

echo ""
echo "/etc/hosts (below):"
cat /etc/hosts

# 7) Verify Pi-to-Pi connectivity
echo ""
echo "===== Verifying Pi-to-Pi Connectivity ====="

for source_alias in "${!WORKERS[@]}"; do
    source_ip="${WORKERS[$source_alias]}"
    
    for target_alias in "${!WORKERS[@]}"; do
        # Skip checking connection to self
        if [ "$source_alias" != "$target_alias" ]; then
            echo "Testing connection from $source_alias to $target_alias..."
            connection_result=$(sshpass -p "$WORKER_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$WORKER_USERNAME@$source_ip" \
                "ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no $target_alias 'echo CONNECTION_OK'" 2>&1)
            
            if [[ "$connection_result" == *"CONNECTION_OK"* ]]; then
                echo "  ✅ Connection successful!"
            else
                echo "  ❌ Connection failed: $connection_result"
            fi
        fi
    done
    echo ""
done