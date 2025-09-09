#!/bin/bash
MODULES=(vfio vfio_iommu_type1 vfio_pci) # vfio_virqfd
MODULE_FILE="/etc/modules"
[[ $EUID -eq 0 ]] && SUDO="" || SUDO="sudo"

function enable() {
    echo "Loading VFIO kernel modules"
    for mod in "${MODULES[@]}"; do
        if ! grep -q "^$mod$" "$MODULE_FILE"; then
            if echo "$mod" | $SUDO tee -a "$MODULE_FILE" > /dev/null; then
                echo "Added $mod to $MODULE_FILE"
            else
                echo "Failed to add $mod to $MODULE_FILE"
                return 1
            fi
        else
            echo "$mod already configured"
        fi
    done
}

function disable() {
    echo "Removing VFIO kernel modules"
    for mod in "${MODULES[@]}"; do
        if $SUDO sed -i "/^$mod$/d" "$MODULE_FILE"; then
            echo "Removed $mod from $MODULE_FILE"
        else
            echo "Failed to remove $mod from $MODULE_FILE"
            return 1
        fi
    done
}

function query() {
    for mod in "${MODULES[@]}"; do
        grep -q "^$mod$" "$MODULE_FILE" || return 1
    done
    return 0
}