#!/usr/bin/env bash
# Self-paced physical verification for #111 — hide the kiosk pointer.
# Run from your own terminal (not an agent shell): walks evaluate → build →
# deploy → Weston restart → cold boot → rollback drill, prompting you to
# observe the 800×480 screen at each gate and logging every answer.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
device_nixos="$script_dir/device-nixos.sh"
log_file="${PAPER_WEIGHT_POINTER_LOG:-$script_dir/../.kiosk-pointer-111.log}"

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$log_file"
}

run_step() {
  local name="$1"
  shift
  log "STEP $name: $*"
  if "$@" 2>&1 | tee -a "$log_file"; then
    log "STEP $name: ok"
  else
    log "STEP $name: FAILED"
    exit 1
  fi
}

ask() {
  local prompt="$1"
  local answer
  while true; do
    read -r -p "$prompt [y/n] " answer </dev/tty
    case "$answer" in
      y | Y) log "OBSERVED yes: $prompt"; return 0 ;;
      n | N) log "OBSERVED no: $prompt"; return 1 ;;
      *) echo "please answer y or n" ;;
    esac
  done
}

pause() {
  read -r -p "$1 — press Enter when ready. " _ </dev/tty
  log "CHECKPOINT: $1"
}

log "=== #111 pointer verification session start ==="

run_step evaluate "$device_nixos" evaluate
run_step build "$device_nixos" build
run_step deploy "$device_nixos" deploy

pause "Deploy done. Weston must be restarted for the new weston.ini to load"
run_step weston-restart ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null root@172.16.42.2 systemctl restart weston-tty1.service

pause "Wait for the kiosk to repaint, then wiggle the wheel / touch the screen"
if ask "Is the pointer GONE after the Weston restart?"; then
  restart_ok=1
else
  restart_ok=0
fi

pause "Now cold boot: the script will reboot the device"
run_step reboot "$device_nixos" reboot
pause "Wait for the kiosk to come back, then wiggle the wheel / touch the screen"
if ask "Is the pointer GONE after the cold boot?"; then
  boot_ok=1
else
  boot_ok=0
fi

ask "Do host keyboard / dev workflows still work (SSH, DevTools reachable)?" \
  && dev_ok=1 || dev_ok=0

if ask "Run the rollback drill (activate previous generation, then return)?"; then
  run_step rollback "$device_nixos" rollback
  pause "Confirm the kiosk still paints on the OLD generation"
  log "Rollback drill: old generation active"
  run_step status "$device_nixos" status
  echo "Pick the NEW generation number from the list above."
  read -r -p "New generation to re-activate: " gen </dev/tty
  run_step activate "$device_nixos" activate "$gen"
  log "Rollback drill complete: returned to generation $gen"
fi

log "=== RESULT restart_pointer_gone=$restart_ok cold_boot_pointer_gone=$boot_ok dev_workflows_ok=$dev_ok ==="
if [[ "$restart_ok" -eq 1 && "$boot_ok" -eq 1 && "$dev_ok" -eq 1 ]]; then
  log "ACCEPTANCE MET — paste $log_file into #111 and tell the agent to close out"
else
  log "ACCEPTANCE NOT MET — leave #111 open; attempt B (transparent cursor theme) is next"
  exit 1
fi
