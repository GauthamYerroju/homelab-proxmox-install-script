#!/bin/bash
set -euo pipefail

VMID=100
VM_NAME="nas-vm"
INVENTORY_FILE="$HOME/nas-vm-inventory.ini"
SSH_KEY_NAME="id_ed25519_ansible_vm_control"
SSH_KEY="$HOME/.ssh/$SSH_KEY_NAME"
VM_IP_TIMEOUT=60

POST_INSTALL_SCRIPT="./pve-post-install.sh"
DOCKER_VM_SCRIPT="./install-docker-vm.sh"
HOST_PLAYBOOK="./setup-host.yml"
VM_PLAYBOOK="./setup-vm.yml"
PASSTHROUGH_PLAYBOOK="./passthrough.yml"

source ./utils.sh

# ========== 1. Install prerequisites ==========
if confirm "Install prerequisites (git, ansible-core, etc.)"; then
    echo "Installing prerequisites..."
    $SUDO apt update
    $SUDO apt install -y git jq pipx
    pipx ensurepath
    for pkg in ansible-core; do
        pipx install "$pkg"
    done
    source /root/.bashrc
    for collection in ansible.posix community.crypto; do
        ansible-galaxy collection install  "$collection"
    done
    echo "✅ Prerequisites installed (ansible version: $(ansible --version | head -n1))"
fi

# ========== 2. Generate host SSH key ==========
if [[ ! -f "$SSH_KEY" ]]; then
    echo "Generating host SSH key..."
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N ""
    echo "✅ SSH key generated at $SSH_KEY"
else
    echo "✅ Host SSH key already exists at $SSH_KEY"
fi

# ========== 3. Run Proxmox post-install script ==========
if confirm "Run Proxmox post-install script"; then
    if [[ -f "$POST_INSTALL_SCRIPT" ]]; then
        echo "Running local Proxmox post-install script..."
        $SUDO bash "$POST_INSTALL_SCRIPT" || { echo "❌ Post-install script failed"; exit 1; }
        echo "✅ Proxmox post-install complete"
    else
        echo "❌ Post-install script not found: $POST_INSTALL_SCRIPT"
    fi
fi

# ========== 4. Run host setup ansible playbook ==========
if confirm "Run host setup ansible playbook"; then
    if [[ -f "$HOST_PLAYBOOK" ]]; then
        echo "Running host configuration playbook..."
        $SUDO ansible-playbook "$HOST_PLAYBOOK" -e "ssh_key_name=$SSH_KEY_NAME" || { echo "❌ Host playbook failed"; exit 1; }
        echo "✅ Host configuration applied"
    else
        echo "❌ Playbook not found: $HOST_PLAYBOOK"
    fi
fi

# ========== 5. Create Docker VM ==========
vm_created=
if confirm "Create Docker VM (ID $VMID)"; then

    if [[ -f "$DOCKER_VM_SCRIPT" ]]; then
        echo "Running local Docker VM creation script..."
        $SUDO bash "$DOCKER_VM_SCRIPT" || { echo "❌ Docker VM script failed"; exit 1; }
        vm_created=1
        echo "✅ Docker VM (ID $VMID) creation complete"
    else
        echo "❌ Docker VM script not found: $DOCKER_VM_SCRIPT"
    fi
fi

# ========== 6. Wait for VM IP ==========
vm_ip=""
if confirm "Fetch VM IP via guest agent"; then
    echo "Waiting for guest agent..."
    elapsed=0
    while [[ -z "$vm_ip" && $elapsed -lt $VM_IP_TIMEOUT ]]; do
        vm_ip=$(qm guest cmd $VMID network-get-interfaces 2>/dev/null | jq -r '
            .[]?
            | select(.name | test("docker") | not)
            | ."ip-addresses"[]?
            | select(.["ip-address"] != "127.0.0.1")
            | select(."ip-address-type"=="ipv4")
            | ."ip-address"
        ' | head -n1)
        [[ -n "$vm_ip" ]] && break
        sleep 2
        elapsed=$((elapsed + 2))
    done

    if [[ -z "$vm_ip" ]]; then
        echo "❌ Failed to detect VM IP. Please update inventory manually."
    else
        echo "✅ VM IP detected: $vm_ip"
    fi
else
    if confirm "Enter VM IP manually?"; then
        read -p "Enter VM IP: " vm_ip
    fi
fi

# ========== 7. Copy SSH key to VM ==========
if [[ -n "$vm_ip" ]]; then
    if confirm "Copy host SSH key to VM ($vm_ip)"; then
        ssh-copy-id -i "$SSH_KEY" root@"$vm_ip" || echo "❌ Failed to copy SSH key; ensure VM is reachable and root login allowed."
        echo "✅ SSH key copied to VM."
    fi
fi

# ========== 8. Generate VM inventory file ==========
if confirm "Generate Ansible inventory"; then
    echo "Generating Ansible inventory file at $INVENTORY_FILE..."
    cat > "$INVENTORY_FILE" <<EOF
[$VM_NAME]
$VM_NAME ansible_host=${vm_ip} ansible_user=root ansible_ssh_private_key_file=$SSH_KEY
EOF
    echo "✅ Inventory generated at $INVENTORY_FILE"
fi

# ========== 9. Run VM Ansible playbook ==========
if confirm "Run VM configuration playbook"; then
    if [[ -f "$VM_PLAYBOOK" ]]; then
        echo "Running VM Ansible playbook..."
        $SUDO ansible-playbook -i "$INVENTORY_FILE" "$VM_PLAYBOOK" || { echo "❌ VM playbook failed"; exit 1; }
        echo "✅ VM configuration applied"
    else
        echo "❌ VM playbook not found: $VM_PLAYBOOK"
    fi
fi

# ================================================
if [[ -n "$vm_ip" ]]; then
    if confirm "Passthrough SATA SSD with PLP (for configs)?"; then
        qm set $VMID -scsi1 /dev/disk/by-id/ata-INTEL_SSDSC2BB480G7_PHDV652506A3480BGN,ssd=1,serial=INTEL_SSDSC2BB480G7,aio=io_uring,cache=none,discard=on,size=468851544K
    fi
    # TODO: Figure out PCI IDs by name
    if confirm "Passthrough nvme (for tiered cache)?"; then
        qm set $VMID -hostpci0 02:00,pcie=1
    fi
    if confirm "Passthrough LSI SAS2308 (controller for all data disks)?"; then
        qm set $VMID -hostpci1 01:00,pcie=1
    fi
fi

# ========== 10. Reboot VM ==========
if confirm "Reboot VM? (Recommended)"; then
    qm shutdown $VMID && sleep 10 && qm start $VMID
fi

# ========== 11. Reboot host ==========
if confirm "Reboot host? (Recommended)"; then
    echo "Rebooting..."
    $SUDO reboot
else
    echo "⚠️ Remember to reboot later before proceeding to VM configuration and verification."
fi
