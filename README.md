# Proxmox VM Template Preparation Script

Production-ready script for preparing Linux virtual machines before converting them into clean Proxmox templates.

## Features

- Installs one-time systemd service for SSH host key regeneration on first boot
- Uses `examples/systemd-hostkey-unit.service` as the source template for unit content
- Reuses existing service file if it already exists
- Removes existing SSH host keys from the template
- Clears all user shell history
- Resets machine-id
- Cleans cloud-init state (if present)
- Updates system packages
- Performs apt cleanup (autoremove + autoclean)
- Cleans system logs and journal
- Runs in quiet mode (shows step messages, hides command output)
- Asks at the end whether to power off the VM

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
```

At the end of the run, the script asks:

```text
Power off now? [y/N]
```

- `y` / `yes`: powers off the VM
- any other input (or Enter): skips power off
- non-interactive shell: power-off prompt is skipped automatically
