#!/usr/bin/env bash
set -euo pipefail

SERVICE=/etc/systemd/system/ssh-hostkey-init.service

echo "[*] Installing first-boot SSH hostkey service..."

if [ ! -f "$SERVICE" ]; then
cat >"$SERVICE" <<'EOF'
[Unit]
Description=Generate SSH host keys on first boot
Before=ssh.service
ConditionPathExists=!/etc/ssh/ssh_host_rsa_key

[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A

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

echo "[*] Cleaning cloud-init state (if installed)..."
if command -v cloud-init >/dev/null 2>&1; then
  cloud-init clean --logs
fi

echo "[*] Cleaning system logs..."

rm -f /var/log/syslog /var/log/messages 2>/dev/null || true
rm -f /var/log/auth.log /var/log/secure 2>/dev/null || true

journalctl --rotate || true
journalctl --vacuum-time=1s || true

echo "[*] Template prepared. Power off and convert to template."
sync
