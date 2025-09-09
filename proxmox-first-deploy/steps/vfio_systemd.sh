#!/bin/bash

SYSTEMD_UNIT_FILE="/etc/systemd/system/vfio-bind.service"
VFIO_BIND_SCRIPT="/usr/local/bin/vfio-bind-devices.sh"
[[ $EUID -eq 0 ]] && SUDO="" || SUDO="sudo"

function enable() {
    if [[ ! -f "$VFIO_BIND_SCRIPT" ]]; then
        echo "VFIO bind script not found at $VFIO_BIND_SCRIPT. Please run pci_passthrough step first."
        return 1
    fi

    echo "Creating systemd service to run VFIO bind script at boot..."
    cat | $SUDO tee "$SYSTEMD_UNIT_FILE" > /dev/null <<EOF
[Unit]
Description=Bind PCI devices to VFIO
After=local-fs.target
Before=pve-guests.service

[Service]
Type=oneshot
ExecStart=$VFIO_BIND_SCRIPT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    echo "Enabling systemd service..."
    $SUDO systemctl daemon-reload
    $SUDO systemctl enable vfio-bind.service
    echo "vfio-bind.service enabled."
}

function disable() {
    echo "Disabling vfio-bind.service..."
    if [[ -f "$SYSTEMD_UNIT_FILE" ]]; then
        $SUDO systemctl disable vfio-bind.service
        $SUDO rm -f "$SYSTEMD_UNIT_FILE"
        $SUDO systemctl daemon-reload
        echo "vfio-bind.service removed."
    else
        echo "Service file not found; nothing to disable."
    fi
}

function query() {
    $SUDO systemctl is-enabled vfio-bind.service &>/dev/null
}
