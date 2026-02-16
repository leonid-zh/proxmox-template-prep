#!/usr/bin/env bash
set -Eeuo pipefail
set +x

SERVICE=/etc/systemd/system/ssh-hostkey-init.service
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_TEMPLATE="$SCRIPT_DIR/systemd/systemd-hostkey-unit.service"
LOG_FILE=/var/log/template-prep.log

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "[!] This script must be run as root."
  exit 1
fi

: >"$LOG_FILE"

trap 'rc=$?; echo "[!] Failed (exit ${rc}) at line ${BASH_LINENO[0]}: ${BASH_COMMAND}"; echo "[!] See details in ${LOG_FILE}"; exit "${rc}"' ERR

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[!] Required command not found: $cmd"
    exit 1
  fi
}

run_step() {
  local message="$1"
  shift
  echo "[*] $message"
  "$@" >>"$LOG_FILE" 2>&1
}

run_optional_step() {
  local message="$1"
  shift
  echo "[*] $message"
  if ! "$@" >>"$LOG_FILE" 2>&1; then
    echo "[!] Non-critical step failed: $message (see $LOG_FILE)"
  fi
}

require_command systemctl
require_command apt-get
require_command install
require_command truncate
require_command find
require_command rm
require_command journalctl
require_command sync

if [ ! -f "$SERVICE_TEMPLATE" ]; then
  echo "[!] Service template not found: $SERVICE_TEMPLATE"
  exit 1
fi

if [ ! -f "$SERVICE" ] || ! cmp -s "$SERVICE_TEMPLATE" "$SERVICE"; then
  run_step "Installing first-boot SSH hostkey service..." install -m 0644 "$SERVICE_TEMPLATE" "$SERVICE"
else
  echo "[*] First-boot SSH hostkey service is already up to date."
fi

run_step "Reloading systemd unit files..." systemctl daemon-reload
run_step "Enabling first-boot SSH hostkey service..." systemctl enable ssh-hostkey-init.service

run_step "Updating package lists..." env DEBIAN_FRONTEND=noninteractive apt-get update
run_step "Upgrading installed packages..." env DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
run_step "Removing unused packages..." env DEBIAN_FRONTEND=noninteractive apt-get -y autoremove
run_step "Cleaning package cache..." env DEBIAN_FRONTEND=noninteractive apt-get -y autoclean

run_step "Removing SSH host keys..." rm -f /etc/ssh/ssh_host_*
run_step "Removing systemd random seed..." rm -f /var/lib/systemd/random-seed

run_optional_step "Clearing in-memory shell history..." history -c
run_optional_step "Writing cleared shell history..." history -w
run_optional_step "Disabling history file for current session..." unset HISTFILE
run_optional_step "Deleting user history files in /home..." find /home -type f -name ".*history" -delete
run_optional_step "Deleting root history files..." rm -f /root/.bash_history /root/.zsh_history

run_step "Truncating /etc/machine-id..." truncate -s 0 /etc/machine-id
run_step "Removing DBus machine-id..." rm -f /var/lib/dbus/machine-id

if command -v cloud-init >/dev/null 2>&1; then
  run_step "Cleaning cloud-init logs and state..." cloud-init clean --logs
else
  echo "[*] cloud-init not found, skipping state cleanup."
fi

if [ -d /tmp ]; then
  run_step "Cleaning temporary directory contents: /tmp" find /tmp -mindepth 1 -xdev -exec rm -rf -- {} +
fi

if [ -d /var/tmp ]; then
  run_step "Cleaning temporary directory contents: /var/tmp" find /var/tmp -mindepth 1 -xdev -exec rm -rf -- {} +
fi

if [ -d /var/log ]; then
  run_step "Truncating text log files under /var/log" find /var/log -xdev -type f \( -name "*.log" -o -name "syslog" -o -name "messages" -o -name "secure" -o -name "auth.log" -o -name "kern.log" \) -exec truncate -s 0 {} +
fi

run_optional_step "Rotating journal logs..." journalctl --rotate
run_optional_step "Vacuuming old journal entries..." journalctl --vacuum-size=16M

run_step "Flushing filesystem buffers..." sync
echo "[*] Template prepared. Power off and convert to template."
echo "[*] Detailed command output: $LOG_FILE"

if [ -t 0 ]; then
  read -r -p "Power off now? [y/N] " REPLY
  case "$REPLY" in
    [yY]|[yY][eE][sS])
      run_step "Powering off..." systemctl poweroff
      ;;
    *)
      echo "[*] Skipping power off."
      ;;
  esac
else
  echo "[*] Non-interactive shell; skipping power off prompt."
fi
