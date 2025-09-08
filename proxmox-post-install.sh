#!/bin/bash 
set -e

SUDO=""

SWAPPINESS=null
PROXMOX_POST_INSTALL=null
DOCKER_VM=null
ANY_PASSTHROUGH=null
NIC_PASSTHROUGH=null
HBA_PASSTHROUGH=null

OPTIONS=(
  "Set swappiness to 10:SWAPPINESS"
  "Install ProxmoxVE post-install script:PROXMOX_POST_INSTALL"
  "Install Docker VM:DOCKER_VM"
  "Passthrough NIC (Mellanox ConnectX-3 Pro):NIC_PASSTHROUGH:DOCKER_VM"
  "Passthrough HBA (LSI SAS2308):HBA_PASSTHROUGH:DOCKER_VM"
)

PASSTHROUGH_PAIRS=(
  'NIC_PASSTHROUGH:ConnectX-3 Pro'
  'HBA_PASSTHROUGH:LSI SAS2308'
)

#==============================================================================

function set_sudo_prefix() {
  [[ $EUID -eq 0 ]] && SUDO="" || SUDO="sudo"
}

function collect_choices() {
  local OLD_IFS=$IFS
  IFS=":"
  local pair prompt var skip answer
  for pair in "${OPTIONS[@]}"; do
    read -r prompt var skip <<< "$pair"

    [[ -n $skip && ${!skip} == 'n' ]] && continue

    read -p "$prompt? y/[n]: " answer
    [[ $answer =~ ^[Yy](es)?$ ]] && declare -g "$var=y" || declare -g "$var=n"
  done
  IFS=$OLD_IFS
}

function show_choices() {
  local OLD_IFS=$IFS
  IFS=":"
  local pair prompt var skip
  for pair in "${OPTIONS[@]}"; do
      read -r prompt var skip <<< "$pair"
      [[ -n $skip && ${!skip} == 'n' ]] && continue
      echo "- $1$prompt: ${!var}"
  done
  IFS=$OLD_IFS
}

function get_swappiness() {
  echo $(cat /proc/sys/vm/swappiness)
}

function set_swappiness() {
  local VALUE=$1
  # local FILE=/etc/sysctl.d/99-swappiness.conf
  local FILE=./test.conf
  touch $FILE

  if grep -q '^vm.swappiness=' "$FILE"; then
    $SUDO sed -i "s/^vm.swappiness=.*/vm.swappiness=$VALUE/" "$FILE"
  else
    echo "vm.swappiness=$VALUE" | $SUDO tee -a "$FILE"
  fi
  $SUDO sysctl --system
}

function run_proxmox_post_install_script() {
  # https://community-scripts.github.io/ProxmoxVE/scripts?id=post-pve-install
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh)"
}

function install_docker_vm() {
  # https://community-scripts.github.io/ProxmoxVE/scripts?id=docker-vm
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/vm/docker-vm.sh)"
}

function add_pcie_ids_to_array() {
  local -n pcie_ids=$1
  local OLD_IFS=$IFS
  IFS=":"
  local pair var pcie_name
  for pair in "${PASSTHROUGH_PAIRS[@]}"; do
    read -r var pcie_name <<< "$pair"
    if [[ ${!var} == 'y' ]]; then
      local pcie_id=$(lspci -D | grep "$pcie_name" | cut -d ' ' -f1)
      [[ -n $pcie_id ]] && pcie_ids+=("$pcie_id")
    fi
  done
  IFS=$OLD_IFS
}

function pcie_passthrough_pre_setup() {
  # Enable Intel IOMMU in GRUB (only add if not present)
  if ! grep -q 'intel_iommu=on' /etc/default/grub; then
    echo "Setting iommu flag in grub..."
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 intel_iommu=on"/' /etc/default/grub
    update-grub
  fi

  # Add VFIO modules to load at boot
  local mod
  for mod in vfio vfio_iommu_type1 vfio_pci vfio_virqfd; do
    if ! grep -q "^$mod$" /etc/modules; then
      echo "Adding \"$mod\" to /etc/modules..."
      echo "$mod" >> /etc/modules
    fi
  done
}

function create_passthrough_devices_bind_script() {
# Create VFIO bind script
cat >/usr/local/bin/vfio-bind-devices.sh <<'EOF'
#!/bin/bash

# TODO Source from file
DEVICES=()
source ./

for DEVICE in "${DEVICES[@]}"; do
  echo "Waiting for PCI device $DEVICE to appear in /sys/bus/pci/devices/..."
  timeout=10
  elapsed=0
  while [ ! -e "/sys/bus/pci/devices/$DEVICE" ] && [ $elapsed -lt $timeout ]; do
    sleep 1
    elapsed=$((elapsed + 1))
  done
  if [ $elapsed -ge $timeout ]; then
    echo "ERROR: Device $DEVICE not found after $timeout seconds, skipping..."
    continue
  fi

  echo "Device $DEVICE found. Processing..."

  VENDOR_ID=$(cat /sys/bus/pci/devices/$DEVICE/vendor)
  DEVICE_ID=$(cat /sys/bus/pci/devices/$DEVICE/device)

  # Unbind current driver if bound
  if [ -L /sys/bus/pci/devices/$DEVICE/driver ]; then
    echo "Unbinding \"$DEVICE\" from current driver..."
    echo "$DEVICE" > /sys/bus/pci/devices/$DEVICE/driver/unbind
  fi

  # Check if device is already bound to vfio-pci
  if [ "$(basename $(readlink /sys/bus/pci/devices/$DEVICE/driver))" == "vfio-pci" ]; then
    echo "\"$DEVICE\" is already bound to vfio-pci."
    continue
  fi

  echo "Registering vfio-pci to claim \"$VENDOR_ID\" \"$DEVICE_ID\"..."
  if ! echo "$VENDOR_ID" "$DEVICE_ID" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null; then
    echo "vfio-pci already registered or error (ignoring)."
  fi

  echo "Binding \"$DEVICE\" to vfio-pci..."
  if ! echo "$DEVICE" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null; then
    echo "Failed to bind $DEVICE. It may be busy or already bound."
  fi
done
EOF
chmod +x /usr/local/bin/vfio-bind-devices.sh
}

function create_passthrough_systemd_service() {
# Create systemd service to run bind script at boot
cat >/etc/systemd/system/vfio-bind.service <<'EOF'
[Unit]
Description=Bind PCI devices to VFIO
After=local-fs.target
Before=pve-guests.service
[Service]
Type=oneshot
ExecStart=/usr/local/bin/vfio-bind-devices.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF

# Enable the systemd service
echo "Enabling vfio-bind.service..."
systemctl enable vfio-bind.service
}

#==============================================================================

function main() {
  set_sudo_prefix()

  printf "===== Proxmox post-install setup =====\n\n"

  collect_choices
  printf "\nStarting installation with the following options:\n"
  show_choices
  local answer
  read -p "Proceed? y/[n]: " answer
  [[ ! $answer =~ ^[Yy](es)?$ ]] && exit

  [[ $SWAPPINESS == y ]] && set_swappiness 10
  [[ $PROXMOX_POST_INSTALL == y ]] && run_proxmox_post_install_script
  [[ $DOCKER_VM == y ]] && install_docker_vm

  [[ $NIC_PASSTHROUGH == 'y' || $HBA_PASSTHROUGH == 'y' ]] && ANY_PASSTHROUGH=y

  if [[ -n $ANY_PASSTHROUGH ]]; then
    passthrough_devices=()
    add_pcie_ids_to_array passthrough_devices

    file_bind_script=/usr/local/bin/vfio-bind-devices.sh
    file_bind_list=/usr/local/bin/vfio-bind-devices-list.sh
    file_bind_service=/etc/systemd/system/vfio-bind.service

    pcie_passthrough_pre_setup
    create_passthrough_devices_bind_script $file_bind_script
    create_passthrough_systemd_service $file_bind_service
  fi
  
  echo "Setup complete. Reboot to apply changes."
  exit 0
}

main()