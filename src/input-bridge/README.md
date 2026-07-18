# P2 input bridge

## Contract

| Raw input | Published JSON |
|---|---|
| Wheel relative movement | `{"v":1,"type":"wheel","ticks":-2}` |
| Wheel press | `{"v":1,"type":"wheel_press"}` |
| Preset short press | `{"v":1,"type":"preset","number":1}` |
| Configured preset hold | `{"v":1,"type":"home"}` |
| Back press | `{"v":1,"type":"back"}` |

- Browser/P3 subscription endpoint: `http://127.0.0.1:9137/v1/events` via `EventSource`.
- SSE accepts only `file://` (`Origin: null`) and loopback-hosted UI origins.
- The listener rejects non-loopback addresses.
- Evdev disconnects reset held-key state and retry with bounded backoff from 250ms to 5s.
- `home_hold`, `hold_ms`, and `debounce_ms` are configuration values; any bound key can be hold-capable.
- Preset actions emit on release; reaching `hold_ms` emits Home once and consumes the short press.
- Linux key repeats and duplicate presses do not duplicate events.

## Device configuration

1. Copy `input-bridge.example.conf` to `/etc/paper-weight/input-bridge.conf`.
2. Replace every numeric binding with the physical P0 `evtest` mapping.
3. Install the release binary at `/opt/paper-weight/bin/input_bridge`.
4. Install and enable `systemd/input-bridge.service`.

The example codes are test-fixture values, not claimed Car Thing hardware mappings.

## Validation

| Command | Purpose |
|---|---|
| `rustup component add rustfmt clippy` | Install formatting and lint components once. |
| `rustup target add x86_64-unknown-linux-musl aarch64-unknown-linux-gnu` | Install self-contained test and device-check targets once. |
| `bash scripts/check.sh` | Format check, full test suite, strict Clippy, and aarch64 compile check. |
