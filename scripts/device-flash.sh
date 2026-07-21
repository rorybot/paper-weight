#!/usr/bin/env bash
# Offline USB flash for Car Thing (nixos-superbird + pyamlboot manual path).
# This is the original P0-1 bootstrap path — NOT live SSH deploy.
#
# Workspace: this script roots itself from its own path (repo that contains it).
# Run with an absolute path, e.g.:
#   /home/rory/repos/paper-weight/scripts/device-flash.sh build
#   /home/rory/repos/paper-weight/scripts/device-flash.sh flash
#   /home/rory/repos/paper-weight/scripts/device-flash.sh wait
#   /home/rory/repos/paper-weight/scripts/device-flash.sh all
#
# Does not need working NCM/SSH to flash. Needs USB burn mode for `flash`.
#
# Local last-good keep (gitignored, not committed):
#   After a successful build (and again after wait proves SSH), the installer is
#   copied to device/flash-keep/last-good so a later brick does not require rebuild.
#   restore-keep / flash --from-keep reuses that copy.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FLAKE_DIR="$ROOT_DIR/device/nix"
# Flake ref inside the builder container (repo mounted at /workdir).
FLAKE_REF="path:/workdir?dir=device/nix"
BUILDER_IMAGE="${PAPER_WEIGHT_NIX_BUILDER:-ghcr.io/joeyeamigh/nixos-superbird/builder:latest}"
FLASH_DIR="${PAPER_WEIGHT_FLASH_DIR:-$ROOT_DIR/device/flash-out}"
# Single retained installer (not git). Overwritten only by keep / successful build|wait.
KEEP_DIR="${PAPER_WEIGHT_FLASH_KEEP_DIR:-$ROOT_DIR/device/flash-keep/last-good}"
DEVICE_TARGET="${PAPER_WEIGHT_DEVICE_TARGET:-root@172.16.42.2}"
HOST_IP="${PAPER_WEIGHT_HOST_IP:-172.16.42.1}"
DEVICE_IP="${PAPER_WEIGHT_DEVICE_IP:-172.16.42.2}"
# Simple P0-style kiosk when staging a recovery flake (build --recovery).
RECOVERY_KIOSK_URL="${PAPER_WEIGHT_FLASH_KIOSK_URL:-http://172.16.42.1:8080/device-smoke/}"
NIXBUILD_HOST="eu.nixbuild.net"
NIXBUILD_HOST_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM"
NIXBUILD_KEY_DEFAULT="${HOME}/.ssh/my-nixbuild-key"
NIXBUILD_MODE="${PAPER_WEIGHT_NIXBUILD:-auto}"
# last build kind written into KEEP MANIFEST (production | recovery)
LAST_BUILD_KIND="production"
LAST_BUILD_KIOSK_URL=""

usage() {
  cat <<EOF
Usage: $0 <command>

Offline reflash (path B / original P0-1). Does not use SSH deploy.

Commands:
  build [--recovery]  Build installer + bootfs into FLASH_DIR; promote to last-good keep
  flash [--from-keep] Run pyamlboot flash (optionally restore last-good into FLASH_DIR first)
  wait                After power-cycle: host IP if needed, wait for SSH; mark keep verified
  keep                Manually promote current FLASH_DIR → last-good (no rebuild)
  restore-keep        Copy last-good → FLASH_DIR (no flash)
  all                 build --recovery → flash → wait
  status              FLASH_DIR + last-good keep + USB/NCM hints

Keep practice (one healthy image is enough):
  Production and recovery flash images are the same NixOS kiosk stack; only kiosk_url
  differs. The Preact app is host-served, not baked into the image. Prefer a normal
  \`build\` (production URL) as last-good; use \`build --recovery\` only for smoke URL.

  last-good path: $KEEP_DIR
  (gitignored — never commit)

Environment:
  PAPER_WEIGHT_FLASH_DIR       Installer stage dir
                               (default: $ROOT_DIR/device/flash-out)
  PAPER_WEIGHT_FLASH_KEEP_DIR  Retained last-good dir
                               (default: $ROOT_DIR/device/flash-keep/last-good)
  PAPER_WEIGHT_NIX_BUILDER     Builder image override
  PAPER_WEIGHT_PODMAN          Podman binary override
  PAPER_WEIGHT_NIXBUILD        auto|1|0 (default auto)
  PAPER_WEIGHT_NIXBUILD_KEY    nixbuild.net key path
  PAPER_WEIGHT_DEVICE_TARGET   SSH after flash (default root@172.16.42.2)
  PAPER_WEIGHT_HOST_IP         Host gadget address (default 172.16.42.1)
  PAPER_WEIGHT_FLASH_KIOSK_URL Recovery kiosk URL for: build --recovery
  PAPER_WEIGHT_FLASH_YES=1     Skip interactive confirmations on flash

Burn mode (for flash): hold top buttons 1 and 4 while plugging USB.
EOF
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

host_bind_path() {
  local path="$1"
  if [[ -n "${CONTAINER_ID:-}" ]]; then
    printf '%s\n' "${path#/run/host}"
  else
    printf '%s\n' "$path"
  fi
}

# Prefer host-native sudo when running inside Distrobox.
host_sudo() {
  if [[ -n "${CONTAINER_ID:-}" ]] && command -v distrobox-host-exec >/dev/null 2>&1; then
    distrobox-host-exec sudo "$@"
  else
    require_command sudo
    sudo "$@"
  fi
}

resolve_nixbuild_key() {
  local key="${PAPER_WEIGHT_NIXBUILD_KEY:-$NIXBUILD_KEY_DEFAULT}"
  if [[ ! -f "$key" && -f "/run/host/home/${USER:-rory}/.ssh/my-nixbuild-key" ]]; then
    key="/run/host/home/${USER:-rory}/.ssh/my-nixbuild-key"
  fi
  if [[ ! -f "$key" && -f "/home/rory/.ssh/my-nixbuild-key" ]]; then
    key="/home/rory/.ssh/my-nixbuild-key"
  fi
  printf '%s\n' "$key"
}

run_builder() {
  local -a podman
  local -a podman_args
  local builder_workdir="$ROOT_DIR"
  local nixbuild_key=""
  local nixbuild_key_host=""
  local use_nixbuild=0

  if [[ -n "${PAPER_WEIGHT_PODMAN:-}" ]]; then
    podman=("$PAPER_WEIGHT_PODMAN")
  elif [[ -n "${CONTAINER_ID:-}" ]] && command -v distrobox-host-exec >/dev/null 2>&1; then
    podman=(distrobox-host-exec podman)
    builder_workdir="$(host_bind_path "$ROOT_DIR")"
  else
    require_command podman
    podman=(podman)
  fi

  nixbuild_key="$(resolve_nixbuild_key)"
  case "$NIXBUILD_MODE" in
    1 | true | yes | on)
      [[ -f "$nixbuild_key" ]] || fail "PAPER_WEIGHT_NIXBUILD=1 but key not found: $nixbuild_key"
      use_nixbuild=1
      ;;
    0 | false | no | off)
      use_nixbuild=0
      ;;
    auto)
      if [[ -f "$nixbuild_key" ]]; then
        use_nixbuild=1
      else
        printf 'note: nixbuild disabled (no key at %s)\n' "$nixbuild_key" >&2
      fi
      ;;
    *)
      fail "PAPER_WEIGHT_NIXBUILD must be auto, 1, or 0 (got: $NIXBUILD_MODE)"
      ;;
  esac

  podman_args=(
    run
    --privileged
    --rm
    --network=host
    --volume "$builder_workdir:/workdir"
  )

  if [[ "$use_nixbuild" -eq 1 ]]; then
    nixbuild_key_host="$(host_bind_path "$nixbuild_key")"
    printf 'note: nixbuild enabled (key=%s → %s)\n' "$nixbuild_key" "$NIXBUILD_HOST" >&2
    podman_args+=(--volume "$nixbuild_key_host:/run/paper-weight/nixbuild-key:ro")
    # shellcheck disable=SC2016
    "${podman[@]}" "${podman_args[@]}" \
      "$BUILDER_IMAGE" \
      sh -eu -c '
        KEY_RW=/root/.ssh/id_nixbuild
        HOST="'"$NIXBUILD_HOST"'"
        HOST_KEY="'"$NIXBUILD_HOST_KEY"'"
        mkdir -p /root/.ssh
        cp /run/paper-weight/nixbuild-key "$KEY_RW"
        chmod 600 "$KEY_RW"
        cat > /root/.ssh/config <<EOF
Host $HOST
  PubkeyAcceptedKeyTypes ssh-ed25519
  ServerAliveInterval 60
  IdentityFile $KEY_RW
  IdentitiesOnly yes
  StrictHostKeyChecking yes
  UserKnownHostsFile /root/.ssh/known_hosts
EOF
        chmod 600 /root/.ssh/config
        printf "%s %s\n" "$HOST" "$HOST_KEY" > /root/.ssh/known_hosts
        export NIX_CONFIG="${NIX_CONFIG:+$NIX_CONFIG
}builders = ssh://$HOST x86_64-linux - 100 1 big-parallel,benchmark ; ssh://$HOST aarch64-linux - 100 1 big-parallel,benchmark
builders-use-substitutes = true"
        exec "$@"
      ' sh "$@"
  else
    "${podman[@]}" "${podman_args[@]}" \
      "$BUILDER_IMAGE" \
      "$@"
  fi
}

require_flake() {
  [[ -f "$FLAKE_DIR/flake.nix" ]] ||
    fail "missing device flake: $FLAKE_DIR/flake.nix (this script roots at $ROOT_DIR)"
  if ! grep -q 'manualScript' "$FLAKE_DIR/flake.nix"; then
    fail "device flake must set superbird.installer.manualScript = true (file: $FLAKE_DIR/flake.nix)"
  fi
}

installer_ready() {
  local dir="$1"
  [[ -f "$dir/bootfs.bin" && -f "$dir/rootfs.img" && -d "$dir/manual" ]]
}

read_kiosk_from_flash_dir() {
  local dir="$1"
  # Best-effort: env.txt sometimes carries the URL; otherwise leave empty.
  if [[ -f "$dir/env.txt" ]] && grep -q 'kiosk' "$dir/env.txt" 2>/dev/null; then
    grep -i 'kiosk' "$dir/env.txt" | head -1 || true
  fi
}

# Copy a complete FLASH_DIR tree into KEEP_DIR with a small MANIFEST.
# Does not delete KEEP_DIR until the source is proven ready (avoids wiping last-good on failure).
promote_keep() {
  local source_dir="${1:-$FLASH_DIR}"
  local kind="${2:-$LAST_BUILD_KIND}"
  local kiosk_url="${3:-$LAST_BUILD_KIOSK_URL}"
  local verified="${4:-no}"
  local git_rev=""
  local staging=""

  installer_ready "$source_dir" ||
    fail "cannot promote keep: incomplete installer in $source_dir (need bootfs.bin rootfs.img manual/)"

  git_rev="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
  staging="${KEEP_DIR}.staging.$$"
  rm -rf "$staging"
  mkdir -p "$(dirname "$KEEP_DIR")"
  # Prefer cp -a; fall back if cross-device oddities.
  cp -a "$source_dir" "$staging"
  # Drop bulky/ephemeral venv from a prior flash attempt if present.
  rm -rf "$staging/.venv"
  {
    printf 'promoted_at=%s\n' "$(date -Iseconds)"
    printf 'kind=%s\n' "$kind"
    printf 'kiosk_url=%s\n' "$kiosk_url"
    printf 'git_rev=%s\n' "$git_rev"
    printf 'source_dir=%s\n' "$source_dir"
    printf 'verified_ssh=%s\n' "$verified"
    printf 'note=gitignored local keep; not an app bundle — UI is host-served\n'
  } >"$staging/KEEP_MANIFEST"

  rm -rf "$KEEP_DIR"
  mv "$staging" "$KEEP_DIR"
  printf 'keep_promoted dir=%s kind=%s verified_ssh=%s\n' "$KEEP_DIR" "$kind" "$verified" >&2
}

restore_keep_to_flash() {
  installer_ready "$KEEP_DIR" ||
    fail "no last-good keep at $KEEP_DIR (run build once, or keep after a good flash-out)"
  case "$FLASH_DIR" in
    "$ROOT_DIR"/*) ;;
    *)
      fail "PAPER_WEIGHT_FLASH_DIR must be under $ROOT_DIR (got $FLASH_DIR)"
      ;;
  esac
  rm -rf "$FLASH_DIR"
  cp -a "$KEEP_DIR" "$FLASH_DIR"
  # Manifest is informational only in the working flash dir.
  printf 'restored_keep → %s\n' "$FLASH_DIR" >&2
  if [[ -f "$KEEP_DIR/KEEP_MANIFEST" ]]; then
    printf 'keep_manifest:\n' >&2
    sed 's/^/  /' "$KEEP_DIR/KEEP_MANIFEST" >&2
  fi
}

mark_keep_verified() {
  if ! installer_ready "$KEEP_DIR"; then
    return 0
  fi
  if [[ ! -f "$KEEP_DIR/KEEP_MANIFEST" ]]; then
    {
      printf 'promoted_at=%s\n' "$(date -Iseconds)"
      printf 'kind=unknown\n'
      printf 'verified_ssh=yes\n'
      printf 'verified_at=%s\n' "$(date -Iseconds)"
    } >"$KEEP_DIR/KEEP_MANIFEST"
    return 0
  fi
  # Rewrite verified fields without losing the rest.
  local tmp
  tmp="$(mktemp)"
  grep -vE '^(verified_ssh|verified_at)=' "$KEEP_DIR/KEEP_MANIFEST" >"$tmp" || true
  printf 'verified_ssh=yes\n' >>"$tmp"
  printf 'verified_at=%s\n' "$(date -Iseconds)" >>"$tmp"
  mv "$tmp" "$KEEP_DIR/KEEP_MANIFEST"
  printf 'keep_marked_verified dir=%s\n' "$KEEP_DIR" >&2
}

stage_recovery_flake() {
  # Optional: rewrite kiosk_url in a staged copy for P0-style device-smoke URL.
  local stage="$ROOT_DIR/device/.flash-flake-stage"
  rm -rf "$stage"
  mkdir -p "$stage"
  cp -a "$FLAKE_DIR/." "$stage/"
  # Replace kiosk_url assignment (single-line form used in this repo).
  if grep -q 'superbird.gui.kiosk_url' "$stage/flake.nix"; then
    sed -i \
      -e "s|superbird.gui.kiosk_url = \".*\";|superbird.gui.kiosk_url = \"${RECOVERY_KIOSK_URL}\";|" \
      "$stage/flake.nix"
  else
    fail "could not find superbird.gui.kiosk_url in staged flake"
  fi
  if ! grep -q 'manualScript' "$stage/flake.nix"; then
    fail "staged recovery flake missing manualScript"
  fi
  printf '%s\n' "$stage"
}

build_installer() {
  local recovery=0
  local flake_host_dir="$FLAKE_DIR"
  local flake_ref="$FLAKE_REF"
  local out_link="$ROOT_DIR/device/.installer-result"
  local result_path
  local flash_rel

  if [[ "${1:-}" == "--recovery" ]]; then
    recovery=1
  fi

  require_flake
  require_command python3

  if [[ "$recovery" -eq 1 ]]; then
    flake_host_dir="$(stage_recovery_flake)"
    flake_ref="path:/workdir?dir=device/.flash-flake-stage"
    LAST_BUILD_KIND="recovery"
    LAST_BUILD_KIOSK_URL="$RECOVERY_KIOSK_URL"
    printf 'note: recovery kiosk_url=%s\n' "$RECOVERY_KIOSK_URL" >&2
  else
    LAST_BUILD_KIND="production"
    LAST_BUILD_KIOSK_URL="$(
      grep -E 'superbird\.gui\.kiosk_url\s*=' "$FLAKE_DIR/flake.nix" \
        | head -1 \
        | sed -E 's/.*kiosk_url = "([^"]*)".*/\1/' || true
    )"
  fi

  printf 'Building installer (this can take a long time)...\n' >&2
  printf '  repo:    %s\n' "$ROOT_DIR" >&2
  printf '  flake:   %s\n' "$flake_host_dir" >&2
  printf '  out dir: %s\n' "$FLASH_DIR" >&2
  printf '  keep:    %s (updated on success)\n' "$KEEP_DIR" >&2

  # Stage a writable copy for make-bootfs + manual flash.
  # FLASH_DIR must live under ROOT_DIR so the builder can write it via /workdir.
  # Build + stage must share one run_builder container: each invocation is a
  # fresh --rm podman with only /workdir mounted, so a store path from a prior
  # container is gone by the time a second container tries to cp it.
  case "$FLASH_DIR" in
    "$ROOT_DIR"/*) ;;
    *)
      fail "PAPER_WEIGHT_FLASH_DIR must be under $ROOT_DIR (got $FLASH_DIR)"
      ;;
  esac
  flash_rel="${FLASH_DIR#"$ROOT_DIR"/}"
  rm -rf "$FLASH_DIR"
  mkdir -p "$FLASH_DIR"

  result_path="$(
    run_builder sh -eu -c '
      flake_ref="$1"
      flash_rel="$2"
      dest="/workdir/$flash_rel"
      src="$(
        nix build \
          "$flake_ref#nixosConfigurations.superbird.config.system.build.installer" \
          --no-link \
          --print-out-paths \
          --show-trace
      )"
      [ -n "$src" ] || { echo "installer build produced no store path" >&2; exit 1; }
      printf "installer=%s\n" "$src" >&2
      rm -rf "$dest"
      mkdir -p "$dest"
      cp -a "$src"/. "$dest"/
      chmod -R u+w "$dest"
      printf "%s\n" "$src"
    ' sh "$flake_ref" "$flash_rel"
  )"
  [[ -n "$result_path" ]] || fail "installer build produced no store path"
  printf 'installer=%s\n' "$result_path"

  [[ -f "$FLASH_DIR/rootfs.img" ]] || fail "missing $FLASH_DIR/rootfs.img after stage"
  [[ -f "$FLASH_DIR/env.txt" ]] || fail "missing $FLASH_DIR/env.txt after stage"
  [[ -d "$FLASH_DIR/builder" ]] || fail "missing $FLASH_DIR/builder after stage"
  [[ -d "$FLASH_DIR/manual" ]] ||
    fail "missing $FLASH_DIR/manual — enable superbird.installer.manualScript = true and rebuild"

  printf 'Building bootfs (needs sudo + loop device)...\n' >&2
  (
    cd "$FLASH_DIR"
    host_sudo ./scripts/make-bootfs.sh
  )
  [[ -f "$FLASH_DIR/bootfs.bin" ]] || fail "make-bootfs did not produce bootfs.bin"

  # Retain a local last-good copy so the next brick does not force a full rebuild.
  promote_keep "$FLASH_DIR" "$LAST_BUILD_KIND" "$LAST_BUILD_KIOSK_URL" "no"

  printf '\nInstaller ready:\n' >&2
  printf '  working: %s\n' "$FLASH_DIR" >&2
  printf '  keep:    %s\n' "$KEEP_DIR" >&2
  printf '  bootfs.bin rootfs.img env.txt manual/\n' >&2
  if [[ "$recovery" -eq 1 ]]; then
    printf '  kiosk_url (recovery): %s\n' "$RECOVERY_KIOSK_URL" >&2
  else
    printf '  kiosk_url (production): %s\n' "${LAST_BUILD_KIOSK_URL:-from flake}" >&2
  fi
  printf '\nNext:\n' >&2
  printf '  1. Hold top buttons 1+4, plug USB (burn mode)\n' >&2
  printf '  2. %s flash\n' "$ROOT_DIR/scripts/device-flash.sh" >&2
  printf '  Later reflash without rebuild: %s flash --from-keep\n' \
    "$ROOT_DIR/scripts/device-flash.sh" >&2
}

flash_device() {
  if ! installer_ready "$FLASH_DIR"; then
    if installer_ready "$KEEP_DIR"; then
      fail "no installer in $FLASH_DIR — run: $ROOT_DIR/scripts/device-flash.sh restore-keep   (or: flash --from-keep)"
    fi
    fail "no bootfs at $FLASH_DIR/bootfs.bin — run: $ROOT_DIR/scripts/device-flash.sh build"
  fi
  [[ -f "$FLASH_DIR/rootfs.img" ]] || fail "missing $FLASH_DIR/rootfs.img"
  [[ -f "$FLASH_DIR/manual/manual.sh" ]] || fail "missing $FLASH_DIR/manual/manual.sh"
  require_command python3

  printf '\n*** DESTRUCTIVE: overwrites Car Thing boot + root filesystems ***\n' >&2
  printf 'Installer dir: %s\n' "$FLASH_DIR" >&2
  printf '\nPut the device in USB burn mode:\n' >&2
  printf '  Hold top buttons 1 and 4 while plugging in USB.\n' >&2
  printf '  (Not normal NCM gadget mode.)\n\n' >&2

  if [[ "${PAPER_WEIGHT_FLASH_YES:-0}" != "1" ]]; then
    read -r -p "Type YES to flash: " confirm
    [[ "$confirm" == "YES" ]] || fail "aborted (expected YES)"
  fi

  # manual.sh creates a venv + installs pyamlboot, then sudo-runs manual.py
  (
    cd "$FLASH_DIR"
    # Prefer host network/python for pyamlboot USB access.
    if [[ -n "${CONTAINER_ID:-}" ]] && command -v distrobox-host-exec >/dev/null 2>&1; then
      # Run the entire flash dir steps on the host so pyusb sees the device.
      host_flash="$(host_bind_path "$FLASH_DIR")"
      distrobox-host-exec bash -lc "
        set -euo pipefail
        cd '$host_flash'
        if [[ ! -d .venv ]]; then
          python3 -m venv .venv
          .venv/bin/python3 -m pip install --upgrade pip 'git+https://github.com/superna9999/pyamlboot'
        fi
        chmod 600 ./ssh/* 2>/dev/null || true
        chmod +x ./scripts/*.sh ./manual/*.sh 2>/dev/null || true
        sudo .venv/bin/python3 ./manual/manual.py
      "
    else
      if [[ ! -d .venv ]]; then
        python3 -m venv .venv
        # shellcheck disable=SC1091
        source .venv/bin/activate
        python3 -m pip install --upgrade pip 'git+https://github.com/superna9999/pyamlboot'
      else
        # shellcheck disable=SC1091
        source .venv/bin/activate
      fi
      chmod 600 ./ssh/* 2>/dev/null || true
      chmod +x ./scripts/*.sh ./manual/*.sh 2>/dev/null || true
      host_sudo ./.venv/bin/python3 ./manual/manual.py
    fi
  )

  printf '\nFlash write finished. Power-cycle the Car Thing, then run:\n' >&2
  printf '  %s wait\n' "$ROOT_DIR/scripts/device-flash.sh" >&2
}

find_gadget_iface() {
  local iface
  # Prefer the well-known USB path name from this machine, then any cdc_ncm-like name.
  for iface in enp0s20f0u3u3; do
    if [[ -d "/sys/class/net/$iface" ]]; then
      printf '%s\n' "$iface"
      return 0
    fi
  done
  for iface in /sys/class/net/*; do
    iface="${iface##*/}"
    case "$iface" in
      enx*|enp*u*|usb*)
        printf '%s\n' "$iface"
        return 0
        ;;
    esac
  done
  return 1
}

ensure_host_ip() {
  local iface
  if ip -4 address show 2>/dev/null | grep -Fq "inet $HOST_IP/"; then
    printf 'host_ip=%s (already assigned)\n' "$HOST_IP"
    return 0
  fi
  iface="$(find_gadget_iface)" || fail "no USB gadget iface yet — is the device plugged and booted?"
  printf 'assigning %s/24 on %s\n' "$HOST_IP" "$iface"
  host_sudo ip link set "$iface" up
  host_sudo ip addr replace "$HOST_IP/24" dev "$iface"
}

wait_for_ssh() {
  local attempts="${1:-90}"
  local attempt
  local iface

  printf 'Waiting for device at %s (up to %ss)...\n' "$DEVICE_IP" "$((attempts * 2))" >&2

  for ((attempt = 1; attempt <= attempts; attempt += 1)); do
    if find_gadget_iface >/dev/null 2>&1; then
      ensure_host_ip || true
    fi
    if ping -c 1 -W 1 "$DEVICE_IP" >/dev/null 2>&1; then
      if ssh \
        -F /dev/null \
        -o BatchMode=yes \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "$DEVICE_TARGET" true 2>/dev/null; then
        printf 'ssh_ok target=%s attempt=%s\n' "$DEVICE_TARGET" "$attempt"
        ssh \
          -F /dev/null \
          -o BatchMode=yes \
          -o ConnectTimeout=5 \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          "$DEVICE_TARGET" \
          'printf "kiosk_url="; cat /etc/kiosk_url 2>/dev/null; printf "\nuptime="; cut -d. -f1 /proc/uptime; printf "s\n"'
        # SSH after flash is the strongest "this installer is good" signal.
        if installer_ready "$FLASH_DIR"; then
          promote_keep "$FLASH_DIR" "${LAST_BUILD_KIND:-unknown}" "${LAST_BUILD_KIOSK_URL:-}" "yes" || true
        else
          mark_keep_verified || true
        fi
        printf '\nDevice is back. Chromium kiosk should show host URL (error page if host UI is down).\n' >&2
        printf 'Optional host UI:\n' >&2
        printf '  %s\n' "$ROOT_DIR/scripts/run-device-fixture.sh" >&2
        return 0
      fi
    fi
    sleep 2
  done

  fail "device did not answer SSH at $DEVICE_TARGET after $((attempts * 2))s"
}

flash_status() {
  printf 'ROOT_DIR=%s\n' "$ROOT_DIR"
  printf 'FLASH_DIR=%s\n' "$FLASH_DIR"
  if installer_ready "$FLASH_DIR"; then
    printf 'installer=ready\n'
  else
    printf 'installer=missing (run build, or restore-keep)\n'
  fi
  printf 'KEEP_DIR=%s\n' "$KEEP_DIR"
  if installer_ready "$KEEP_DIR"; then
    printf 'keep=ready\n'
    if [[ -f "$KEEP_DIR/KEEP_MANIFEST" ]]; then
      sed 's/^/keep_/' "$KEEP_DIR/KEEP_MANIFEST"
    fi
    if command -v du >/dev/null 2>&1; then
      printf 'keep_size=%s\n' "$(du -sh "$KEEP_DIR" 2>/dev/null | awk '{print $1}')"
    fi
  else
    printf 'keep=missing (will be created on next successful build)\n'
  fi
  if iface="$(find_gadget_iface 2>/dev/null)"; then
    printf 'gadget_iface=%s\n' "$iface"
    printf 'carrier=%s\n' "$(cat "/sys/class/net/$iface/carrier" 2>/dev/null || echo unknown)"
    ip -br addr show "$iface" 2>/dev/null || true
  else
    printf 'gadget_iface=none\n'
  fi
  if ping -c 1 -W 1 "$DEVICE_IP" >/dev/null 2>&1; then
    printf 'ping_%s=ok\n' "$DEVICE_IP"
  else
    printf 'ping_%s=fail\n' "$DEVICE_IP"
  fi
}

[[ $# -ge 1 ]] || {
  usage >&2
  exit 1
}

case "$1" in
  build)
    shift
    build_installer "${1:-}"
    ;;
  flash)
    shift
    if [[ "${1:-}" == "--from-keep" ]]; then
      restore_keep_to_flash
      shift
    fi
    [[ $# -eq 0 ]] || fail "flash accepts only optional --from-keep"
    flash_device
    ;;
  wait)
    [[ $# -eq 1 ]] || fail "wait takes no arguments"
    wait_for_ssh
    ;;
  keep)
    [[ $# -eq 1 ]] || fail "keep takes no arguments"
    # Prefer manifest kind if re-promoting an already-labeled tree.
    LAST_BUILD_KIND="${LAST_BUILD_KIND:-manual}"
    LAST_BUILD_KIOSK_URL="${LAST_BUILD_KIOSK_URL:-}"
    promote_keep "$FLASH_DIR" "$LAST_BUILD_KIND" "$LAST_BUILD_KIOSK_URL" "no"
    ;;
  restore-keep)
    [[ $# -eq 1 ]] || fail "restore-keep takes no arguments"
    restore_keep_to_flash
    ;;
  all)
    [[ $# -eq 1 ]] || fail "all takes no arguments"
    build_installer --recovery
    flash_device
    printf '\nPower-cycle the device now if it has not rebooted itself.\n' >&2
    wait_for_ssh
    ;;
  status)
    [[ $# -eq 1 ]] || fail "status takes no arguments"
    flash_status
    ;;
  -h | --help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
