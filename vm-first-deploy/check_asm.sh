#!/bin/bash

echo "=== Checking ASM1166 PCIe SATA Controller Passthrough ==="

echo
echo "[1] Checking for ASM1166 in lspci:"
asm=$(lspci | grep -i 'ASM1166')
if [[ -z "$asm" ]]; then
    echo "❌ ASM1166 not detected in lspci. Passthrough likely failed."
    exit 1
else
    echo "✅ Found:"
    echo "$asm"
fi

slot=$(echo "$asm" | awk '{print $1}')

echo
echo "[2] Checking kernel driver for ASM1166 (slot: $slot):"
driver=$(lspci -k -s "$slot" | grep "Kernel driver in use" | awk -F: '{print $2}' | xargs)
if [[ "$driver" == "ahci" ]]; then
    echo "✅ Correct driver bound: $driver"
else
    echo "❌ Incorrect or no driver bound. Got: ${driver:-<none>}"
fi

echo
echo "[3] Listing attached block devices:"
lsblk -dpno NAME,MODEL,SIZE | grep '/dev/sd' || echo "❌ No block devices found on /dev/sd*"

echo
echo "[4] Relevant dmesg logs (AHCI, SATA, ASM):"
dmesg | grep -iE 'ahci|asm|sata|ata|error|fail'

echo
echo "=== Done ==="
