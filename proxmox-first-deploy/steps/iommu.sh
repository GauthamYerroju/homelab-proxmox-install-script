#!/bin/bash

GRUB_FILE="/etc/default/grub"

[[ $EUID -eq 0 ]] && SUDO="" || SUDO="sudo"

function enable() {
    echo "Enabling IOMMU in GRUB"

    # Detect CPU type
    if grep -q "vendor_id.*Intel" /proc/cpuinfo; then
        IOMMU_PARAM="intel_iommu=on"
    elif grep -q "vendor_id.*AMD" /proc/cpuinfo; then
        IOMMU_PARAM="amd_iommu=on"
    else
        echo "Unknown CPU vendor"
        return 1
    fi

    if ! grep -q "$IOMMU_PARAM" "$GRUB_FILE"; then
        $SUDO sed -i "/^GRUB_CMDLINE_LINUX.*=/ s/\"$/ $IOMMU_PARAM\"/" "$GRUB_FILE"
        $SUDO update-grub
    fi
}

function disable() {
    echo "Disabling IOMMU in GRUB"
    $SUDO sed -i -e 's/intel_iommu=on *//g' -e 's/amd_iommu=on *//g' \
              -e 's/  */ /g' -e 's/ *"/"/' "$GRUB_FILE"
    $SUDO update-grub
}

function query() {
    grep -q -E 'intel_iommu=on|amd_iommu=on' "$GRUB_FILE"
}
