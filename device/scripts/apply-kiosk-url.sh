#!/usr/bin/env bash
set -euo pipefail

SOURCE=/var/lib/paper-weight/kiosk_url
TARGET=/etc/kiosk_url

[[ -s "$SOURCE" ]] || {
  printf 'error: missing kiosk URL: %s\n' "$SOURCE" >&2
  exit 1
}

rm -f "$TARGET"
install -m 0644 "$SOURCE" "$TARGET"
