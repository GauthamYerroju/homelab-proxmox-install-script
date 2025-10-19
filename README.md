# Homelab Proxmox Post-Install Script

Automation scripts for configuring **Proxmox VE** in a homelab environment.

## Files & Purpose

- `create-installer.sh`  
  Builds a customized script to do some post-installation setup and maintenance.

- `runner.py`  
  Orchestrates execution flow based on the STEPS dict (self-explanatory).

## Usage

Run scripts manually:

```bash
bash create-installer.sh
bash proxmox-post-install.sh
```

Or use Python runner:

```bash
python3 runner.py
```

## Requirements

* Linux host
* Bash
* Python 3

## TODO
- Expand pcie-passthrough implementation for per-device blacklist option.
- Fix bug with blacklist conf file containing vfio driver when playbook is run successively.
- For nvme drive, use qm command:
  - `qm set 100 -hostpci0 01:00,pcie=1`
- Add command to passthrough SATA drives (nvme drives are passed through pci-passthrough).
  - Set serial of passed through sata drive for easy identification (serial=).
  `qm set 100 -scsi1 /dev/disk/by-id/ata-INTEL_SSDSC2BB480G7_PHDV652506A3480BGN,ssd=1,serial=INTEL_SSDSC2BB480G7,aio=io_uring,cache=none,discard=on,size=468851544K`
