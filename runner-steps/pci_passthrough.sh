#!/bin/bash

# ================== Instructions ==============================
# 1. Set defaults / parameters (e.g., swappiness value, PCI IDs).
# 2. Define enable() - implement step logic, accept parameters.
# 3. Define disable() - implement undo logic.
# 4. Define query() - return 0 if enabled, 1 if disabled.
# 5. Ensure idempotency - repeated calls should not break system.
# 6. Python runner calls: "source script; enable/disable/query".
# 7. Keep consistent function names across all step scripts.
#===============================================================

# ================== Configuration / Defaults ==================
VFIO_BIND_SCRIPT="/usr/local/bin/vfio-bind-devices.sh"
PCI_IDS_FILE="/etc/vfio-pci-ids.conf"
DEFAULT_PCI_FILTER="SAS2308|ConnectX-3"

# ================== Functions ==================
function enable() {
    local pci_filter="${1:-$DEFAULT_PCI_FILTER}"
    echo "Enabling VFIO PCI passthrough with filter: $pci_filter"
    
    # Return early if already enabled to maintain idempotency
    if [[ -f "$VFIO_BIND_SCRIPT" ]] && [[ -f "$PCI_IDS_FILE" ]]; then
        echo "VFIO binding already enabled"
        return 0
    fi
    
    echo "Detecting PCI devices for passthrough..."
    mapfile -t DETECTED < <(lspci -D | grep -E "$pci_filter")
    
    if [[ ${#DETECTED[@]} -eq 0 ]]; then
        echo "No supported PCI devices detected with filter: $pci_filter"
        return 0
    fi

    echo "Detected devices:"
    for i in "${!DETECTED[@]}"; do
        echo "$((i+1))) ${DETECTED[i]}"
    done

    echo "Enter comma-separated indices to enable (e.g., 1,3), or press Enter to select all:"
    read -r selection
    [[ -z "$selection" ]] && selection=$(seq -s, 1 ${#DETECTED[@]})

    IDS=()
    for idx in ${selection//,/ }; do
        if [[ "$idx" =~ ^[0-9]+$ ]] && [[ "$idx" -ge 1 ]] && [[ "$idx" -le ${#DETECTED[@]} ]]; then
            # Extract PCI address and convert to sysfs format
            pci_addr="${DETECTED[$((idx-1))]%% *}"
            IDS+=("$pci_addr")
        fi
    done

    if [[ ${#IDS[@]} -eq 0 ]]; then
        echo "No devices selected"
        return 0
    fi

    echo "Selected PCI IDs: ${IDS[@]}"
    mkdir -p "$(dirname "$PCI_IDS_FILE")"
    printf "%s\n" "${IDS[@]}" > "$PCI_IDS_FILE"

    echo "Creating VFIO bind script..."
    cat > "$VFIO_BIND_SCRIPT" <<'EOF'
#!/bin/bash

set -e

while IFS= read -r DEVICE; do
    [[ -z "$DEVICE" ]] && continue
    
    echo "Processing device: $DEVICE"
    
    SYSFS_PATH="/sys/bus/pci/devices/$DEVICE"
    
    # Check if device exists
    if [[ ! -d "$SYSFS_PATH" ]]; then
        echo "Error: Device $DEVICE not found in sysfs"
        continue
    fi
    
    # Read vendor and device IDs
    if [[ ! -r "$SYSFS_PATH/vendor" ]] || [[ ! -r "$SYSFS_PATH/device" ]]; then
        echo "Error: Cannot read vendor/device ID for $DEVICE"
        continue
    fi
    
    VENDOR_ID=$(cat "$SYSFS_PATH/vendor")
    DEVICE_ID=$(cat "$SYSFS_PATH/device")
    
    echo "Device $DEVICE: Vendor=$VENDOR_ID, Device=$DEVICE_ID"
    
    # Skip if already bound to vfio-pci
    if [[ -L "$SYSFS_PATH/driver" ]]; then
        CURRENT_DRIVER=$(readlink "$SYSFS_PATH/driver" | xargs basename)
        if [[ "$CURRENT_DRIVER" == "vfio-pci" ]]; then
            echo "Device $DEVICE already bound to vfio-pci"
            continue
        fi
        
        echo "Unbinding $DEVICE from $CURRENT_DRIVER"
        if ! echo "$DEVICE" > "$SYSFS_PATH/driver/unbind" 2>/dev/null; then
            echo "Warning: Failed to unbind $DEVICE from $CURRENT_DRIVER"
        else
            # Wait for unbind to complete
            sleep 0.5
        fi
    fi
    
    # Check if vfio-pci driver exists
    if [[ ! -d "/sys/bus/pci/drivers/vfio-pci" ]]; then
        echo "Error: vfio-pci driver not available. Is the module loaded?"
        exit 1
    fi
    
    # Add device ID to vfio-pci driver (idempotent)
    echo "Adding device ID $VENDOR_ID $DEVICE_ID to vfio-pci"
    if ! echo "$VENDOR_ID $DEVICE_ID" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null; then
        # Device ID might already be known to the driver, which is fine
        echo "Note: Device ID already known to vfio-pci driver"
    fi
    
    # Bind to vfio-pci
    echo "Binding $DEVICE to vfio-pci"
    if echo "$DEVICE" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null; then
        echo "Successfully bound $DEVICE to vfio-pci"
    else
        echo "Error: Failed to bind $DEVICE to vfio-pci"
    fi
    
    echo "---"
    
done < /etc/vfio-pci-ids.conf

echo "VFIO binding complete"
EOF

    chmod +x "$VFIO_BIND_SCRIPT"
    echo "VFIO bind script created at $VFIO_BIND_SCRIPT"
}

function disable() {
    echo "Disabling VFIO PCI passthrough"
    
    # Unbind devices from vfio-pci if possible
    if [[ -f "$PCI_IDS_FILE" ]]; then
        echo "Attempting to unbind devices from vfio-pci..."
        while IFS= read -r DEVICE; do
            [[ -z "$DEVICE" ]] && continue
            
            SYSFS_PATH="/sys/bus/pci/devices/$DEVICE"
            if [[ -L "$SYSFS_PATH/driver" ]]; then
                CURRENT_DRIVER=$(readlink "$SYSFS_PATH/driver" 2>/dev/null | xargs basename)
                if [[ "$CURRENT_DRIVER" == "vfio-pci" ]]; then
                    echo "Unbinding $DEVICE from vfio-pci"
                    echo "$DEVICE" > "$SYSFS_PATH/driver/unbind" 2>/dev/null || true
                fi
            fi
        done < "$PCI_IDS_FILE"
    fi
    
    # Remove files
    rm -f "$VFIO_BIND_SCRIPT"
    rm -f "$PCI_IDS_FILE"
    echo "VFIO configuration files removed"
}

function query() {
    [[ -f "$VFIO_BIND_SCRIPT" ]] && [[ -f "$PCI_IDS_FILE" ]]
}

function info() {
    # Return 0 if enabled, 1 if disabled
    if [[ -f "$VFIO_BIND_SCRIPT" ]] && [[ -f "$PCI_IDS_FILE" ]]; then
        # Additional check: verify at least one device is actually bound to vfio-pci
        local bound_count=0
        while IFS= read -r DEVICE; do
            [[ -z "$DEVICE" ]] && continue
            
            SYSFS_PATH="/sys/bus/pci/devices/$DEVICE"
            if [[ -L "$SYSFS_PATH/driver" ]]; then
                CURRENT_DRIVER=$(readlink "$SYSFS_PATH/driver" 2>/dev/null | xargs basename)
                if [[ "$CURRENT_DRIVER" == "vfio-pci" ]]; then
                    ((bound_count++))
                fi
            fi
        done < "$PCI_IDS_FILE" 2>/dev/null
        
        if [[ $bound_count -gt 0 ]]; then
            echo "At least 1 device from $PCI_IDS_FILE is bound to the vfio-pci driver."
        else
            echo "No devices from $PCI_IDS_FILE are bound the vfio-pci driver."
        fi
    fi
}