# Feature: platform

Foundation for all screens. Stack decision lives in `docs/architecture/workflow-v1.md` (P1).

## Cards

| ID | Issue | Title | Status |
|----|-------|-------|--------|
| P0-1 | [#22](https://github.com/rorybot/paper-weight/issues/22) | Device bootstrap — backup, flash, shell | **Ready** |
| P0 | [#21](https://github.com/rorybot/paper-weight/issues/21) | Device smoke — kiosk + presets 1–4 → mock frames | **Done** (closed) |
| P1 | [#2](https://github.com/rorybot/paper-weight/issues/2) | Architecture spike — runtime & stack | **Done** (closed) |
| P2 | [#1](https://github.com/rorybot/paper-weight/issues/1) | Input daemon — evdev → event bus | **Done** (closed) |
| P3 | [#3](https://github.com/rorybot/paper-weight/issues/3) | Screen shell — router, overlays, back stack | **In progress** (integrating against P2 events) |
| P4 | [#4](https://github.com/rorybot/paper-weight/issues/4) | BERG design system tokens + card component | **Done** (closed) |
| P5 | [#5](https://github.com/rorybot/paper-weight/issues/5) | 1-bit Atkinson dither utility | **Done** (approved and closed) |

## Stack slice (do not re-litigate)

- Device UI: Preact + TS + Tailwind, pure screens.
- Device input: evdev bridge → typed bus.
- Host: Elixir services + dither.
- Protocol: WS JSON v1.

## Next Session Context Chunk (2026-07-16 board tidy)

- GH project + `kanban/board.md` realigned: P2 demoted Ready; P5 → In progress; P0-1 promoted to #22.
- **P0 / P0-1**: hardware path — bootstrap then on-device smoke; desktop preflight already in `device-smoke/`.
- **P5**: implementation + golden tests approved; #5 is Done and closed.
- **P2**: native input bridge complete; versioned event contract and fake-evdev acceptance are validated.
- Prefer `scripts/set-card-status.ps1`; do not claim status via local edit alone.

## Next Session Context Chunk (P5)

- P5 is implemented in `host/`: grayscale image -> centered cover resize -> pure Atkinson -> packed 1-bit bitmap/PBM.
- The OTP cache keys content + target size + threshold; callers can inject an isolated cache or bypass it.
- Validation: `mix format --check-formatted` + `mix test --warnings-as-errors` pass (11 tests, including golden PBM).
- Full 800x480 uncached benchmark in Arch WSL: ~840 ms; JPEG/PNG adapters only need to supply 8-bit luma pixels.
- User approved P5; remote #5 is closed and project status is verified Done.

## Next Session Context Chunk (P4 — 2026-07-16)
- `src/device-ui` implements immutable BERG/gruvbox tokens, bundled typefaces, and the reusable `Card` recipe.
- `FeedSample` is a fixed 800×480 acceptance fixture based only on `spec/feed-4f.png`.
- Validation passes: typecheck + 6 tests + production build; headless 800×480 render visually checked.
- GitHub project P4 is verified Done and issue #4 is closed; implementation remains uncommitted locally.

## Next Session Context Chunk (P0 — 2026-07-16)

- Physical Car Thing flashed via nixos-superbird using the manual pyamlboot fallback path (Terbium
  browser flash crashed on a WASM libarchive error); BL2's mid-flash USB re-enumeration required a
  persistent `usbipd` auto-bind policy + watcher to survive, not just one-off rebinds.
- Windows has no driver for the Linux USB gadget's CDC-NCM interface (no MS OS descriptor, so
  `usbncm.inf` never matches) — the gadget network only works by passing the NCM USB device through
  `usbipd` into WSL, where the native `cdc_ncm` driver binds it directly.
- Kiosk confirmed loading `http://172.16.42.1:8080/device-smoke/` (served from WSL) at exact
  800×480 (verified via CDP `Page.getLayoutMetrics`); Chromium 131 runs software-only
  (`--disable-gpu`, SwiftShader WebGL), MemAvailable ~200Mi while running.
- All 4 presets verified individually (isolated capture + screenshot per button) via CDP over an
  SSH-forwarded remote-debugging port (device only binds it to `127.0.0.1`, so `--remote-debugging-address`
  is ignored — forward with `ssh -L 9222:127.0.0.1:9222`). `gpio-keys` already emits standard
  `KEY_1`–`KEY_4` on `/dev/input/event0`; no P0 injector needed. GO verdict recorded in
  `docs/architecture/device-smoke.md`; #21 closed and project Status set to Done.
- Other input nodes seen but unexercised: `event1` rotary (wheel), `event2` aml_vkeypad (unknown),
  `event3` tlsc6x_dbg (touchscreen) — relevant for P2/P3.
## Next Session Context Chunk (P2 — 2026-07-16)
- `src/input-bridge/` is a dependency-free Rust evdev daemon with configurable device codes and hold timing.
- P3 subscribes at loopback SSE `/v1/events`; JSON v1 covers wheel, wheel press, presets, home, and back.
- `bash scripts/check.sh` passes 14 tests, strict Clippy, and all-target aarch64 compilation.
- GitHub project P2 is verified Done and issue #1 is closed; implementation remains uncommitted locally.
