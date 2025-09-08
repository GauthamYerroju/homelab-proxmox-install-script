#!/bin/bash

function enable() {
    echo "Running Proxmox post-install script"
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh)"
}

function disable() {
    echo "No automatic revert for Proxmox post-install. Manual cleanup may be required."
}

function query() {
    # Could check for a specific marker file or package; simplified as always 0
    return 1
}
