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
| W3-P1 | [#43](https://github.com/rorybot/paper-weight/issues/43) | Protocol v1.1 — freeze playlist channel | **Done** (closed, PR #53) |
| W3-A | [#44](https://github.com/rorybot/paper-weight/issues/44) | Device shell screen map + channel store | **Done** (closed, PR #59) |
| W3-B | [#45](https://github.com/rorybot/paper-weight/issues/45) | Host deps, Application children, and runtime config | **Done** (closed, PR #58) |
| W3-C | [#46](https://github.com/rorybot/paper-weight/issues/46) | Host WebSocket gateway snapshot push | **Done** (closed, PR #68) |

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

## Next Session Context Chunk (W3-A — 2026-07-18)

- `shell/channelStore.ts` is a pure `ChannelV1 → snapshot` store: `applyEnvelope` rejects `gen <=`
  the stored generation per channel and ignores unmanaged channels (`system`, `etymology`, and any
  unknown wire value); `fixtureChannelStoreState` seeds `now_playing`/`weather`/`feed`/`photo`/`playlist`.
- `ShellApp.tsx` now renders the real Now Playing, Weather, Feed, Photo, Playlist, and Settings
  screens plus the Lyrics/feed-detail overlays from that one store (weather was folded in too —
  don't reintroduce a second `weatherSnapshot`-only path). `etymology` stays a placeholder; no E2
  screen exists yet. New `onIntent` prop is a plumbed-but-unconsumed no-op until W3-D's gateway.
- `npm run check` (typecheck + 146 tests + build) is green; dev server boots clean and every
  changed module transforms via Vite with no errors — but no headless browser exists in this
  environment, so live wheel/press click-through was **not** exercised interactively.
- PR #59 open on `feat/w3a-shell-screen-map`, issue #44 set to In review. Next: wait for CI `ci`
  check + merge, then flip GitHub Status → Done, `gh issue close 44`, and update this table +
  `kanban/board.md` (currently show In review). W3-C #46 and W3-D #47 unblock once this merges.

## Next Session Context Chunk (W3-B — 2026-07-18)
- `PaperWeight.Application` is now a pure `children/1` (config map `%{weather:, spotify:, feed:, photo:, photo_library_dir:}` → child specs) plus impure `config_from_env/0`. `start/2` just wires the two together.
- Weather defaults `:enabled`; Spotify/Feed/Photo default `:disabled` in `config.exs`, and all four are forced `:disabled` under `MIX_ENV=test` so `mix test` needs zero credentials/network.
- `Photo.Config` has no `from_env/0` of its own (unlike Weather/Feed/Spotify, which read env inside their own `Config.new/1`), so `Application` reads `PAPER_WEIGHT_PHOTO_LIBRARY_DIR` directly and passes it as `:library_dir`.
- `mix.exs`/`mix.lock` now lock `bandit ~> 1.5`, `websock_adapter ~> 0.5`, `plug ~> 1.16` — compiled only, nothing starts Bandit (that's W3-C's job: wire the actual listener/socket).
- New `host/test/paper_weight/application_test.exs` covers zero-env, all-enabled (4 child specs), per-service isolation, photo `library_dir` plumbing, and a `start_supervised!` smoke test for the Photo child spec; existing `application_weather_test.exs` untouched and still green.
- PR #58 (`feat/w3b-host-app-children`) merged (squash, ff to master); `ci` required check green with `host`/`lane-guard` passing and product-lane jobs (device-ui/input-bridge/screen-tests) correctly skipped — confirms no `cross-lane` label was needed. Issue #45 closed, Status Done.
- Unblocked next: W3-C (wire the actual Bandit/websock_adapter listener + socket) can now build on `PaperWeight.Application`'s per-service `:enabled`/`:disabled` config and the locked WS deps.

## Next Session Context Chunk (W3-C — 2026-07-18)
- New `host/lib/paper_weight/gateway/{publisher,socket,endpoint,playlist_stub}.ex`: `Publisher.envelopes/2` is a pure `inputs → [Envelope.t()]` assembler (each channel is `{:ok, payload, gen} | :disabled | {:error, _}`, disabled/errored channels are simply omitted); `Socket` (WebSock behaviour) is the impure edge — collects inputs via each service's real API (`get_snapshot/1`+`get_gen/1` for weather/photo, `now_playing/1`+`get_gen/1` for spotify, `current/1` for feed), pushes all channels on connect, then polls every 1s and re-pushes only channels whose `gen` advanced; dead/unavailable adapters degrade to `:disabled` via a `catch :exit` rather than crashing the socket. `playlist` is an always-on stub (`gen: 1`, empty list) per W3-G being unbuilt. Inbound frames are dropped (`handle_in` is a no-op — W3-E's job).
- `PaperWeight.Application` gained one more per-service key: `gateway: :enabled | :disabled` + `gateway_port` (default 9138), `:disabled` in `config.exs`'s `MIX_ENV=test` block alongside the other four — so `mix test` still opens no port. `gateway_child/1` builds the `Bandit` child spec with `adapters` built only from the services that are themselves `:enabled` (disabled service → `nil` adapter, gateway omits that channel).
- No `mix.exs`/`mix.lock` edits — W3-B's locked `bandit`/`websock_adapter`/`plug` deps compiled as-is; JSON encoding uses Elixir 1.20's built-in `JSON.encode!/1` (no `Jason` dep needed/added).
- Verified live: `WEATHER_LAT=40.0 WEATHER_LON=-74.0 MIX_ENV=dev mix run --no-halt`, then an HTTP `Upgrade: websocket` `curl` to `localhost:9138/` completed the 101 handshake and received one `playlist` envelope frame immediately (weather/spotify/feed/photo all omitted — weather fetch fails with no real network/creds, others default `:disabled`), confirming the connect → push path end-to-end without needing `websocat` (not installed in this environment).
- `mix test`: 139 passed (was 122; added `gateway/publisher_test.exs`, `gateway/socket_test.exs`, and 5 new `application_test.exs` cases for the gateway child + updated fixtures to include the new config keys).
- CI caught a real bug before merge: `JSON.encode!/1` is Elixir-1.20-only (built-in `JSON` module added in 1.18); CI runs 1.17. Replaced with a small dependency-free `PaperWeight.Gateway.JsonEncoder` (handles maps/lists/strings/numbers/booleans/nil/atoms) — no `mix.exs`/`mix.lock` edits needed. `mix test` green at 140 (was 139) after the fix.
- Branch `feat/w3c-ws-gateway-push`, PR #68, squash-merged to master; `ci` required check green (`host`/`lane-guard`/`changes`/`label` passing, `device-ui`/`input-bridge`/`screen-tests` correctly skipped as host-only). Issue #46 closed, Status Done. No cross-lane seam: only `host/**` touched, device UI and other lanes' worktree files (etymology/, W3-D's `shell/gateway.ts` etc.) left untouched.
