# Proxmox VM Template Preparation Script

Production-ready script for preparing Linux virtual machines before converting them into clean Proxmox templates.

## Features

- Installs one-time systemd service for SSH host key regeneration on first boot
- Removes existing SSH host keys from the template
- Clears all user shell history
- Resets machine-id
- Cleans cloud-init state (if present)
- Updates system packages
- Performs apt cleanup (autoremove + autoclean)

## Why this exists

Cloned VMs must never share:

- SSH host fingerprints
- machine-id
- shell command history
- cloud-init state

This script guarantees clean, reproducible Proxmox templates.

## How it works

During template preparation:

- System is fully updated
- Cleanup operations are executed
- SSH host keys are removed
- First-boot regeneration service is installed

On first boot of each clone:

- systemd automatically generates fresh SSH host keys
- Service runs only once and never again

## Usage

```bash
sudo ./prepare-template.sh
shutdown -h now
