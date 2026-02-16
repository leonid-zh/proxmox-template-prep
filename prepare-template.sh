#!/usr/bin/env bash
set -euo pipefail

SERVICE=/etc/systemd/system/ssh-hostkey-init.service
MARKER=/var/lib/ssh-hostkey-init.done

echo "[*] Installing first-boot SSH hostkey service (idempotent)..."

if [ ! -f "$SERVICE" ]; then
cat >"$SERVICE" <<'EOF'
[Unit]
Description=Generate SSH host keys on first boot
Before=ssh.service
ConditionPathExists=!/etc/ssh/ssh_host_rsa_key

[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A
ExecStartPost=/usr/bin/touch /var/lib/ssh-hostkey-init.done

[Install]
WantedBy=multi-user.target
EOF
fi

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable ssh-hostkey-init.service

echo "[*] Updating system..."
apt update -y
apt upgrade -y
apt autoremove -y
apt autoclean -y

echo "[*] Removing SSH host keys..."
rm -f /etc/ssh/ssh_host_*

echo "[*] Clearing shell history..."
find /home -type f -name ".*history" -delete || true
rm -f /root/.bash_history

echo "[*] Resetting machine-id..."
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id

echo "[*] Cleaning cloud-init state (if present)..."
if command -v cloud-init >/dev/null 2>&1; then
  cloud-init clean --logs
fi

echo "[*] Template prepared. Shut down and convert to template."
sync
