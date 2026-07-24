#!/usr/bin/env bash
# Car Thing recovery: flash last-good image via pyamlboot (burn mode).
#
# Before running:
#   1) Unplug the device
#   2) Hold top buttons 1 + 4
#   3) Plug USB, wait ~2s, release buttons (burn mode)
#   4) Run this script
#
# After flash completes, unplug/replug for a normal boot (no buttons held).
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MAIN="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# Prefer host-native path when invoked from Distrobox (/run/host/...).
if [[ "$MAIN" == /run/host/* ]]; then
  MAIN="${MAIN#/run/host}"
fi

# device-flash.sh insists FLASH_DIR/KEEP_DIR live under its own ROOT_DIR
# (the device-nix-reconcile worktree), not the main checkout.
WT="${PAPER_WEIGHT_FLASH_WORKTREE:-$MAIN/.worktrees/device-nix-reconcile}"
FLASH_SH="${PAPER_WEIGHT_DEVICE_FLASH_SH:-$WT/scripts/device-flash.sh}"
export PAPER_WEIGHT_FLASH_DIR="${PAPER_WEIGHT_FLASH_DIR:-$WT/device/flash-out}"
export PAPER_WEIGHT_FLASH_KEEP_DIR="${PAPER_WEIGHT_FLASH_KEEP_DIR:-$WT/device/flash-keep/last-good}"

# Real last-good lives on the main checkout (gitignored, verified_ssh=yes).
MAIN_KEEP="$MAIN/device/flash-keep/last-good"

[[ -x "$FLASH_SH" ]] || {
  printf 'error: missing flash helper: %s\n' "$FLASH_SH" >&2
  exit 1
}
[[ -d "$WT" ]] || {
  printf 'error: missing worktree: %s\n' "$WT" >&2
  exit 1
}
[[ -f "$MAIN_KEEP/rootfs.img" && -f "$MAIN_KEEP/bootfs.bin" ]] || {
  printf 'error: missing main last-good images under %s\n' "$MAIN_KEEP" >&2
  exit 1
}

# Seed worktree keep from main if needed (symlink — no 3GB copy).
if [[ ! -f "$PAPER_WEIGHT_FLASH_KEEP_DIR/rootfs.img" ]]; then
  mkdir -p "$(dirname "$PAPER_WEIGHT_FLASH_KEEP_DIR")"
  if [[ -e "$PAPER_WEIGHT_FLASH_KEEP_DIR" || -L "$PAPER_WEIGHT_FLASH_KEEP_DIR" ]]; then
    rm -rf "$PAPER_WEIGHT_FLASH_KEEP_DIR"
  fi
  ln -sfn "$MAIN_KEEP" "$PAPER_WEIGHT_FLASH_KEEP_DIR"
  printf 'seeded keep symlink: %s → %s\n' "$PAPER_WEIGHT_FLASH_KEEP_DIR" "$MAIN_KEEP"
fi

[[ -f "$PAPER_WEIGHT_FLASH_KEEP_DIR/rootfs.img" ]] || {
  printf 'error: keep rootfs not readable at %s\n' "$PAPER_WEIGHT_FLASH_KEEP_DIR" >&2
  exit 1
}

printf 'Using:\n  FLASH_SH=%s\n  FLASH_DIR=%s\n  KEEP_DIR=%s\n\n' \
  "$FLASH_SH" "$PAPER_WEIGHT_FLASH_DIR" "$PAPER_WEIGHT_FLASH_KEEP_DIR"

printf 'Flashing last-good keep → device (destructive)...\n'
# flash --from-keep copies keep → FLASH_DIR then runs pyamlboot
"$FLASH_SH" flash --from-keep

printf '\nFlash done. Unplug/replug for normal boot (no buttons), then waiting for SSH...\n'
"$FLASH_SH" wait

printf '\nDevice should be up. Quick checks:\n'
ip -br addr 2>/dev/null | grep -E 'enp0s20|usb|ncm' || true
ping -c1 -W2 172.16.42.2 || true
ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
  root@172.16.42.2 'uptime; systemctl is-active weston-tty1.service 2>/dev/null || true' || true
