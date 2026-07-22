# P2 input bridge

## Contract

| Raw input | Published JSON |
|---|---|
| Wheel relative movement | `{"v":1,"type":"wheel","ticks":-2}` |
| Wheel short press | `{"v":1,"type":"wheel_press"}` |
| Wheel held ≥ `wheel_hold_ms` | `{"v":1,"type":"wheel_long_press"}` |
| Preset short press | `{"v":1,"type":"preset","number":1}` |
| Configured preset hold | `{"v":1,"type":"home"}` |
| Back press | `{"v":1,"type":"back"}` |

- Browser/P3 subscription endpoint: `http://127.0.0.1:9137/v1/events` via `EventSource`.
- SSE accepts only `file://` (`Origin: null`) and loopback-hosted UI origins.
- The listener rejects non-loopback addresses.
- `devices` accepts a comma-separated evdev path list; legacy single-path `device` remains valid.
- Evdev disconnects reset held-key state and retry with bounded backoff from 250ms to 5s.
- `home_hold`, `hold_ms`, and `debounce_ms` are configuration values; any bound key can be hold-capable.
- Preset actions emit on release; reaching `hold_ms` emits Home once and consumes the short press.
- The wheel-press key is always hold-capable: `wheel_hold_ms` (default 3000ms) gates when a held
  wheel press emits `wheel_long_press` once instead of, on release, the short `wheel_press`.
- Linux key repeats and duplicate presses do not duplicate events.

## Device configuration

1. Import `device/nix/input-bridge.nix` in the device flake.
2. Configure every evdev path and numeric binding from the physical mapping.
3. Build a physical-test candidate with `scripts/device-nixos.sh build-input-bridge`.
4. After acceptance, deploy with `scripts/device-nixos.sh deploy`.

The example codes are test-fixture values, not claimed Car Thing hardware mappings.

## Validation

| Command | Purpose |
|---|---|
| `rustup component add rustfmt clippy` | Install formatting and lint components once. |
| `rustup target add x86_64-unknown-linux-musl aarch64-unknown-linux-gnu` | Install self-contained test and device-check targets once. |
| `bash scripts/check.sh` | Format check, full test suite, strict Clippy, and aarch64 compile check. |
