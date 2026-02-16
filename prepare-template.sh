#!/usr/bin/env bash
set -euo pipefail

SERVICE=/etc/systemd/system/ssh-hostkey-init.service

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GRAY='\033[0;37m'
NC='\033[0m'

log_status() {
  local name="$1"; local status="$2"; local msg="$3"; local fix="${4:-}"
  local color tag
  case "$status" in
    PASS) color="$GREEN" tag="[PASS]" ;;
    WARN) color="$YELLOW" tag="[WARN]" ;;
    FAIL) color="$RED" tag="[FAIL]" ;;
    *) color="$GRAY" tag="[INFO]" ;;
  esac
  if [[ ( "$status" == "WARN" || "$status" == "FAIL" ) && -n "$fix" ]]; then
    msg="$msg | Fix: $fix"
  fi
  echo -e "${color}${tag}${NC} $name ${GRAY}- $msg${NC}"
}

run_cmd() {
  local name="$1"; shift
  log_status "$name" "INFO" "Starting"
  "$@"
}

log_status "SSH hostkey service" "INFO" "Installing first-boot SSH hostkey service"

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

run_cmd "systemd" systemctl daemon-reexec
run_cmd "systemd" systemctl daemon-reload
run_cmd "systemd" systemctl enable ssh-hostkey-init.service

run_cmd "apt" apt update -y 2>&1
run_cmd "apt" apt upgrade -y 2>&1
run_cmd "apt" apt autoremove -y 2>&1
run_cmd "apt" apt autoclean -y 2>&1

log_status "SSH host keys" "INFO" "Removing"
run_cmd "ssh" rm -f /etc/ssh/ssh_host_*

log_status "Shell history" "INFO" "Clearing (memory + disk)"

# Clear current shell history (if interactive)
history -c 2>/dev/null || true
history -w 2>/dev/null || true

# Prevent further writes in this session
unset HISTFILE || true

# Remove history files for all users
find /home -type f -name ".*history" -delete 2>/dev/null || true
rm -f /root/.bash_history /root/.zsh_history 2>/dev/null || true


log_status "machine-id" "INFO" "Resetting"
run_cmd "machine-id" truncate -s 0 /etc/machine-id
run_cmd "machine-id" rm -f /var/lib/dbus/machine-id

log_status "cloud-init" "INFO" "Cleaning state (if installed)"
if command -v cloud-init >/dev/null 2>&1; then
  run_cmd "cloud-init" cloud-init clean --logs
fi

log_status "system logs" "INFO" "Cleaning"

rm -f /var/log/syslog /var/log/messages 2>/dev/null || true
rm -f /var/log/auth.log /var/log/secure 2>/dev/null || true

run_cmd "journalctl" journalctl --rotate || true
run_cmd "journalctl" journalctl --vacuum-time=1s || true

log_status "template" "INFO" "Prepared. Power off and convert to template"
sync

if [ -t 0 ]; then
  read -r -p "Power off now? [y/N] " REPLY
  case "$REPLY" in
    [yY]|[yY][eE][sS])
      log_status "poweroff" "WARN" "Powering off"
      systemctl poweroff
      ;;
    *)
      log_status "poweroff" "INFO" "Skipping"
      ;;
  esac
else
  log_status "poweroff" "INFO" "Non-interactive shell; skipping prompt"
fi
