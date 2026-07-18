# Feature: platform

Foundation for all screens. Stack decision lives in `docs/architecture/workflow-v1.md` (P1).

## Cards

| ID | Issue | Title | Status |
|----|-------|-------|--------|
| P0-1 | [#22](https://github.com/rorybot/paper-weight/issues/22) | Device bootstrap — backup, flash, shell | **Done** (closed) |
| P0 | [#21](https://github.com/rorybot/paper-weight/issues/21) | Device smoke — kiosk + presets 1–4 → mock frames | **Done** (closed) |
| P1 | [#2](https://github.com/rorybot/paper-weight/issues/2) | Architecture spike — runtime & stack | **Done** (closed) |
| P2 | [#1](https://github.com/rorybot/paper-weight/issues/1) | Input daemon — evdev → event bus | **Done** (closed) |
| P3 | [#3](https://github.com/rorybot/paper-weight/issues/3) | Screen shell — router, overlays, back stack | **Done** (closed) |
| P3-1 | [#23](https://github.com/rorybot/paper-weight/issues/23) | Fix swapped preset 2/3 preview routing | **Done** (closed) |
| P4 | [#4](https://github.com/rorybot/paper-weight/issues/4) | BERG design system tokens + card component | **Done** (closed) |
| P5 | [#5](https://github.com/rorybot/paper-weight/issues/5) | 1-bit Atkinson dither utility | **Done** (approved and closed) |
| W3-P1 | [#43](https://github.com/rorybot/paper-weight/issues/43) | Protocol v1.1 — freeze playlist channel | **In review** (PR #53) |

## Stack slice (do not re-litigate)

- Device UI: Preact + TS + Tailwind, pure screens.
- Device input: evdev bridge → typed bus.
- Host: Elixir services + dither.
- Protocol: WS JSON v1.

## Next Session Context Chunk (2026-07-16 hygiene)

- GH + `kanban/board.md` + this table: Done P0-1/P0/P1/P2/P3/P3-1/P4/P5; rest Backlog/Ready by lane.
- Prefer `scripts/set-card-status.ps1`; do not claim status via local edit alone.
- **P0-1 #22** is Done: owner accepted the completed device bootstrap and successful P0 run.

## Next Session Context Chunk (P3 — 2026-07-16)

- Shell lives in `src/device-ui/src/shell/`: pure `routeShellInput`, `ScreenShell`, `ShellApp` harness.
- Interaction map (design §Interaction) covered in `router.navigation.test.ts`; P2 JSON v1 via `bridge.ts`; host keys via `devKeyboard.ts`.
- Wheel turns do **not** reset `konamiIndex` (sequence can complete alongside volume/scroll).
- Settings: presets inactive; back exits (history or home). Feed enlarge / NP lyrics are overlays.
- Validate: `cd src/device-ui && npm run check` (41 tests). Dev: `npm run dev` · `?bridge=0` skips SSE.
- #3 closed + project Status Done. Next: screen cards (N1/W1/…).

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

## Next Session Context Chunk (P0-1 closeout - 2026-07-16)
- #22 is closed and its GitHub project Status is verified Done.
- Owner accepted flash, shell, transfer, Chromium, and the successful P0 hardware run as sufficient.
- No further platform P-cards remain; P0-1 and P0–P5 are all Done.
- Next implementation work is one Ready lane card: N1 #6, W1 #9, or F1 #12.

## Next Session Context Chunk (P3-1 - 2026-07-16)
- Presets now route 2 to Playlist and 3 to Weather in both the Preact shell and standalone device-smoke preview; presets 1 and 4 are unchanged.
- Router regression cases carry explicit product expectations, and keyboard tests cover both Digit2 and Digit3; the evdev bridge remains untouched.
- `cd src/device-ui && npm run check` passes typecheck, 53 tests, and production build; a static smoke assertion also verifies both frame paths.
- GitHub Project card #23 is Done, issue #23 is closed, and the isolated implementation branch is `fix/23-preset-2-3-routing`.

## Next Session Context Chunk (W3-P1 — 2026-07-17)
- `playlist` is now a first-class `ChannelV1` member (protocol doc v1.1, `envelope.ex`, `envelope.ts`); envelope fields themselves are untouched.
- Payload stays `PlaylistSnapshotV1` from `src/device-ui/src/protocol/playlist.ts` (unchanged shape); doc now documents the Elixir-side map mirror for host authors.
- No service/screen code touched — W3-A/B and the rest of wave 3 can now build against `channel: :playlist` / `"playlist"`.
- `mix test` (100 passed) and `npm run check` (typecheck + 130 tests + build) both green; branch `chore/w3p1-playlist-channel`, PR #53, issue #43 set to In review pending CI + merge.
