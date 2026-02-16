# Proxmox VM Template Preparation Script

Prepares Linux VMs for conversion into clean Proxmox templates.

## What it does

- Removes SSH host keys
- Clears user shell history
- Resets machine-id
- Cleans cloud-init state

## Usage

```bash
sudo ./prepare-template.sh
shutdown -h now
