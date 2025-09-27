#!/bin/bash
set -euo pipefail

SUDO=""
[[ $EUID -eq 0 ]] || SUDO="sudo"

VERIFY_SCRIPT="./verify_passthrough.sh"
VM_PLAYBOOK="./vm_setup.yml"  # placeholder for future VM playbook

function confirm() {
    read -p "⚠️  $1? [y/N]: " ans
    [[ $ans =~ ^[Yy] ]] || return 1
}

# ========== 1. Verify PCI passthrough ==========
if confirm "Run PCI passthrough verification"; then
    if [[ -f "$VERIFY_SCRIPT" ]]; then
        echo "Running PCI passthrough verification..."
        chmod +x "$VERIFY_SCRIPT"
        "$VERIFY_SCRIPT" || { echo "❌ PCI passthrough verification failed"; exit 1; }
        echo "✅ PCI passthrough verification complete"
    else
        echo "❌ Verification script not found: $VERIFY_SCRIPT"
    fi
fi

# ========== 2. Run VM Ansible playbook ==========
if confirm "Run VM configuration playbook"; then
    if [[ -f "$VM_PLAYBOOK" ]]; then
        echo "Running VM Ansible playbook..."
        $SUDO ansible-playbook "$VM_PLAYBOOK" || { echo "❌ VM playbook failed"; exit 1; }
        echo "✅ VM configuration applied"
    else
        echo "❌ VM playbook not found: $VM_PLAYBOOK"
    fi
fi

# Optional: additional pre-VM checks
if confirm "Perform optional pre-VM checks"; then
    echo "Checking network connectivity..."
    ping -c 3 8.8.8.8 || echo "⚠️ Network test failed; verify host networking"

    echo "Checking storage mounts..."
    df -h || echo "⚠️ Disk usage check complete"

    echo "Checking memory availability..."
    free -h || echo "⚠️ Memory check complete"
fi

echo "✅ Post-reboot verification and VM preparation complete"
