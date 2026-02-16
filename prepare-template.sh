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

echo "[*] Running apt update..."
apt update -y 2>&1

echo "[*] Running apt upgrade..."
apt upgrade -y 2>&1

echo "[*] Running apt autoremove..."
apt autoremove -y 2>&1

echo "[*] Running apt autoclean..."
apt autoclean -y 2>&1

echo "[*] Removing SSH host keys..."
rm -f /etc/ssh/ssh_host_*

echo "[*] Clearing shell history (memory + disk)..."

# Clear current shell history (if interactive)
history -c 2>/dev/null || true
history -w 2>/dev/null || true

# Prevent further writes in this session
unset HISTFILE || true

# Remove history files for all users
find /home -type f -name ".*history" -delete 2>/dev/null || true
rm -f /root/.bash_history /root/.zsh_history 2>/dev/null || true


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
