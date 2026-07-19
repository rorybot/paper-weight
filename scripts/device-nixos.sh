#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FLAKE_REF="path:/workdir?dir=device/nix"
BUILDER_IMAGE="${PAPER_WEIGHT_NIX_BUILDER:-ghcr.io/joeyeamigh/nixos-superbird/builder:latest}"
DEVICE_TARGET="${PAPER_WEIGHT_DEVICE_TARGET:-root@172.16.42.2}"
SYSTEM_PROFILE="/nix/var/nix/profiles/system"
EXPECTED_KIOSK_URL="http://172.16.42.1:8080/?gateway=ws://172.16.42.1:9138/"
NIXBUILD_HOST="eu.nixbuild.net"
NIXBUILD_HOST_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM"
# Default key location (host path). Override with PAPER_WEIGHT_NIXBUILD_KEY.
NIXBUILD_KEY_DEFAULT="${HOME}/.ssh/my-nixbuild-key"
# PAPER_WEIGHT_NIXBUILD: auto | 1 | 0  (auto = use key if present)
NIXBUILD_MODE="${PAPER_WEIGHT_NIXBUILD:-auto}"
BUILDER_OUTPUT_DIR=""

usage() {
  cat <<'EOF'
Usage: scripts/device-nixos.sh <command> [generation]

  evaluate              Evaluate the flake, deploy schema, and kiosk URL
  build-input-bridge    Build only the aarch64 bridge candidate outside the worktree
  build                 Build the NixOS system through the upstream builder
  deploy                Build and activate a new generation on the Car Thing
  status                Show current/available generations and kiosk service state
  reboot                Reboot, wait for SSH, then show status
  rollback              Activate the immediately previous generation
  activate <generation> Select and activate an existing generation

Environment:
  PAPER_WEIGHT_NIX_BUILDER     Builder image override
  PAPER_WEIGHT_DEVICE_TARGET   SSH target override (default root@172.16.42.2)
  PAPER_WEIGHT_PODMAN          Podman binary override
  PAPER_WEIGHT_NIXBUILD        auto|1|0 — use nixbuild.net remote builders (default auto)
  PAPER_WEIGHT_NIXBUILD_KEY    Path to Ed25519 private key (default ~/.ssh/my-nixbuild-key)
  PAPER_WEIGHT_ARTIFACT_DIR    Host directory for package-only build artifacts
EOF
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

# Map a path from this environment to a path Podman on the host can bind-mount.
host_bind_path() {
  local path="$1"
  if [[ -n "${CONTAINER_ID:-}" ]]; then
    printf '%s\n' "${path#/run/host}"
  else
    printf '%s\n' "$path"
  fi
}

resolve_nixbuild_key() {
  local key="${PAPER_WEIGHT_NIXBUILD_KEY:-$NIXBUILD_KEY_DEFAULT}"
  # Inside distrobox, HOME may be the box home; prefer host key when present.
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
  local builder_output_host=""
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
        printf 'note: nixbuild disabled (no key at %s; set PAPER_WEIGHT_NIXBUILD_KEY or PAPER_WEIGHT_NIXBUILD=0)\n' \
          "$nixbuild_key" >&2
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

  if [[ -n "$BUILDER_OUTPUT_DIR" ]]; then
    mkdir -p "$BUILDER_OUTPUT_DIR"
    builder_output_host="$(host_bind_path "$BUILDER_OUTPUT_DIR")"
    podman_args+=(--volume "$builder_output_host:/output")
  fi

  if [[ "$use_nixbuild" -eq 1 ]]; then
    nixbuild_key_host="$(host_bind_path "$nixbuild_key")"
    printf 'note: nixbuild enabled (key=%s → %s)\n' "$nixbuild_key" "$NIXBUILD_HOST" >&2
    podman_args+=(--volume "$nixbuild_key_host:/run/paper-weight/nixbuild-key:ro")
    # Setup SSH + NIX_CONFIG, then exec the real builder command.
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

ssh_device() {
  require_command ssh
  ssh \
    -F /dev/null \
    -o BatchMode=yes \
    -o ConnectTimeout=8 \
    -o LogLevel=ERROR \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "$DEVICE_TARGET" \
    "$@"
}

device_status() {
  ssh_device "
    set -eu
    printf 'current_system=%s\\n' \"\$(readlink -f /run/current-system)\"
    printf 'profile_system=%s\\n' \"\$(readlink -f $SYSTEM_PROFILE)\"
    nix-env --profile $SYSTEM_PROFILE --list-generations
    printf 'weston_active='
    systemctl is-active weston-tty1.service
    printf 'weston_enabled='
    systemctl is-enabled weston-tty1.service
    printf 'input_bridge_active='
    systemctl is-active input-bridge.service
    printf 'input_bridge_enabled='
    systemctl is-enabled input-bridge.service
    printf 'kiosk_url='
    cat /etc/kiosk_url
    printf 'uptime_seconds='
    cut -d. -f1 /proc/uptime
  "
}

evaluate_flake() {
  local actual_url

  actual_url="$(
    run_builder sh -eu -c '
      flake_ref="$1"
      nix flake check "$flake_ref" --show-trace 1>&2
      nix eval \
        --raw \
        "$flake_ref#nixosConfigurations.superbird.config.environment.etc.kiosk_url.text"
    ' sh "$FLAKE_REF"
  )"
  [[ "$actual_url" == "$EXPECTED_KIOSK_URL" ]] ||
    fail "evaluated kiosk URL does not match the production URL"
  printf 'kiosk_url=%s\n' "$actual_url"
}

build_system() {
  run_builder nix build \
    "$FLAKE_REF#nixosConfigurations.superbird.config.system.build.toplevel" \
    --no-link \
    --print-out-paths \
    --show-trace
}

build_input_bridge() {
  local artifact_dir
  local artifact_path

  if [[ -n "${PAPER_WEIGHT_ARTIFACT_DIR:-}" ]]; then
    artifact_dir="$PAPER_WEIGHT_ARTIFACT_DIR"
  else
    artifact_dir="${XDG_CACHE_HOME:-$HOME/.cache}/paper-weight/input-bridge"
  fi
  mkdir -p "$artifact_dir"
  artifact_dir="$(cd "$artifact_dir" && pwd)"
  artifact_path="$artifact_dir/input_bridge"

  BUILDER_OUTPUT_DIR="$artifact_dir" run_builder sh -eu -c '
    flake_ref="$1"
    output="$(
      nix build \
        "$flake_ref#nixosConfigurations.superbird.config.system.build.paperWeightInputBridge" \
        --no-link \
        --print-out-paths \
        --show-trace
    )"
    install -Dm755 "$output/bin/input_bridge" /output/input_bridge
  ' sh "$FLAKE_REF"
  printf 'input_bridge=%s\n' "$(host_bind_path "$artifact_path")"
}

restore_kiosk_tty() {
  # Current generations declare tty1 ownership. This also keeps activate and
  # rollback safe when selecting an older generation without that declaration.
  ssh_device "
    set -eu
    systemctl stop getty@tty1.service
    systemctl start weston-tty1.service
  "
}

deploy_system() {
  printf '%s\n' "Before deployment:"
  device_status
  run_builder sh -eu -c '
    flake_ref="$1"
    deploy_source="$(
      nix eval \
        --impure \
        --raw \
        --expr "(builtins.getFlake \"$flake_ref\").inputs.deploy-rs.outPath"
    )"
    nix run "path:$deploy_source" -- \
      "$flake_ref#superbird" \
      --ssh-opts "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
  ' sh "$FLAKE_REF"
  restore_kiosk_tty
  printf '%s\n' "After deployment:"
  device_status
}

wait_for_device() {
  local attempts="${1:-60}"
  local attempt

  for ((attempt = 1; attempt <= attempts; attempt += 1)); do
    if ssh_device true 2>/dev/null; then
      return 0
    fi
    sleep 2
  done

  fail "device did not return over SSH after $((attempts * 2)) seconds"
}

reboot_device() {
  ssh_device systemctl reboot || true
  sleep 2
  wait_for_device
  restore_kiosk_tty
  device_status
}

activate_profile() {
  local selection="$1"

  ssh_device "
    set -eu
    nix-env --profile $SYSTEM_PROFILE --switch-generation '$selection'
    $SYSTEM_PROFILE/bin/switch-to-configuration switch
  "
  restore_kiosk_tty
  device_status
}

rollback_profile() {
  local before
  local after

  before="$(ssh_device "readlink -f $SYSTEM_PROFILE")"
  ssh_device "
    set -eu
    nix-env --profile $SYSTEM_PROFILE --rollback
    $SYSTEM_PROFILE/bin/switch-to-configuration switch
  "
  after="$(ssh_device "readlink -f $SYSTEM_PROFILE")"
  [[ "$after" != "$before" ]] || fail "rollback did not select a different generation"
  restore_kiosk_tty
  device_status
}

[[ $# -ge 1 ]] || {
  usage >&2
  exit 1
}

case "$1" in
  evaluate)
    [[ $# -eq 1 ]] || fail "evaluate takes no arguments"
    evaluate_flake
    ;;
  build-input-bridge)
    [[ $# -eq 1 ]] || fail "build-input-bridge takes no arguments"
    build_input_bridge
    ;;
  build)
    [[ $# -eq 1 ]] || fail "build takes no arguments"
    build_system
    ;;
  deploy)
    [[ $# -eq 1 ]] || fail "deploy takes no arguments"
    deploy_system
    ;;
  status)
    [[ $# -eq 1 ]] || fail "status takes no arguments"
    device_status
    ;;
  reboot)
    [[ $# -eq 1 ]] || fail "reboot takes no arguments"
    reboot_device
    ;;
  rollback)
    [[ $# -eq 1 ]] || fail "rollback takes no arguments"
    rollback_profile
    ;;
  activate)
    [[ $# -eq 2 ]] || fail "activate requires a generation number"
    [[ "$2" =~ ^[0-9]+$ ]] || fail "generation must be a positive integer"
    activate_profile "$2"
    ;;
  -h | --help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
