#!/usr/bin/env bash
# Make Amlogic burn-mode USB visible to pyamlboot (permissions).
#
# Symptom: device plugged, kernel shows 1b8e:c003 GX-CHIP, but flash says
# "device could not be found" / "No device found!".
#
# Cause: /dev/bus/usb/*/* is often crw-rw-r-- nobody nobody. pyamlboot's
# find_device() reads the USB product string; that control transfer needs
# write access. Failure is swallowed as "not found".
#
# Run this on bare archbox (host zsh), not only inside distrobox:
#   /home/rory/repos/paper-weight/scripts/car-thing-usb-burn-fix.sh
set -euo pipefail

find_nodes() {
  local d v p bus dev
  for d in /sys/bus/usb/devices/*; do
    [[ -f "$d/idVendor" && -f "$d/idProduct" ]] || continue
    v="$(cat "$d/idVendor")"
    p="$(cat "$d/idProduct")"
    # Amlogic worldcup / GX-CHIP (buttons 1+4 or burn)
    if [[ "$v" == "1b8e" && "$p" == "c003" ]]; then
      bus="$(cat "$d/busnum")"
      dev="$(cat "$d/devnum")"
      printf '/dev/bus/usb/%03d/%03d\n' "$bus" "$dev"
    fi
  done
}

echo "Looking for Amlogic 1b8e:c003 (burn / GX-CHIP)..."
mapfile -t NODES < <(find_nodes)

if [[ ${#NODES[@]} -eq 0 ]]; then
  echo "NOT on USB yet."
  echo "  Hold top buttons 1+4, plug in, release after ~2s."
  echo "  Prefer a direct motherboard port (not a deep hub)."
  echo "  Then re-run this script."
  exit 1
fi

for node in "${NODES[@]}"; do
  echo "found: $node  ($(ls -l "$node" 2>/dev/null || true))"
  if [[ -w "$node" ]]; then
    echo "  already writable"
  else
    echo "  fixing permissions (sudo chmod a+rw)..."
    sudo chmod a+rw "$node"
    ls -l "$node"
  fi
done

# Prefer installer venv pyusb if present
MAIN="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "$MAIN" == /run/host/* ]]; then
  MAIN="${MAIN#/run/host}"
fi
PY=""
for c in \
  "$MAIN/device/flash-out/.venv/bin/python3" \
  "$MAIN/.worktrees/device-nix-reconcile/device/flash-out/.venv/bin/python3"
do
  if [[ -x "$c" ]]; then PY="$c"; break; fi
done
PY="${PY:-python3}"

echo
echo "pyusb check with: $PY"
"$PY" - <<'PY' || true
import sys
try:
    import usb.core
except ImportError:
    print("  (no pyusb in this python — flash venv will still use its own)")
    sys.exit(0)

d = usb.core.find(idVendor=0x1B8E, idProduct=0xC003)
if d is None:
    print("  FAIL: pyusb still cannot open 1b8e:c003")
    sys.exit(1)
try:
    product = d.product
except Exception as e:
    print(f"  WARN: device open ok but product string failed: {e}")
    print("  flash may still say not-found — re-run with: sudo $PY ... or re-plug")
    sys.exit(1)
print(f"  OK: product={product!r}  (GX-CHIP = USB mode, ready for flash bl2 entry)")
print("  Next: /home/rory/repos/paper-weight/scripts/car-thing-reflash-last-good.sh")
PY
