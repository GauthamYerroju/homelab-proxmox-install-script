#!/bin/bash

function enable() {
    echo "Installing Docker VM"
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/vm/docker-vm.sh)"
}

function disable() {
    echo "No automatic revert for Docker VM. Manual cleanup may be required."
}

function query() {
    # Could check if VM exists; simplified as always 0
    return 1
}
