#!/bin/bash
set -e

echo "Set swappiness to 10 on confirmation"
read -p "Set vm.swappiness=10 permanently? (y/n) " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
  current=$(cat /proc/sys/vm/swappiness)
  if [ "$current" -eq 10 ]; then
    echo "Swappiness is already set to 10. No changes made."
  fi

  SUDO=''
  if [ "$EUID" -ne 0 ]; then
    SUDO='sudo'
  fi

  echo 'vm.swappiness=10' | $SUDO tee /etc/sysctl.d/99-swappiness.conf
  $SUDO sysctl --system
  echo "Swappiness set to 10."
else
  echo "No changes made."
fi

echo "Updating package lists..."
sudo apt update

echo "Installing DE and utilities..."
sudo apt install -y cinnamon-core gedit gnome-system-monitor file-roller gnome-disk-utility openssh-server hdparm smartmontools

echo "Cleaning up unused packages..."
sudo apt autoremove --purge -y

echo "Setup complete."



echo "=== Disabling unwanted systemd services ==="

# Services to disable unconditionally
services=(
  blueman-mechanism.service
  power-profiles-daemon.service
  wpa_supplicant.service
  ModemManager.service
  speech-dispatcher.service
)

for svc in "${services[@]}"; do
  if systemctl is-enabled "$svc" &>/dev/null; then
    sudo systemctl disable --now "$svc"
    echo "Disabled $svc"
  else
    echo "$svc not enabled or already disabled"
  fi
done

# Conditionally disable systemd-network* if NetworkManager active
if systemctl is-active --quiet NetworkManager.service; then
  networkd_services=(
    systemd-networkd.service
    systemd-networkd-wait-online.service
    systemd-network-generator.service
    systemd-networkd.socket
  )
  for svc in "${networkd_services[@]}"; do
    if systemctl is-enabled "$svc" &>/dev/null; then
      sudo systemctl disable --now "$svc"
      echo "Disabled $svc because NetworkManager is active"
    else
      echo "$svc not enabled or already disabled"
    fi
  done
else
  echo "NetworkManager is not active; skipping disabling systemd-network* services"
fi

echo "=== Disabling unwanted autostart entries system-wide ==="

autostart_files=(
  blueman.desktop
  org.gnome.SettingsDaemon.Power.desktop
  cinnamon-settings-daemon-power.desktop
  org.gnome.SettingsDaemon.Rfkill.desktop
  org.gnome.SettingsDaemon.Wwan.desktop
  org.gnome.SettingsDaemon.PrintNotifications.desktop
  cinnamon-settings-daemon-print-notifications.desktop
  org.gnome.SettingsDaemon.Smartcard.desktop
  cinnamon-settings-daemon-smartcard.desktop
  org.gnome.SettingsDaemon.Wacom.desktop
  cinnamon-settings-daemon-wacom.desktop
  pulseaudio.desktop
  xapp-sn-watcher.desktop
  xdg-user-dirs-kde.desktop
  at-spi-dbus-bus.desktop
  gnome-keyring-pkcs11.desktop
)

for file in "${autostart_files[@]}"; do
  path="/etc/xdg/autostart/$file"
  if [ -f "$path" ]; then
    if ! grep -q '^Hidden=true' "$path"; then
      echo 'Hidden=true' | sudo tee -a "$path" > /dev/null
      echo "Disabled $file system-wide"
    else
      echo "$file already disabled"
    fi
  else
    echo "File $file not found, skipping"
  fi
done

echo "=== Disabling Cinnamon compositing for better remote performance ==="
if command -v gsettings &>/dev/null; then
  gsettings set org.cinnamon.muffin compositing-manager false || echo "Warning: Could not disable compositing (key may not exist)"
else
  echo "gsettings not found, skipping compositing disable"
fi

echo "=== VM optimization complete ==="
