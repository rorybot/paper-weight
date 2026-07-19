# Kanban mirror — CarThing custom app

Remote board: https://github.com/users/rorybot/projects/1  
Issues: https://github.com/rorybot/paper-weight/issues  
Status helper: `scripts/set-card-status.ps1`  
Create helper (legacy): `scripts/push-cards.ps1` — do **not** re-run for existing cards.

Card format: **Goal / Scope / Constraints / Acceptance** (compressed contracts — a junior agent
implements from the card + its feature spec only). Epic prefix in title. Each card maps to a
**repo issue** (`#N`) on the project board — **not draft items**.

Launch/demo order: **P6-H #83** + **P6-N #84** → **P6-I #82** → parallel **P7 #85** /
**P8 #86**; P7 → parallel **W4 #87** / **F3 #88** / **N4 #89**; those three plus P8
→ **P9 #90**. D3 remains unrelated Backlog.

**Status = GitHub project Status field.** This file is a mirror only. Never mark a card
In progress / Done here unless the same change succeeded on the remote project.

Status snapshot (2026-07-19, verified against remote project):
| Status | Cards |
|--------|--------|
| **Done** | P0-1 #22; P0 #21; P1 #2; P2 #1; P3 #3; P3-1 #23; P4 #4; P5 #5; W1 #9; W2 #10; F1 #12; F2 #13; N1 #6; N2 #7; N3 #8; L1 #11; D2 #19; H1 #14; H2 #15; W3-P1 #43; W3-B #45; E1 #16; W3-A #44; D1 #18; E2 #17; W3-C #46; W3-D #47; W3-E #48; W3-G #49; W3-F #50; E2-1 #79; P6-H #83; P6-N #84; P6-I #82; P7 #85; P8 #86; N4 #89; W4 #87; stale-branch cleanup #105; W5 #109 |
| **In progress** | - |
| **In review** | - |
| **Ready** | - |
| **Backlog** | F3 #88; P9 #90; D3 #20; agent-instructions review #108; kiosk pointer #111; late-host kiosk recovery #112; wheel doesn't toggle 5d/7d on Weather #114; verify Weather stale/recovery on real outage #115 |

Parallel playbook: `docs/architecture/parallel-lanes-v1.md` · prompts: `features/_lanes/agent-prompts.md`

---

## Epic: platform (foundation — blocks everything)

### P0-1 [platform] Device bootstrap — backup, flash, shell · #22 ✅ Done
- **Goal**: prepare stock Car Thing so P0 can run on a known Chromium-capable image.
- **Scope**: stock backup + hashes; choose image; flash (no fastboot); shell + file-transfer path;
  record image/tools/Chromium @ 800×480 in `docs/architecture/device-smoke.md`.
- **Constraints**: stop if backup unverified; do not run P0 mock acceptance or build P2 here.
- **Acceptance**: device boots selected image; shell + copy works; P0 unblocked at `device-smoke/`.
- **Done**: owner accepted the completed flash, shell/file-transfer, Chromium, and successful P0
  hardware run as sufficient; project Status set to Done and #22 closed on 2026-07-16.

### P0 [platform] Device smoke — Chromium kiosk paints a frame · #21 ✅ Done
- **Goal**: prove Chromium kiosk + preset buttons work on real Car Thing before platform/UI.
- **Scope**: kiosk @ 800×480 loads `device-smoke/index.html`; **buttons 1–4 switch mock frames**
  from `spec/`: 1→`now-playing-4a` · 2→`weather-4b` · 3→`playlist-4c` · 4→`feed-4f`. Record
  image, flags, RAM, `/dev/input`, preset→page mapping (keys / evdev bridge).
- **Constraints**: static HTML only (no Elixir/Preact). Photo/etymology not on 1–4 for this smoke.
- **Acceptance**: each preset shows the correct mockup (captures); `docs/architecture/device-smoke.md`
  with go/no-go (or fallback if kiosk/input fails).
- **Done**: flashed via nixos-superbird (manual pyamlboot fallback); USB CDC-NCM gadget network
  routed through WSL (Windows lacks a driver for the Linux gadget's NCM interface); kiosk confirmed
  loading `device-smoke/` at exact 800×480; all four presets verified correct one-at-a-time via
  CDP screenshots (gpio-keys emits standard `KEY_1`–`KEY_4`, no injector needed). GO verdict
  recorded in `docs/architecture/device-smoke.md`.

### P1 [platform] Architecture spike — runtime & stack decision · #2 ✅ Done
- **Goal**: pick the on-device stack before any src/ code.
- **Scope**: evaluate template default (Elixir backend + web frontend) vs alternatives
  (webview/kiosk browser on device, native framebuffer app, host-serves/device-renders split)
  against Car Thing hardware: ARM SoC, ~512MB RAM, reflashed Linux, evdev input, 800×480 LCD.
- **Constraints**: functional paradigm non-negotiable; deviation from Elixir must be justified.
- **Acceptance**: `docs/architecture/workflow-v1.md` with decision, rationale, deploy story.
- **Decision**: host Elixir services + device Chromium kiosk + Preact/TS pure UI + evdev bridge;
  P5 dither on host. See `docs/architecture/workflow-v1.md`.

### P2 [platform] Input daemon — evdev → event bus · #1 ✅ Done
- **Goal**: one process/module normalizing all hardware input.
- **Scope**: wheel turn (±ticks), wheel press, buttons 1–4, button-hold (→home), back. Emit
  typed events on an internal bus; screens subscribe.
- **Constraints**: app must be fully usable without touch; hold-vs-press debounce; pure handlers.
- **Acceptance**: fake-evdev test feed produces the exact event stream; hold threshold configurable.
- **Done**: `src/input-bridge/` provides configurable 64-bit Linux evdev normalization, a versioned loopback SSE bus, systemd unit, and 14 passing tests.

### P3 [platform] Screen shell — router, overlays, back stack · #3 ✅ Done
- **Goal**: top-level navigation container.
- **Scope**: presets 1–4 hard-switch screens; hold→Home from anywhere; back = up one level /
  dismiss overlay; overlay layer (lyrics); konami-code listener → Settings.
- **Constraints**: screens are pure `state → view` functions; router owns all input routing.
- **Acceptance**: interaction map in design spec §Interaction reproduced exactly in tests.
- **Done**: `src/device-ui/src/shell/` pure `routeShellInput` + `ScreenShell` + P2 SSE bridge
  adapter + dev keyboard map; interaction-map tests (presets/hold/back/konami/wheel/press per
  screen). `npm run check` 41 tests. Harness: `ShellApp` (`?bridge=0` keyboard-only).

### P3-1 [platform] Fix swapped preset 2/3 preview routing · #23 ✅ Done
- **Goal**: preset 2 opens Playlist and preset 3 opens Weather everywhere.
- **Scope**: correct the Preact shell mapping and standalone device-smoke frame order; add explicit regression assertions.
- **Constraints**: keep evdev numeric translation unchanged; preserve presets 1 and 4; do not edit data-service lanes.
- **Acceptance**: both previews route 2 → Playlist and 3 → Weather; device UI checks pass.
- **Done**: Preact shell and device-smoke mappings corrected; explicit preset 2/3 regression assertions added; 53 device-UI tests pass.

### P4 [platform] BERG design system tokens + card component · #4 ✅ Done
- **Goal**: shared visual layer for all screens.
- **Scope**: color tokens, DM Serif Display / JetBrains Mono / Space Grotesk, signature card
  recipe (hard outline + hard offset shadow), dark-desk chrome, min-size rules (≥13px).
- **Constraints**: 800×480 fixed; gruvbox TUI palette kept available as fallback theme.
- **Acceptance**: token module + card component render a sample screen matching the spec recipe.
- **Done**: `src/device-ui/` provides immutable BERG/gruvbox tokens, bundled fonts, reusable
  hard-outline/offset-shadow `Card`, and a visually checked 800×480 feed sample; 6 tests pass.

### P5 [platform] 1-bit Atkinson dither utility · #5 ✅ Done
- **Goal**: shared image pipeline for album art (NP), covers (Playlist), photos (Photo frame).
- **Scope**: image → 1-bit Atkinson-dithered bitmap sized for target slot; cache results.
- **Constraints**: host-side (P1); pure core fn; golden-image tests required.
- **Acceptance**: golden-image tests; visually matches mockups' dither character.
- **Done**: `host/lib/paper_weight/` provides Image/Resize/Atkinson/Bitmap/Cache; 11 tests pass,
  including the 8×8 gradient golden PBM; user approved and #5 closed.

### P6-H [platform] Host production service · #83 · Done (closed)
- **Goal**: run the production UI `:8080` and fixture gateway `:9138` as a resilient host user service.
- **Scope**: salvage/harden `scripts/run-device-fixture.sh`; add service operations, USB retry,
  and HTTP/WebSocket health checks.
- **Constraints**: no device Nix, live lanes, `application.ex`, or #82 evidence edits.
- **Acceptance**: build/check, restart, USB replug, health checks, and host reboot all pass.
- **Done**: both servers bind `0.0.0.0` so USB unplug/replug is a non-event (no gadget-IP
  rebind to repair); added `scripts/host-service.sh` (`systemd --user` install/start/stop/
  restart/status/uninstall + linger for reboot survival) and `scripts/host-health-check.sh`
  (HTTP UI + WS-upgrade gateway check). Doc: `docs/architecture/host-production-service.md`.
  `npm run check` and `mix test` both green; PR #93 merged, issue #83 closed.
  Real-device `systemctl --user start`/reboot survival not exercised in the dev sandbox
  (verified as a sandbox limitation, not a script defect) — spot-check on the USB-host machine.

### P6-N [platform] Declarative NixOS kiosk · #84 · Done (closed)
- **Goal**: boot directly into the production kiosk through a rollback-safe NixOS generation.
- **Scope**: pin `nixos-superbird` at `0d2b239683907c19583c51134c6795ded087437d`;
  set `superbird.gui.kiosk_url`; build/deploy through the privileged upstream builder.
- **Constraints**: use host Podman; preserve the prior generation; no `/etc` symlink/systemd override.
- **Acceptance**: evaluate/build, deploy to `172.16.42.2`, reboot fullscreen, and rollback pass.
- **Done**: `device/nix/flake.nix` pins the upstream rev and sets the production kiosk URL;
  `scripts/device-nixos.sh` (evaluate/build/deploy/status/reboot/rollback/activate, optional
  nixbuild.net remote builder). Doc: `docs/architecture/device-nixos-kiosk.md`. Physically
  verified on `172.16.42.2`: deploy landed generation 2, survived a real `systemctl reboot`
  (Weston active, production URL, Home screen confirmed on-device), rollback to generation 1
  and return to generation 2 both confirmed; generation 1 retained throughout. PR #100 merged,
  issue #84 closed.

### P6-I [platform] Cold-boot integration · #82 ✅ Done
- **Goal**: integrate P6-H and P6-N into one physically verified device-launch path.
- **Scope**: finish `device-launch.md` operations; production-port checks; exact 800×480 evidence.
- **Constraints**: integration/evidence only; fixture data only; eventual-host cold boot is P9.
- **Acceptance**: device boot/fullscreen; presets 1–4; status/reboot/rollback; final-head `ci`.
- **Evidence**: 2026-07-19 dev-environment fixture passed UI/gateway over USB, exact `800×480`,
  and owner-verified physical presets 1–4; device reboot/rollback/restore passed under P6-N.
  Required `ci` passed; #82 closed and project Status set to Done.

### P7 [platform] Live-runtime contract · #85 ✅ Done
- **Goal**: one activation contract for live Weather, Feed, and Spotify.
- **Scope**: documented EnvironmentFile variables, validation, and per-lane enablement only.
- **Constraints**: #82 is Done; secrets stay untracked/out-of-band; frozen envelopes unchanged;
  Etymology stays fixture-backed and Photo stays outside the milestone.
- **Acceptance**: zero-secret config tests and clear safe failure for missing/invalid variables.
- **Done**: new pure `PaperWeight.RuntimeContract` + `Application.resolve_config/1` add
  `PAPER_WEIGHT_WEATHER_ENABLED`/`_SPOTIFY_ENABLED`/`_FEED_ENABLED` runtime overrides and
  fail-fast validation (missing var *names* only, never values); `run-device-fixture.sh` and
  the systemd unit template now accept a live `EnvironmentFile` while staying fixture-safe by
  default. Doc: `docs/architecture/live-runtime-contract-v1.md`. `mix test` 174 passed; manual
  boot checks (fixture default, fail-fast, success path) all passed. PR #106 squash-merged,
  required `ci` green, issue #85 closed. Unblocks W4 #87, F3 #88, N4 #89.

### P8 [platform] Device input-bridge deployment · #86 ✅ Done
- **Goal**: package/supervise the Rust bridge on aarch64 and feed physical input through loopback SSE.
- **Scope**: device package/service at `127.0.0.1:9137/v1/events`, evdev access, reconnect;
  remove `bridge=0` after acceptance.
- **Constraints**: #82 is Done; no live-lane or frozen-envelope edits.
- **Acceptance**: fmt/test/clippy, aarch64 build, physical events, boot service, and reconnect pass.

### P6-N1 [platform] Hide kiosk pointer reliably · #111 · Backlog
- **Goal**: remove the visible Chromium/Weston pointer from the production 800×480 kiosk.
- **Scope**: identify pointer ownership; apply the smallest declarative fix; validate restart and boot.
- **Constraints**: preserve host/dev browser and keyboard workflows; do not reopen P8.
- **Acceptance**: no pointer on-device; relevant checks and physical validation pass.

### P6-N2 [platform] Recover when host UI starts after device · #112 · Backlog
- **Goal**: load the kiosk automatically when the host fixture becomes ready after device startup.
- **Scope**: readiness/reload strategy covering late host startup and USB reconnect.
- **Constraints**: no restart storm; preserve kiosk restart, rollback, and diagnosability.
- **Acceptance**: late host and USB reconnect recover without SSH/manual service restart; cold-boot
  physical validation passes.

### P9 [platform] Demo-appliance acceptance · #90 · Backlog
- **Goal**: accept the unattended eventual-host appliance with live lanes and physical input.
- **Scope**: integrate P8/W4/F3/N4; final-host/device cold boot, network recovery, final evidence.
- **Constraints**: gate only; actual eventual host required; interactive dev fixture is insufficient.
- **Acceptance**: unattended host services; exact 800×480 cold boot; post-boot health; live screens,
  playlist/volume input, degraded/reconnect states, screenshots, green `ci`.

### Chore [process] Agent-instructions review and reusable template · #108 · Backlog
- **Goal**: make the repository's agent instructions coherent, reliable, and reusable.
- **Scope**: audit instruction sources, resolve duplication/conflicts, and extract a future-project
  template with explicit customization points.
- **Constraints**: documentation/process only; preserve project safety boundaries and call out any
  proposed workflow behavior changes for owner review.
- **Acceptance**: precedence and ownership are explicit, expensive-cycle lessons are integrated,
  the reusable template is scenario-reviewed, and required `ci` passes.

### W3-P1 [platform] Protocol v1.1 — freeze playlist channel · #43 ✅ Done
- **Goal**: make `playlist` a first-class host-to-device channel rather than a now-playing fixture.
- **Scope**: add `playlist` to the channel union in the protocol doc, `envelope.ex`, and
  `envelope.ts`; document the existing `PlaylistSnapshotV1` payload (TS + Elixir mirror).
- **Constraints**: cross-lane change, `chore/*` branch; no other envelope changes; no service/screen code.
- **Acceptance**: both envelope files list `playlist`; protocol doc is v1.1 and documents the
  payload; `mix test` and `npm run check` pass.
- **Done**: PR #53 merged; `mix test` (100 passed) and `npm run check` (typecheck + 130 tests +
  build) green; unblocks W3-C/D/G. Wave-3 Day-1 parallel-agent prompts for W3-A/W3-B added in PR #54.

### W3-A [platform] Device shell screen map + channel store · #44 ✅ Done
- **Goal**: render every built screen and overlay from a single channel-to-snapshot store, seeded
  by fixtures; route shell commands to screen props without networking.
- **Scope**: `src/device-ui/src/shell/channelStore.ts` (new, pure `applyEnvelope`); wire real Now
  Playing, Feed, Photo, Playlist, Settings, Lyrics, and feed-detail into `ShellApp.tsx`.
- **Constraints**: branch `feat/w3a-shell-screen-map`; no edits to `bridge.ts`, `router.ts`,
  `model.ts`, `screens/**`, `protocol/**`, `host/**`; no WebSocket/network code, no play/pause.
- **Acceptance**: every ScreenId/overlay renders its real component from fixture data;
  stale-generation + unknown-channel behavior unit tested; `npm run check` passes.
- **Done**: PR #59 merged; issue #44 closed and Project Status Done; `npm run check` was green:
  typecheck + 146 tests + build. Interactive click-through belongs to W3-F.

### W3-B [platform] Host deps, Application children, and runtime config · #45 ✅ Done
- **Goal**: supervise all four service GenServers with per-service enablement; add the locked
  WebSocket deps/config plumbing (nothing starts Bandit yet — that's W3-C).
- **Scope**: `mix.exs`/`mix.lock` add `bandit`, `websock_adapter`, `plug`; `application.ex`
  generalizes into a pure `children/1` (config → child specs) plus an impure
  `config_from_env/0` edge; `config.exs` documents per-service env vars and defaults
  Weather `:enabled`, Spotify/Feed/Photo `:disabled`.
- **Constraints**: platform wiring overrides the wave-1 "don't touch application.ex/mix.exs"
  rule for this card only; no service internals, envelope, or device UI touched.
- **Acceptance**: `mix test` passes zero-env; all-enabled config yields four service child
  specs; weather default behavior unchanged; new deps compile in CI.
- **Done**: PR #58 (`feat/w3b-host-app-children`) merged (squash, fast-forward to master); `ci`
  required check green (`host`/`lane-guard` pass, product-lane jobs correctly skipped); issue #45
  closed and Status set to Done.

## Epic: now-playing (screen 4a)

### N1 [now-playing] Spotify data service · #6 · Done (lane wave 1)
- **Goal**: now-playing metadata, up-next queue, volume control.
- **Scope**: Spotify API/connect client; expose `now_playing()`, `queue()`, `set_volume(delta)`.
- **Constraints**: NO play/pause anywhere (flagged off); token refresh handled internally.
  Own only `host/lib/paper_weight/spotify/**` — see `features/now-playing/spec.md`.
- **Acceptance**: mocked-API tests; volume responds to wheel-tick deltas. Done: 31 mocked
  tests green under `host/test/paper_weight/spotify/`, see spec.md Next Session chunk.

### N2 [now-playing] Screen 4a UI · #7 ✅ Done
- **Goal**: build final pick 4a.
- **Scope**: 1-bit dithered art square (P5), title/metadata, up-next queue pane (wheel scrolls
  queue is WRONG — wheel = volume; queue is display-only), footer "⟲ volume · press words".
- **Constraints**: TUI/gruvbox chrome for now (reskin decision = D3); wheel press → lyrics (N3).
- **Acceptance**: matches `now-playing-4a.png`; wheel=volume, press=lyrics overlay, no transport UI.
- **Done**: PR #39 — pure Preact 4a screen (PBM art, metadata, progress, volume, display-only
  queue); coexists with N3 `LyricsOverlay`; wave-3 wires ShellApp.

### N3 [now-playing] Lyrics overlay — design + build · #8 ✅ Done
- **Goal**: press-to-toggle overlay over 4a (NOT a top-level screen). Not yet mocked.
- **Scope**: design in BERG language first (paper card over dimmed 4a suggested), then build;
  synced or static lyrics per what Spotify service exposes; press again / back dismisses.
- **Acceptance**: design snippet approved on the claude.ai/design canvas; overlay toggles on
  device without disturbing NP state.
- **Done**: PR #36 — `LyricsOverlay` BERG paper card + pure active-line sync; shell owns toggle;
  design snippet in feature spec; wave-3 wires `renderOverlay`.

### W3-G [now-playing] Host playlist snapshot channel · #49 ✅ Done
- **Goal**: publish real Spotify playlists on the `playlist` channel.
- **Scope**: fetch id/name/(null cover) into `PlaylistSnapshotV1`; `Service.playlists` +
  independent `playlist_gen`; replace gateway `PlaylistStub` with live publisher input.
- **Constraints**: branch `feat/w3g-playlist-channel`; match `protocol/playlist.ts`; no play/pause.
- **Acceptance**: mocked tests produce a valid playlist envelope; publisher emits live data;
  generation advances on refresh.
- **Done**: PR #75 merged; host `mix test` 155 passed; CI green; issue #49 closed + Project Done.
  Covers stay `null` until JPEG→grayscale exists. Unblocks W3-F #50.

### N4 [now-playing] Live Spotify acceptance · #89 ✅ Done
- **Goal**: accept real-account metadata, playlists, volume, failures, and reconnect on the device.
- **Scope**: P7 activation plus Spotify-owned gaps/tests and physical validation.
- **Constraints**: blocked by P7; Spotify-owned paths only; frozen envelopes; no play/pause; no secrets.
- **Acceptance**: mocked token/failure recovery; live Now Playing/playlists; selection and volume pass.
- **Done**: PR #96 merged; mocked coverage (56 spotify tests) + physical acceptance: live metadata
  and 50 real playlists on device; scripted outage drill passed (stale=true frozen snapshot →
  reconnect → fresh, gen 1670→1688). Playlist *selection* waived by Rory (no navigation path to
  PlaylistScreen exists in the shell router); wheel volume deferred to P8 (`bridge=0`).

### W3-F [platform] End-to-end fixture host to desktop UI smoke · #50 ✅ Done
- **Goal**: document and prove a repeatable fixture-host-to-desktop-UI smoke including volume
  intent round-trip.
- **Scope**: `docs/architecture/wave-3-smoke.md`; host `gateway: [stubs: :all]` profile
  (`PAPER_WEIGHT_GATEWAY_STUBS=all`); npm `dev:live`; fix only integration mismatches.
- **Constraints**: branch `chore/w3f-e2e-smoke`; blocked by W3-D/E/G (met); no new features,
  protocol changes, screen changes, or CI job.
- **Acceptance**: clean-checkout instructions work; all channel envelopes render; keyboard
  volume logs `set_volume`; host loss shows reconnect.
- **Done**: PR #77 merged; host `mix test` 161; live WS showed all five channels + `set_volume`
  log; issue #50 closed + Project Done. Wave-3 integration capstone complete.

## Epic: weather (screen 4b)

### W1 [weather] Weather data service — NWS + OpenUV · #9 ✅ Done
- **Goal**: current conditions, 5-day + 7-day forecast, hourly UV index.
- **Scope**: NWS forecast API + OpenUV client; walk-verdict generator (plain-spoken italic quote
  from temp/UV/precip windows); cache + periodic refresh (glanceable snapshot, not live).
  Own only `host/lib/paper_weight/weather/**` — see `features/weather/spec.md`.
- **Acceptance**: fixture tests incl. verdict phrasing rules; graceful stale-data state.
- **Done**: mocked NWS/OpenUV + pure grade/verdict/snapshot + stale path; `mix test test/paper_weight/weather/` green.

### W2 [weather] Screen 4b UI · #10 ✅ Done
- **Goal**: build final pick 4b.
- **Scope**: thin status topbar → compact UV "WALK?" band (~¼ height; solid=extreme,
  dithered-lines=high, faint=low, legend ▮▤▮) → big current temp left + 5-day right → footer.
  Wheel toggles today ↔ 7-day.
- **Acceptance**: matches `weather-4b.png`; UV grading renders all three strengths correctly.
- **Done**: fixture-driven `WeatherScreen` @ 800×480; pure `toggle-weather-range` 5d↔7d;
  UV bars/legend for extreme/high/low; no shell edits (wave 3 wires screen map).

### W4 [weather] Live Weather acceptance · #87 ✅ Done
- **Goal**: accept live NWS/OpenUV Weather behavior on the physical device.
- **Scope**: P7 activation plus Weather-owned gaps/tests and physical validation.
- **Constraints**: P7 #85 Done; Weather-owned paths only; frozen envelope;
  credentials untracked.
- **Acceptance**: mocked stale/recovery; live current conditions/UV/verdict on device; required `ci` green.
- **Done**: added mocked coverage for OpenUV-specific failure, malformed/partial NWS + OpenUV
  responses, post-failure recovery, and generation transitions
  (`service_test.exs`/`fetch_test.exs`/`nws_test.exs`/`open_uv_test.exs`); fixed a real bug —
  `Service.refresh_now/1` returned a malformed nested reply tuple on a successful post-failure
  refresh instead of `{:ok, snap}`. `mix test test/paper_weight/weather` 38/38, full host
  201/201. Physical Car Thing acceptance (`.env` via P7 contract): kiosk loads, live current
  conditions render, 5-day forecast displays, UV + walk verdict consistent with live snapshot.
  7-day wheel toggle does not respond on-device — split out to #114 (not a code regression;
  `WeatherScreen`/`ShellApp` unit tests for the toggle still pass). Stale/error + recovery
  behavior on a real ~15-min network outage was not genuinely re-observed this session
  (refresh interval is fixed 15 min, no env override) — split out to #115. PR #95 squash-merged,
  required `ci` green, issue #87 closed.

### W4-1 [weather] Wheel does not toggle 5-day/7-day on physical device · #114 · Backlog
- **Goal**: make the on-device wheel actually flip the Weather screen between 5-day and 7-day.
- **Scope**: confirm whether wheel events reach the Weather screen's command handler at all
  on-device (control-case check against now-playing volume); narrow to Weather lane vs
  input-bridge/shell wiring before assuming ownership.
- **Acceptance**: turning the wheel on the physical Weather screen visibly toggles 5-day ↔ 7-day.

### W4-2 [weather] Verify stale/recovery on a real physical-device network outage · #115 · Backlog
- **Goal**: actually observe (not mock) the accepted stale/error and recovery presentation on
  the Car Thing across a real ~15-minute network outage.
- **Scope**: cut host internet with the live Weather runtime active, wait for a failed refresh
  tick, confirm on-device stale/error state, restore connectivity, confirm the next tick
  refreshes to a fresh snapshot on-device.
- **Acceptance**: both stale/error and recovery states are confirmed on-device against a real outage.

### W5 [weather] Migrate Weather from NWS/OpenUV to Open-Meteo · #109 ✅ Done
- **Goal**: remove the OpenUV credential requirement by using Open-Meteo as the live provider.
- **Scope**: replace NWS/OpenUV parsing/fetching; preserve the frozen Weather snapshot and UI;
  remove `OPENUV_API_KEY` from the P7 runtime contract and docs.
- **Constraints**: cross-lane `chore/*` branch or `cross-lane` label; no committed location values;
  use the proven no-key request shape from local `newTab` where appropriate.
- **Acceptance**: current conditions, 5/7-day forecast, UV/verdict, stale/reconnect behavior pass;
  startup requires only latitude/longitude; required `ci` green.
- **Done**: PR #118 squash-merged; `host/lib/paper_weight/weather/{open_meteo,weather_code}.ex`
  replace NWS/OpenUV parsing; `OPENUV_API_KEY` removed from runtime contract and `.env.example`;
  frozen snapshot envelope and UV/verdict logic unchanged; required `ci` green; #109 closed
  2026-07-19.

## Epic: playlist (screen 4c)

### L1 [playlist] Playlist grid screen 4c · #11 ✅ Done
- **Goal**: build final pick 4c.
- **Scope**: 2×3 (or 4-wide) dithered cover grid (P5), fat labels; selected tile pops onto paper
  card with ▶; wheel walks grid, press plays via Spotify service (N1).
- **Acceptance**: matches `playlist-4c.png`; press starts playback and switches to Now Playing.
- **Done**: `screens/playlist/**` + `protocol/playlist.ts` (PR #34); pure reduce for wheel/play;
  fixture mockup names; play → `play_playlist` args; NP host/navigate remains wave 3.

## Epic: feed (screen 4f)

### F1 [feed] X/Twitter snapshot service · #12 · Done
- **Goal**: periodic read-only feed snapshot.
- **Scope**: fetch N recent posts from followed handles/list; strip to text+handle+time;
  per-handle accent color assignment; refresh on interval.
  Own only `host/lib/paper_weight/feed/**` — see `features/feed/spec.md`.
- **Constraints**: read-only; snapshot semantics (no live updates mid-view).
- **Acceptance**: fixture snapshot renders ≥3 posts; refresh swaps atomically.

### F2 [feed] Screen 4f UI · #13 ✅ Done
- **Goal**: build final pick 4f (BERG-pushed 3d renderer).
- **Scope**: dark desk, ~3 posts visible, selected post on cream hard-outline+offset card, serif
  bodies, mono handles, dashed dividers, mustard footer, receipt-roll progress rail (right).
  Wheel scrolls, press enlarges, back collapses.
- **Constraints**: "Grus Gazette" mini-newspaper concept is REJECTED — do not build.
- **Acceptance**: matches `feed-4f.png`; big type readable on the 3.97" panel.
- **Done**: `src/device-ui/src/screens/feed/**` pure `reduceFeedUi` + `FeedScreen` @ 800×480 BERG;
  ~3-post window, cream selected card, mustard footer, receipt rail; enlarge/collapse; 12 tests;
  no shell edits. Branch `lane/feed-f2`.

### F3 [feed] Live Feed acceptance · #88 · Backlog
- **Goal**: accept live feed snapshots, interaction, failure, and reconnect on the physical device.
- **Scope**: P7 activation plus Feed-owned gaps/tests and physical validation.
- **Constraints**: blocked by P7; Feed-owned paths only; frozen envelope; secrets untracked.
- **Acceptance**: mocked atomic refresh/failure recovery; live scroll/detail; reconnect passes.

## Epic: photo (screen 4g)

### H1 [photo] Photo source + rotation service · #14 ✅ Done
- **Goal**: local photo library with slideshow rotation.
- **Scope**: photo ingest (local dir/drop), rotation timer ("reprints in X min"), ordering,
  "keep on show" pin (wheel press), skip (wheel turn); caption metadata.
- **Acceptance**: N/M counter + reprint countdown correct across skip/keep interactions.
- **Done**: `host/lib/paper_weight/photo/**` pure Rotate + Library scan + Service; 20 tests;
  payload frozen in `features/photo/spec.md` + `protocol/photo.ts`. No Application registration.

### H2 [photo] Screen 4g UI · #15 ✅ Done
- **Goal**: build final pick 4g.
- **Scope**: cream frame, true 1-bit Atkinson dither over the real photo (P5), printed serif
  caption, "photo N/M · reprints in X min" line.
- **Acceptance**: matches `photo-4g.png` with a real user photo.
- **Done**: `src/device-ui/src/screens/photo/**` BERG cream frame + P4→BMP art + status line;
  pure skip/keep local reducer; fixture Atkinson PBM; 10 photo tests. Mock PNG still pending
  for pixel QA. No shell / Application edits.

## Epic: etymology (screens 2a→2b→2c)

### E1 [etymology] Word-origin data service - #16 - Done ✅
- **Goal**: day's word + nested origin trace.
- **Scope**: Wiktionary-style source; recursive trace structure (stage → sub-trace → … → root);
  daily selection; cache the day's tree.
- **Acceptance**: `travailler`-style fixture yields a ≥3-depth tree with a terminal root. **Met** —
  `host/test/paper_weight/etymology/` (121 tests green on CI).
- **Delivered** (PR #60, merged): standalone service under `host/lib/paper_weight/etymology/`
  (Origin/Entry/Corpus/Selection/Snapshot/Service), `src/device-ui/src/protocol/etymology.ts`
  (payload types only), `features/etymology/spec.md`. Not wired into `Application`; `etymology`
  stays an ignored/omitted channel (no `ChannelV1` edit). Wave-3 child: `{PaperWeight.Etymology.Service, []}`.

### E2 [etymology] Drill-down screen (one state machine, 3 depths) - #17 - ✅ Done
- **Goal**: build 2a/2b/2c as ONE screen with depth states — not three screens.
- **Scope**: depth 0 = root-of-day + trace ladder (wheel scrolls stages); press digs into
  highlighted stage (depth 1, breadcrumb grows); bottom = dead-end reveal (depth 2); back walks
  breadcrumb up.
- **Acceptance**: matches all three `etymology-*.png` states; back from depth 0 does nothing.
- **Done**: PR #66 merged (CI green). One pure state machine + `EtymologyScreen` under
  `src/device-ui/src/screens/etymology/`; 25 tests. Shell wire-up seam recorded in PR #66
  for the W3-D follow-up; `etymology` channel still not in `ChannelV1` (fixture-only).

### E2-1 [platform] Wire preset 4 to Etymology screen · #79 ✅ Done
- **Goal**: make physical preset 4 render the existing E2 screen instead of the shell placeholder.
- **Scope**: route `ShellApp` to `EtymologyScreen` with its local fixture and add regression coverage.
- **Constraints**: no host channel, protocol, or other-screen changes; Etymology remains fixture-only.
- **Acceptance**: preset 4 renders `data-screen="etymology"` in tests and on the 800×480 device.
- **Done**: PR #80 merged with required `ci` green; physical device capture verified 800×480.

## Epic: design (remaining design work — can run anytime)

### D1 [design] Home screen — design + build · #18 ✅ Done
- **Goal**: the button-hold target. Not yet mocked.
- **Scope**: design in BERG language on the claude.ai/design canvas, get approval, then build;
  likely a glanceable launcher/status card for the 6 screens.
- **Acceptance**: mock approved; hold from any screen lands here; presets 1–4 still work from it.
- **Done**: PR #42 merged; TUI (gruvbox) mock approved in-thread. Presets changed to
  1:now-playing 2:weather 3:feed 4:etymology — playlist folds into Now Playing (no button of
  its own); photo has no preset either. See PR #42 for the full topbar-rail rewiring.

### D2 [design] Settings screen — design + build (konami entry) · #19 ✅ Done
- **Goal**: hidden config screen. Not yet mocked.
- **Scope**: konami-code entry (P3 hook), wheel moves field / press edits / back exits;
  minimal fields (wifi, brightness, feed handles, photo source, hold-threshold).
- **Acceptance**: mock approved; unreachable via presets; full wheel-only operation.
- **Done**: PR #37 — `screens/settings/**` BERG card + pure move/edit reduce; shell owns
  konami/back; wave-3 wires `SettingsScreen`.

### D3 [design] Decision — reskin 4a/4b/4c TUI→BERG or keep two-layer mix · #20 · Backlog
- **Goal**: settle the open visual question.
- **Scope**: try one screen (suggest 4b) in full BERG on the design canvas; compare on-device
  legibility vs gruvbox TUI chrome; document verdict in design spec + this board.
- **Acceptance**: written decision; follow-up reskin cards created OR question closed as "keep mix".
