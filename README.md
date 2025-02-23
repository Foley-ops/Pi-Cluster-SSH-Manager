# Pi Cluster SSH Manager

Automate SSH key generation, configuration management, and connectivity testing for a Raspberry Pi cluster. This suite of scripts ensures seamless communication between a master device and worker Pis by managing .ssh/config and /etc/hosts files. This setup is designed to facilitate building a distributed system using the Raspberry Pi cluster.

---

## 📦 **Repository Contents**

- **Scripts:**
  - `master_to_pi_ssh_setup.sh`: Sets up SSH from the master to each Raspberry Pi.
  - `pi_to_master_ssh_setup.sh`: Configures SSH keys from the Pis to the master.
  - `test_connection.sh`: Tests connectivity and communication status of all Pis in the cluster.
  - `gather_pi_configs.sh`: Retrieves and displays `~/.ssh/config` and `/etc/hosts` files from all worker Pis.

- **Configuration Files:**
  - `example.env`: Template for environment variables.
  - `example_workers.txt`: Template for worker aliases and IP addresses.

---

## ⚙️ **Setup Instructions**

### 1. **Clone the Repository:**
```bash
git clone https://github.com/yourusername/pi-cluster-ssh-manager.git
cd pi-cluster-ssh-manager
```

---

### 2. **Set Up Environment Variables:**
- Copy `example.env` to `.env` and edit with your actual values:
```bash
cp example.env .env
vim .env
```

#### Example `.env` file:
```plaintext
# Master Node Configuration
MASTER="MASTER"
MASTER_USERNAME="master_username"
MASTER_PASSWORD="master_password"
MASTER_IP="192.100.1.0"

# Worker Credentials
WORKER_USERNAME="worker_username"
WORKER_PASSWORD="worker_password"

# SSH Key
SSH_KEY="~/.ssh/id_ed25519.pub"
```

---

### 3. **Set Up Worker Aliases and IPs:**
- Copy `example_workers.txt` to `workers.txt` and edit with your actual devices:
```bash
cp example_workers.txt workers.txt
vim workers.txt
```

#### Example `workers.txt` file:
```plaintext
master-pi=192.100.1.1
core-pi=192.100.1.2
worker1=192.100.1.3
worker2=192.100.1.4
```

---

### 4. **Run the Setup and Management Scripts:**

#### **From Master to Pi:**
```bash
bash master_to_pi_ssh_setup.sh
```

#### **From Pi to Master:**
```bash
bash pi_to_master_ssh_setup.sh
```

#### **Test Connectivity:**
```bash
bash test_connection.sh
```

#### **Gather Configuration Files:**
```bash
bash gather_pi_configs.sh
```

---

## 🔒 **Important Security Tips**

- **Do Not Push Sensitive Files to Git:** Ensure `.env` and `workers.txt` are in your `.gitignore` file:
```plaintext
.env
workers.txt
pi_configs/
```

- **Configure `sudo` Without Password:** Add to `/etc/sudoers` via `sudo visudo`:
```plaintext
your_username ALL=(ALL) NOPASSWD: ALL
```

---

## 🛠 **Troubleshooting**

- **"Permission Denied" Errors:** Ensure SSH keys are properly copied and `sudo` permissions are configured correctly.
- **SSH Key Issues:** Re-run `ssh-copy-id` with the `-f` flag to force reinstallation if needed.
- **Connectivity Issues:** Use `test_connection.sh` to diagnose offline or unreachable devices.

---

## 💡 **Future Improvements**

- Add logging for actions taken on each worker device.
- Implement a dry-run mode for testing changes without applying them.
- Add automated configuration validation to detect inconsistencies in `/etc/hosts` and `~/.ssh/config` files.

---

## 🧹 **Caution:**

- Ensure all configuration files are backed up before running scripts that modify remote devices.
- Manually verify configurations with `gather_pi_configs.sh` before applying changes to production environments.

