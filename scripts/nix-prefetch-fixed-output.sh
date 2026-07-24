#!/usr/bin/env bash
# Pre-supply one fixed-output derivation's content directly into the persistent
# builder Nix store, bypassing a flaky/expensive fetch path (e.g. the nixbuild.net
# SSH remote-builder link dying mid-transfer on a large custom github tarball fetch).
#
# Fixed-output derivations are content-addressed: Nix only cares that the result
# matches the known hash, not how or where it was produced. So we fetch it here
# with plain reliable curl (real host internet, no SSH-to-remote-builder involved),
# reproduce the same unpack-single-top-level-entry step nixpkgs' generic fetcher
# does, and register it in the store by hash. The next build/deploy sees a valid
# path already present for that derivation and skips fetching it entirely.
#
# Usage:
#   scripts/nix-prefetch-fixed-output.sh <url> <expected-store-path>
#
# Example (spotify-kernel source, blocking every deploy as of 2026-07-24 — see
# resolutions/nixbuild-retries-restart-from-zero.md):
#   scripts/nix-prefetch-fixed-output.sh \
#     "https://github.com/JoeyEamigh/spotify-kernel/archive/295ca0144aca4cebf7a4ab21e73d7395013315d2.tar.gz" \
#     "/nix/store/a06q8hxn4mk1015k4yz2d3fp073vv010-source"
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MAIN="$(cd -- "$SCRIPT_DIR/.." && pwd)"
if [[ "$MAIN" == /run/host/* ]]; then
  MAIN="${MAIN#/run/host}"
fi

BUILDER_IMAGE="${PAPER_WEIGHT_NIX_BUILDER:-ghcr.io/joeyeamigh/nixos-superbird/builder:latest}"
NIX_STORE_VOLUME="${PAPER_WEIGHT_NIX_STORE_VOLUME:-paper-weight-nix-store}"

url="${1:?usage: $0 <url> <expected-store-path>}"
expected_path="${2:?usage: $0 <url> <expected-store-path>}"
# Store paths are <hash>-<name>; nix-store --add-fixed needs the exact same
# name to reproduce the same path, since name is part of the digest input.
expected_base="$(basename "$expected_path")"
name="${expected_base#*-}"

if [[ -n "${PAPER_WEIGHT_PODMAN:-}" ]]; then
  podman=("$PAPER_WEIGHT_PODMAN")
elif [[ -n "${CONTAINER_ID:-}" ]] && command -v distrobox-host-exec >/dev/null 2>&1; then
  podman=(distrobox-host-exec podman)
else
  command -v podman >/dev/null 2>&1 || {
    printf 'error: podman not found (run this on the host, not this container)\n' >&2
    exit 1
  }
  podman=(podman)
fi

printf 'url=%s\n' "$url"
printf 'expected_path=%s\n' "$expected_path"
printf 'derived_name=%s\n' "$name"
printf 'nix_store_volume=%s\n' "$NIX_STORE_VOLUME"
printf '\n'

result="$(
  "${podman[@]}" run --rm --privileged --network=host \
    --volume "$NIX_STORE_VOLUME:/nix" \
    "$BUILDER_IMAGE" \
    sh -eu -c '
      set -x
      cd /tmp
      # The bare builder image has no curl on PATH; pull it via nix itself
      # (small, public-substituter package — not the flaky custom fetch path).
      export FETCH_URL="$1"
      nix-shell -p curl --run '"'"'curl -L -o /tmp/src.archive "$FETCH_URL"'"'"'
      rm -rf /tmp/unpack "/tmp/$2"
      mkdir /tmp/unpack
      cd /tmp/unpack
      tar xf /tmp/src.archive
      # Mirror nixpkgs generic fetcher postFetch exactly: recursive +w during
      # unpack, then a single non-recursive 755 on the final top-level output —
      # permission bits are part of the NAR hash, so this must match precisely.
      chmod -R +w /tmp/unpack
      entries="$(ls -A)"
      count="$(printf "%s\n" "$entries" | wc -l)"
      if [ "$count" -ne 1 ]; then
        echo "error: archive must contain exactly one top-level entry, found $count" >&2
        exit 1
      fi
      if [ -f "$entries" ]; then
        mkdir "/tmp/$2"
        mv "$entries" "/tmp/$2"
      else
        mv "$entries" "/tmp/$2"
      fi
      chmod 755 "/tmp/$2"
      nix-store --add-fixed --recursive sha256 "/tmp/$2"
    ' sh "$url" "$name"
)"

printf '\nregistered store path: %s\n' "$result"

if [[ "$result" == "$expected_path" ]]; then
  printf 'OK: matches expected path — this derivation should now be skipped on the next build/deploy.\n'
else
  printf 'MISMATCH: expected %s, got %s\n' "$expected_path" "$result" >&2
  printf 'Do not proceed assuming this is fixed — the content or unpack step differs from what the derivation expects.\n' >&2
  exit 1
fi
