#!/bin/bash

SWAPPINESS_FILE="/etc/sysctl.d/99-swappiness.conf"
[[ $EUID -eq 0 ]] && SUDO="" || SUDO="sudo"

function enable() {
    read -p "⚠️ Enter swappiness value [10]: " val
    val=${val:-10}
    if ! [[ "$val" =~ ^[0-9]+$ ]] || [ "$val" -lt 0 ] || [ "$val" -gt 100 ]; then
        echo "Invalid value, using default 10"
        val=10
    fi
    echo "Setting vm.swappiness=$val"
    $SUDO touch "$SWAPPINESS_FILE" || return 1
    if grep -q '^vm.swappiness=' "$SWAPPINESS_FILE"; then
        $SUDO sed -i "s/^vm.swappiness=.*/vm.swappiness=$val/" "$SWAPPINESS_FILE" || return 1
    else
        echo "vm.swappiness=$val" | $SUDO tee -a "$SWAPPINESS_FILE" > /dev/null || return 1
    fi
    $SUDO sysctl --system || return 1
}

function disable() {
    echo "Removing vm.swappiness setting..."
    $SUDO sed -i '/^vm\.swappiness=/d' "$SWAPPINESS_FILE" || return 1
    $SUDO sysctl --system || return 1
}

function query() {
    grep -q '^vm.swappiness=' "$SWAPPINESS_FILE"
}