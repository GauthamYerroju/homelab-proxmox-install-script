#!/bin/bash

echo "=== Disk Mount Setup Tool ==="
echo

BYID_PATH="/dev/disk/by-id"
declare -a fstab_entries=()

ls -l "$BYID_PATH" | grep -E 'ata|nvme' | awk '{print $9}' | sort | while read -r id; do
    real_path=$(readlink -f "$BYID_PATH/$id")
    # Skip partitions (e.g. /dev/sda1)
    if [[ "$real_path" =~ [0-9]+$ ]]; then
        continue
    fi

    echo "--------------------------------------------"
    echo "Disk ID:      $id"
    echo "Device path:  $real_path"

    fstype=$(blkid -s TYPE -o value "$real_path" 2>/dev/null || echo "none")
    echo "Filesystem:   $fstype"

    uuid=$(blkid -s UUID -o value "$real_path" 2>/dev/null || echo "")
    echo "UUID:         ${uuid:-<none>}"

    capacity_bytes=$(lsblk -b -dn -o SIZE "$real_path")
    capacity_gb=$((capacity_bytes / 1024 / 1024 / 1024))
    echo "Capacity:     ${capacity_gb} GB"

    devname=$(basename "$real_path")
    model=$(cat /sys/block/$devname/device/model 2>/dev/null | tr -d ' ' || echo "unknownmodel")
    echo "Model:        $model"

    read -rp "Use this disk? [y/N] " use_disk
    [[ "$use_disk" != "y" ]] && echo "Skipping $id" && continue

    if [[ -z "$uuid" ]]; then
        echo "Warning: No filesystem detected on $real_path."
        echo "Please format this disk manually before adding to fstab."
        echo "Skipping $id."
        continue
    fi

    mount_point="/mnt/hdd/${uuid}-${capacity_gb}GB-${model}"
    echo "Mount point will be: $mount_point"
    mkdir -p "$mount_point"

    fstab_entries+=("UUID=$uuid $mount_point $fstype noatime 0 2")
    echo
done

echo "============================================"
echo "=== Suggested /etc/fstab entries to add ==="
echo
printf "%s\n" "${fstab_entries[@]}"
