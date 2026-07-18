#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT_NAME="paper-weight-host.service"
TEMPLATE="$ROOT_DIR/scripts/$UNIT_NAME.template"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT_PATH="$UNIT_DIR/$UNIT_NAME"

usage() {
  cat <<'EOF'
Usage: scripts/host-service.sh <install|start|stop|restart|status|uninstall>

  install    Render the systemd --user unit for this checkout, reload the
             user manager, enable the service, and enable linger so it also
             starts after a host reboot with no interactive login.
  start      systemctl --user start paper-weight-host.service
  stop       systemctl --user stop paper-weight-host.service
  restart    systemctl --user restart paper-weight-host.service
  status     systemctl --user status paper-weight-host.service
  uninstall  Stop, disable, and remove the installed unit.

Environment:
  PAPER_WEIGHT_UI_PORT       Production UI port (default 8080)
  PAPER_WEIGHT_GATEWAY_STUBS Set by the unit itself (fixture stubs; live
                              credentials are out of scope for this card)
EOF
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

install_service() {
  require_command systemctl

  mkdir -p "$UNIT_DIR"
  sed "s|__PAPER_WEIGHT_ROOT__|$ROOT_DIR|g" "$TEMPLATE" >"$UNIT_PATH"
  printf 'Installed %s\n' "$UNIT_PATH"

  systemctl --user daemon-reload
  systemctl --user enable "$UNIT_NAME"
  printf 'Enabled %s (starts on user manager start; not yet running — use "start")\n' "$UNIT_NAME"

  if command -v loginctl >/dev/null 2>&1 && loginctl enable-linger "$(id -un)" 2>/dev/null; then
    printf 'Enabled linger for %s: the service survives host reboot without a login.\n' "$(id -un)"
  else
    printf 'warning: could not enable linger automatically.\n' >&2
    printf '  Run manually: loginctl enable-linger %s\n' "$(id -un)" >&2
    printf '  Without linger, this service only starts after that user logs in.\n' >&2
  fi
}

uninstall_service() {
  require_command systemctl

  systemctl --user stop "$UNIT_NAME" 2>/dev/null || true
  systemctl --user disable "$UNIT_NAME" 2>/dev/null || true
  rm -f "$UNIT_PATH"
  systemctl --user daemon-reload
  printf 'Removed %s\n' "$UNIT_PATH"
}

[[ $# -eq 1 ]] || {
  usage >&2
  exit 1
}

case "$1" in
  install)
    install_service
    ;;
  start | stop | restart | status)
    require_command systemctl
    systemctl --user "$1" "$UNIT_NAME"
    ;;
  uninstall)
    uninstall_service
    ;;
  -h | --help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
