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
