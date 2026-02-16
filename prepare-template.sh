#!/usr/bin/env bash
set -euo pipefail
set +x

SERVICE=/etc/systemd/system/ssh-hostkey-init.service

echo "[*] Installing first-boot SSH hostkey service..."

if [ ! -f "$SERVICE" ]; then
echo "[*] Writing service file: $SERVICE"
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
else
echo "[*] Service file already exists: $SERVICE"
fi

echo "[*] Re-executing systemd manager..."
systemctl daemon-reexec >/dev/null 2>&1
echo "[*] Reloading systemd unit files..."
systemctl daemon-reload >/dev/null 2>&1
echo "[*] Enabling first-boot SSH hostkey service..."
systemctl enable ssh-hostkey-init.service >/dev/null 2>&1

echo "[*] Updating package lists..."
apt update -y >/dev/null 2>&1

echo "[*] Upgrading installed packages..."
apt upgrade -y >/dev/null 2>&1

echo "[*] Removing unused packages..."
apt autoremove -y >/dev/null 2>&1

echo "[*] Cleaning package cache..."
apt autoclean -y >/dev/null 2>&1

echo "[*] Removing SSH host keys..."
rm -f /etc/ssh/ssh_host_* >/dev/null 2>&1

echo "[*] Clearing shell history (memory + disk)..."

# Clear current shell history (if interactive)
echo "[*] Clearing in-memory shell history..."
history -c >/dev/null 2>&1 || true
echo "[*] Writing cleared history state..."
history -w >/dev/null 2>&1 || true

# Prevent further writes in this session
echo "[*] Disabling history file for current session..."
unset HISTFILE || true

# Remove history files for all users
echo "[*] Deleting user history files in /home..."
find /home -type f -name ".*history" -delete >/dev/null 2>&1 || true
echo "[*] Deleting root history files..."
rm -f /root/.bash_history /root/.zsh_history >/dev/null 2>&1 || true


echo "[*] Resetting machine-id..."
echo "[*] Truncating /etc/machine-id..."
truncate -s 0 /etc/machine-id >/dev/null 2>&1
echo "[*] Removing DBus machine-id..."
rm -f /var/lib/dbus/machine-id >/dev/null 2>&1

echo "[*] Cleaning cloud-init state (if installed)..."
if command -v cloud-init >/dev/null 2>&1; then
  echo "[*] Cleaning cloud-init logs and state..."
  cloud-init clean --logs >/dev/null 2>&1
else
  echo "[*] cloud-init not found, skipping"
fi

echo "[*] Cleaning system logs..."

echo "[*] Removing syslog/message files..."
rm -f /var/log/syslog /var/log/messages >/dev/null 2>&1 || true
echo "[*] Removing authentication log files..."
rm -f /var/log/auth.log /var/log/secure >/dev/null 2>&1 || true

echo "[*] Rotating journal logs..."
journalctl --rotate >/dev/null 2>&1 || true
echo "[*] Vacuuming old journal entries..."
journalctl --vacuum-time=1s >/dev/null 2>&1 || true

echo "[*] Template prepared. Power off and convert to template."
echo "[*] Flushing filesystem buffers..."
sync

if [ -t 0 ]; then
  read -r -p "Power off now? [y/N] " REPLY
  case "$REPLY" in
    [yY]|[yY][eE][sS])
      echo "[*] Powering off..."
      systemctl poweroff
      ;;
    *)
      echo "[*] Skipping power off."
      ;;
  esac
else
  echo "[*] Non-interactive shell; skipping power off prompt."
fi
