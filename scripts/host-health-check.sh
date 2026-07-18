#!/usr/bin/env bash
set -euo pipefail

# Checks the production UI and fixture gateway independently of whether the
# Car Thing's USB gadget is currently attached: both servers bind the
# wildcard address, so loopback is a faithful proxy for "the service is up."
# Point PAPER_WEIGHT_HEALTH_HOST at 172.16.42.1 to check the gadget-facing
# address specifically once a device is connected.
HOST="${PAPER_WEIGHT_HEALTH_HOST:-127.0.0.1}"
UI_PORT="${PAPER_WEIGHT_UI_PORT:-8080}"
GATEWAY_PORT="${PAPER_WEIGHT_GATEWAY_PORT:-9138}"
TIMEOUT="${PAPER_WEIGHT_HEALTH_TIMEOUT:-3}"

# RFC 6455's example key: only the format matters here, not the accept hash,
# since we only need the server to reach the 101 upgrade branch.
WS_KEY='dGhlIHNhbXBsZSBub25jZQ=='

fail_count=0

check_ui() {
  if curl --fail --silent --show-error --max-time "$TIMEOUT" \
    "http://$HOST:$UI_PORT/" >/dev/null 2>&1; then
    printf 'UI       http://%s:%s/         ok\n' "$HOST" "$UI_PORT"
  else
    printf 'UI       http://%s:%s/         FAIL\n' "$HOST" "$UI_PORT" >&2
    fail_count=$((fail_count + 1))
  fi
}

check_gateway() {
  local response

  response="$(curl --include --silent --max-time "$TIMEOUT" \
    -H 'Connection: Upgrade' \
    -H 'Upgrade: websocket' \
    -H 'Sec-WebSocket-Version: 13' \
    -H "Sec-WebSocket-Key: $WS_KEY" \
    "http://$HOST:$GATEWAY_PORT/" 2>/dev/null || true)"

  if printf '%s' "$response" | grep -q '^HTTP/1.1 101'; then
    printf 'Gateway  ws://%s:%s/            ok\n' "$HOST" "$GATEWAY_PORT"
  else
    printf 'Gateway  ws://%s:%s/            FAIL\n' "$HOST" "$GATEWAY_PORT" >&2
    fail_count=$((fail_count + 1))
  fi
}

check_ui
check_gateway

exit "$fail_count"
