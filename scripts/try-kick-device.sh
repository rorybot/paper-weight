#!/usr/bin/env bash
# Grab-bag of quick fixes for "the Car Thing was reachable a minute ago and now
# isn't" — the class of USB-gadget-networking flakiness that isn't a code bug.
# Run this from a native host terminal (needs sudo for the ip-addr fix), not
# from inside Distrobox.
#
# Usage: scripts/try-kick-device.sh [device-ip]
set -euo pipefail

DEVICE_IP="${1:-172.16.42.2}"
HOST_CIDR="172.16.42.1/24"

log() { printf '%s\n' "$*"; }

ping_device() {
  ping -c 1 -W 2 "$DEVICE_IP" >/dev/null 2>&1
}

ssh_port_open() {
  (exec 3<>"/dev/tcp/$DEVICE_IP/22") 2>/dev/null && exec 3<&- 3>&-
}

log "== try-kick-device: diagnosing $DEVICE_IP =="

if ping_device; then
  log "ok: ping to $DEVICE_IP succeeds"
else
  log "fail: ping to $DEVICE_IP does not respond"
fi

log
log "-- fix 1: USB gadget interface lost its static address --"
log "The 172.16.42.1 address on the USB NCM gadget interface is sometimes a"
log "short-lived dynamic/link-local lease (seen with a ~28s valid_lft) rather"
log "than a stable static one. When that lease expires, the host side of the"
log "link silently goes unreachable even though the interface is still UP."

candidates=$(ip -4 -o link show up 2>/dev/null | awk -F': ' '{print $2}' | grep -E '^enp[0-9a-z]+u[0-9]+u[0-9]+$' || true)

if [[ -z "$candidates" ]]; then
  log "no UP enp*u*u* USB gadget interface found — is the Car Thing plugged in?"
else
  for iface in $candidates; do
    current_addr=$(ip -4 -o address show dev "$iface" | awk '{print $4}')
    log "found candidate interface: $iface (current address: ${current_addr:-none})"
    log "applying: sudo ip addr replace $HOST_CIDR dev $iface"
    sudo ip addr replace "$HOST_CIDR" dev "$iface"
  done
fi

log
log "-- re-checking after fix 1 --"
if ping_device; then
  log "ok: ping to $DEVICE_IP now succeeds"
else
  log "still failing: ping to $DEVICE_IP — check the physical USB-C cable at both"
  log "ends, and confirm the interface shows up at all with: ip -4 -o link show"
fi

if ssh_port_open; then
  log "ok: SSH port 22 on $DEVICE_IP is open"
else
  log "SSH port 22 on $DEVICE_IP is not responding yet — if ping just started"
  log "working, give the device a few seconds and re-run this script."
fi

log
log "If none of the above helped, this is likely a genuine device hang, not a"
log "host-side networking blip — see the Troubleshooting section in"
log "docs/architecture/device-launch.md for the next steps (reboot, then"
log "recovery flash via scripts/device-nixos.sh / scripts/device-flash.sh)."
