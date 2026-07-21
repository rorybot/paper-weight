#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_SSH="${PAPER_WEIGHT_DEVICE_SSH:-root@172.16.42.2}"
HOST_IP="${PAPER_WEIGHT_HOST_IP:-172.16.42.1}"
UI_PORT="${PAPER_WEIGHT_UI_PORT:-8080}"
GATEWAY_PORT=9138
KIOSK_URL="http://$HOST_IP:$UI_PORT/?bridge=0&gateway=ws://$HOST_IP:$GATEWAY_PORT/"
APPLY_SCRIPT="$ROOT_DIR/device/scripts/apply-kiosk-url.sh"
OVERRIDE_UNIT="$ROOT_DIR/device/systemd/paper-weight-kiosk-override.service"
SSH_OPTIONS=(
  -o BatchMode=yes
  -o ConnectTimeout=5
  -o StrictHostKeyChecking=accept-new
)

usage() {
  cat <<'EOF'
Usage: scripts/device-kiosk.sh <install|status|restart|rollback>

  install   Verify the production UI, install the boot-time kiosk override,
            and restart Weston.
  status    Show the configured URL, override mode, and Weston status.
  restart   Restart Weston with the currently configured kiosk URL.
  rollback  Restore the Nix-managed kiosk URL and restart Weston.

Environment:
  PAPER_WEIGHT_DEVICE_SSH  SSH target (default root@172.16.42.2)
  PAPER_WEIGHT_HOST_IP     USB host address (default 172.16.42.1)
  PAPER_WEIGHT_UI_PORT     production UI port (default 8080)
EOF
}

remote() {
  ssh "${SSH_OPTIONS[@]}" "$DEVICE_SSH" "$@"
}

copy_to_device() {
  scp "${SSH_OPTIONS[@]}" "$1" "$DEVICE_SSH:$2"
}

status() {
  remote bash -s <<'REMOTE'
set -euo pipefail

if systemctl is-enabled --quiet paper-weight-kiosk-override.service 2>/dev/null; then
  override="enabled"
else
  override="disabled"
fi

if [[ -L /etc/kiosk_url ]]; then
  mode="nix-managed"
else
  mode="paper-weight override"
fi

printf 'override=%s\n' "$override"
printf 'mode=%s\n' "$mode"
printf 'url='
cat /etc/kiosk_url
printf '\n'
printf 'weston='
systemctl is-active weston-tty1.service
REMOTE
}

install_override() {
  local encoded_url
  encoded_url="$(printf '%s' "$KIOSK_URL" | base64 | tr -d '\n')"

  copy_to_device "$APPLY_SCRIPT" /tmp/paper-weight-apply-kiosk-url
  copy_to_device "$OVERRIDE_UNIT" /tmp/paper-weight-kiosk-override.service

  remote "PAPER_WEIGHT_KIOSK_URL_B64=$encoded_url bash -s" <<'REMOTE'
set -euo pipefail

url="$(printf '%s' "$PAPER_WEIGHT_KIOSK_URL_B64" | base64 --decode)"
curl --fail --silent --show-error --max-time 5 "$url" >/dev/null

install -d -m 0755 /var/lib/paper-weight
if [[ ! -f /var/lib/paper-weight/kiosk_url.rollback ]]; then
  cat /etc/kiosk_url > /var/lib/paper-weight/kiosk_url.rollback
fi

printf '%s\n' "$url" > /var/lib/paper-weight/kiosk_url
install -m 0755 /tmp/paper-weight-apply-kiosk-url \
  /var/lib/paper-weight/apply-kiosk-url.sh
install -m 0644 /tmp/paper-weight-kiosk-override.service \
  /var/lib/paper-weight/paper-weight-kiosk-override.service

systemctl link --force /var/lib/paper-weight/paper-weight-kiosk-override.service
systemctl daemon-reload
systemctl enable --now paper-weight-kiosk-override.service
systemctl restart weston-tty1.service
sleep 3

[[ ! -L /etc/kiosk_url ]]
systemctl is-enabled --quiet paper-weight-kiosk-override.service
systemctl is-active --quiet weston-tty1.service
printf 'installed='
cat /etc/kiosk_url
printf '\n'
REMOTE
}

rollback() {
  remote bash -s <<'REMOTE'
set -euo pipefail

systemctl disable --now paper-weight-kiosk-override.service 2>/dev/null || true
rm -f /etc/systemd/system/paper-weight-kiosk-override.service
systemctl daemon-reload

rm -f /etc/kiosk_url
ln -s /etc/static/kiosk_url /etc/kiosk_url
systemctl restart weston-tty1.service
sleep 3

[[ -L /etc/kiosk_url ]]
! systemctl is-enabled --quiet paper-weight-kiosk-override.service 2>/dev/null
systemctl is-active --quiet weston-tty1.service
printf 'restored='
cat /etc/kiosk_url
printf '\n'
REMOTE
}

case "${1:-}" in
  install)
    install_override
    status
    ;;
  status)
    status
    ;;
  restart)
    remote systemctl restart weston-tty1.service
    status
    ;;
  rollback)
    rollback
    status
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
