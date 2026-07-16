#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-/tmp/paper-weight-p2-target}"

cargo fmt --check --manifest-path "$ROOT_DIR/Cargo.toml"
env CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=rust-lld \
  cargo test --target x86_64-unknown-linux-musl --manifest-path "$ROOT_DIR/Cargo.toml"
env CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=rust-lld \
  cargo clippy --target x86_64-unknown-linux-musl --all-targets \
  --manifest-path "$ROOT_DIR/Cargo.toml" -- -D warnings
cargo check --target aarch64-unknown-linux-gnu --all-targets \
  --manifest-path "$ROOT_DIR/Cargo.toml"
