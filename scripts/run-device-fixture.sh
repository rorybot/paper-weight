#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UI_DIR="$ROOT_DIR/src/device-ui"
HOST_DIR="$ROOT_DIR/host"
UI_HOST="${PAPER_WEIGHT_UI_HOST:-172.16.42.1}"
UI_PORT="${PAPER_WEIGHT_UI_PORT:-8080}"
# Fixed to match host/config/config.exs's :gateway_port — not env-overridable
# here since the host app doesn't read an env var for it.
GATEWAY_PORT=9138

declare -a CHILD_PIDS=()

cleanup() {
  local pid

  trap - EXIT
  for pid in "${CHILD_PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait "${CHILD_PIDS[@]}" 2>/dev/null || true
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

# Polls loopback endpoints rather than $UI_HOST: the servers below bind the
# wildcard address (0.0.0.0), so readiness never depends on whether the Car
# Thing's USB gadget interface happens to be attached yet. This is also what
# makes USB unplug/replug a non-event for this process — nothing is bound to
# the gadget IP specifically, so there is nothing to repair when it returns.
wait_for_ui() {
  local attempts=150

  while ((attempts > 0)); do
    if curl --fail --silent --show-error --max-time 1 \
      "http://127.0.0.1:$UI_PORT/" >/dev/null 2>&1; then
      return 0
    fi
    attempts=$((attempts - 1))
    sleep 0.1
  done

  return 1
}

# The gateway plug only completes a plain GET with a 500 (it expects a
# WebSocket upgrade) — a bare curl --fail would misreport it as down, so
# readiness needs the same upgrade handshake the health-check script uses.
wait_for_gateway() {
  local attempts=150
  local response

  while ((attempts > 0)); do
    # Captured into a variable rather than piped to grep: the gateway keeps
    # a matched WS connection open indefinitely, so a piped `grep -q` exits
    # the moment it matches and SIGPIPEs curl — under `pipefail` that turns
    # curl's resulting timeout (exit 28) into the pipeline's reported
    # failure even though the 101 response was already received.
    response="$(curl --include --silent --max-time 1 \
      -H 'Connection: Upgrade' -H 'Upgrade: websocket' \
      -H 'Sec-WebSocket-Version: 13' \
      -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
      "http://127.0.0.1:$GATEWAY_PORT/" 2>/dev/null || true)"
    if printf '%s' "$response" | grep -q '^HTTP/1.1 101'; then
      return 0
    fi
    attempts=$((attempts - 1))
    sleep 0.1
  done

  return 1
}

trap cleanup EXIT
trap 'exit 0' INT TERM

require_command curl
require_command mix
require_command npm
require_command python3

if [[ "${PAPER_WEIGHT_SKIP_BUILD:-0}" != "1" ]]; then
  if [[ ! -d "$UI_DIR/node_modules" ]]; then
    npm --prefix "$UI_DIR" ci
  fi
  npm --prefix "$UI_DIR" run build
fi

[[ -f "$UI_DIR/dist/index.html" ]] ||
  fail "production UI missing: run without PAPER_WEIGHT_SKIP_BUILD=1"

(
  cd "$HOST_DIR"
  # Fixture-safe by default, but doesn't clobber an inherited value — an
  # EnvironmentFile (or sourced .env) setting PAPER_WEIGHT_GATEWAY_STUBS=none
  # plus the PAPER_WEIGHT_*_ENABLED vars flips this same script to live mode.
  # See docs/architecture/live-runtime-contract-v1.md.
  exec env PAPER_WEIGHT_GATEWAY_STUBS="${PAPER_WEIGHT_GATEWAY_STUBS:-all}" MIX_ENV=dev mix run --no-halt
) &
CHILD_PIDS+=("$!")

python3 -m http.server "$UI_PORT" \
  --bind 0.0.0.0 \
  --directory "$UI_DIR/dist" &
CHILD_PIDS+=("$!")

wait_for_ui ||
  fail "production UI did not become ready on 127.0.0.1:$UI_PORT"
wait_for_gateway ||
  fail "fixture gateway did not become ready on 127.0.0.1:$GATEWAY_PORT"

for pid in "${CHILD_PIDS[@]}"; do
  kill -0 "$pid" 2>/dev/null || fail "a Paper Weight host process exited during startup"
done

printf 'Paper Weight fixture host ready\n'
printf '  UI:      http://%s:%s/  (bound 0.0.0.0:%s)\n' "$UI_HOST" "$UI_PORT" "$UI_PORT"
printf '  Gateway: ws://%s:%s/  (bound 0.0.0.0:%s)\n' "$UI_HOST" "$GATEWAY_PORT" "$GATEWAY_PORT"
printf '  Kiosk:   http://%s:%s/?bridge=0&gateway=ws://%s:%s/\n' \
  "$UI_HOST" "$UI_PORT" "$UI_HOST" "$GATEWAY_PORT"
printf 'Press Ctrl-C to stop both processes (or "systemctl --user stop paper-weight-host").\n'

set +e
wait -n "${CHILD_PIDS[@]}"
status=$?
set -e

fail "a Paper Weight host process exited (status $status)"
