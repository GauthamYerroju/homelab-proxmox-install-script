#!/bin/bash
set -euo pipefail

VMID=200
VM_NAME="deploy-test-1"
INVENTORY_FILE="$HOME/docker-vm-inventory.ini"
SSH_KEY="$HOME/.ssh/id_ed25519"
VM_IP_TIMEOUT=60

SUDO=""
[[ $EUID -eq 0 ]] || SUDO="sudo"

function confirm() {
    read -p "⚠️  $1? [y/N]: " ans
    [[ $ans =~ ^[Yy] ]] || return 1
}

# ========== Prep ==========
echo "Updating APT and installing prerequisites..."
$SUDO apt update
$SUDO apt install -y curl git ansible-core
echo "✅ Prerequisites and Ansible (version: $(ansible --version | head -n1) installed."

# ========== Proxmox post-install ==========
if confirm "Run Proxmox post-install script"; then
    echo "Running Proxmox post-install..."
    $SUDO bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh)"
    echo "✅ Proxmox post-install script complete."
fi

# ========== Docker VM installation ==========
if confirm "Create Docker VM (ID $VMID)"; then
    echo "Creating Docker VM..."
    $SUDO bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/vm/docker-vm.sh)" || true
    echo "✅ Created Docker VM (ID $VMID)."
fi

# ========== Wait for VM IP ==========
vm_ip=""
if confirm_step "Fetch VM IP via guest agent"; then
    echo "Waiting for guest agent..."
    elapsed=0
    while [[ -z "$vm_ip" && $elapsed -lt $VM_IP_TIMEOUT ]]; do
        vm_ip=$(qm guest exec $VM_ID ip a 2>/dev/null | awk '/inet / && !/127.0.0.1/ {print $2}' | cut -d/ -f1 | head -n1 || true)
        [[ -n "$vm_ip" ]] && break
        sleep 2
        elapsed=$((elapsed + 2))
    done

    if [[ -z "$vm_ip" ]]; then
        echo "❌ Failed to detect VM IP. Please update inventory manually."
    else
        echo "✅ VM IP detected: $vm_ip"
    fi
fi

# ========== Generate VM inventory file ==========
if confirm_step "Generate Ansible inventory"; then
    echo "Generating Ansible inventory file at $INVENTORY_FILE..."
    cat > "$INVENTORY_FILE" <<EOF
[$VM_NAME]
$VM_NAME ansible_host=${vm_ip:-192.168.100.100} ansible_user=root ansible_ssh_private_key_file=$SSH_KEY
EOF
    echo "✅ Inventory generated at $INVENTORY_FILE"
fi

# ========== SSH key for host ==========
if confirm "Generate SSH key for host"; then
    if [[ ! -f "$SSH_KEY" ]]; then
        ssh-keygen -t ed25519 -f "$SSH_KEY" -N ""
        echo "SSH key generated at $SSH_KEY"
    fi

    if [[ -n "$vm_ip" ]]; then
        echo "Copying SSH key to VM..."
        ssh-copy-id -i "$SSH_KEY" root@$vm_ip || echo "❌ Failed to copy SSH key; ensure VM is reachable and root login allowed."
    fi

    echo "✅ SSH key generated."
fi

echo "✅ Proxmox host bootstrap complete. Reboot."

# ========== Reboot prompt ==========
if confirm "Reboot"; then
    $SUDO reboot
fi
