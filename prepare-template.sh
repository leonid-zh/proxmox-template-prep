#!/usr/bin/env bash
set -euo pipefail

echo "[*] Removing SSH host keys"
rm -f /etc/ssh/ssh_host_*

echo "[*] Clearing shell history"
find /home -type f -name ".*history" -delete || true
rm -f /root/.bash_history

echo "[*] Resetting machine-id"
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id

echo "[*] Cleaning cloud-init state (if installed)"
if command -v cloud-init >/dev/null 2>&1; then
  cloud-init clean --logs
fi

echo "[*] Done. Power off and convert to template."
sync
