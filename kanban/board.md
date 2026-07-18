# Kanban mirror — CarThing custom app

Remote board: https://github.com/users/rorybot/projects/1  
Issues: https://github.com/rorybot/paper-weight/issues  
Status helper: `scripts/set-card-status.ps1`  
Create helper (legacy): `scripts/push-cards.ps1` — do **not** re-run for existing cards.

Card format: **Goal / Scope / Constraints / Acceptance** (compressed contracts — a junior agent
implements from the card + its feature spec only). Epic prefix in title. Each card maps to a
**repo issue** (`#N`) on the project board — **not draft items**.

Dependency order: **P0-1** (device flash) → **P0** (hardware smoke) in parallel with host work;
**P0–P5 done** (platform foundation complete); screen
epics parallel now; design epic anytime.

**Status = GitHub project Status field.** This file is a mirror only. Never mark a card
In progress / Done here unless the same change succeeded on the remote project.

Status snapshot (2026-07-18, verified against remote project):
| Status | Cards |
|--------|--------|
| **Done** | P0-1 #22; P0 #21; P1 #2; P2 #1; P3 #3; P3-1 #23; P4 #4; P5 #5; W1 #9; W2 #10; F1 #12; F2 #13; N1 #6; N2 #7; N3 #8; L1 #11; D2 #19; H1 #14; H2 #15; W3-P1 #43; W3-B #45; E1 #16; W3-A #44 |
| **In progress** | - |
| **In review** | D1 #18 (PR #42) |
| **Ready** | E2 #17 |
| **Backlog** | D3 #20; W3-C #46; W3-D #47; W3-E #48; W3-G #49; W3-F #50 |

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

### W3-P1 [platform] Protocol v1.1 — freeze playlist channel · #43 ✅ Done
- **Goal**: make `playlist` a first-class host-to-device channel rather than a now-playing fixture.
- **Scope**: add `playlist` to the channel union in the protocol doc, `envelope.ex`, and
  `envelope.ts`; document the existing `PlaylistSnapshotV1` payload (TS + Elixir mirror).
- **Constraints**: cross-lane change, `chore/*` branch; no other envelope changes; no service/screen code.
- **Acceptance**: both envelope files list `playlist`; protocol doc is v1.1 and documents the
  payload; `mix test` and `npm run check` pass.
- **Done**: PR #53 merged; `mix test` (100 passed) and `npm run check` (typecheck + 130 tests +
  build) green; unblocks W3-C/D/G. Wave-3 Day-1 parallel-agent prompts for W3-A/W3-B added in PR #54.

### W3-A [platform] Device shell screen map + channel store · #44 · In review (PR #59)
- **Goal**: render every built screen and overlay from a single channel-to-snapshot store, seeded
  by fixtures; route shell commands to screen props without networking.
- **Scope**: `src/device-ui/src/shell/channelStore.ts` (new, pure `applyEnvelope`); wire real Now
  Playing, Feed, Photo, Playlist, Settings, Lyrics, and feed-detail into `ShellApp.tsx`.
- **Constraints**: branch `feat/w3a-shell-screen-map`; no edits to `bridge.ts`, `router.ts`,
  `model.ts`, `screens/**`, `protocol/**`, `host/**`; no WebSocket/network code, no play/pause.
- **Acceptance**: every ScreenId/overlay renders its real component from fixture data;
  stale-generation + unknown-channel behavior unit tested; `npm run check` passes.
- **In review**: PR #59 open; `npm run check` (typecheck + 146 tests + build) green; dev server
  boots clean and every changed module transforms via Vite with no errors. Interactive
  click-through not exercised — no headless browser in this environment.

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

### E2 [etymology] Drill-down screen (one state machine, 3 depths) - #17 - Ready
- **Goal**: build 2a/2b/2c as ONE screen with depth states — not three screens.
- **Scope**: depth 0 = root-of-day + trace ladder (wheel scrolls stages); press digs into
  highlighted stage (depth 1, breadcrumb grows); bottom = dead-end reveal (depth 2); back walks
  breadcrumb up.
- **Acceptance**: matches all three `etymology-*.png` states; back from depth 0 does nothing.

## Epic: design (remaining design work — can run anytime)

### D1 [design] Home screen — design + build · #18 · In review (PR #42)
- **Goal**: the button-hold target. Not yet mocked.
- **Scope**: design in BERG language on the claude.ai/design canvas, get approval, then build;
  likely a glanceable launcher/status card for the 6 screens.
- **Acceptance**: mock approved; hold from any screen lands here; presets 1–4 still work from it.
- **Note**: mock went TUI (gruvbox) instead of BERG, approved in-thread. Presets changed to
  1:now-playing 2:weather 3:feed 4:etymology — playlist folds into Now Playing (no button of
  its own); photo has no preset either. See PR #42 for the full topbar-rail rewiring.

### D2 [design] Settings screen — design + build (konami entry) · #19 ✅ Done
- **Goal**: hidden config screen. Not yet mocked.
- **Scope**: konami-code entry (P3 hook), wheel moves field / press edits / back exits;
  minimal fields (wifi, brightness, feed handles, photo source, hold-threshold).
- **Acceptance**: mock approved; unreachable via presets; full wheel-only operation.
- **Done**: PR #37 — `screens/settings/**` BERG card + pure move/edit reduce; shell owns
  konami/back; wave-3 wires `SettingsScreen`.

### D3 [design] Decision — reskin 4a/4b/4c TUI→BERG or keep two-layer mix · #20 · Ready
- **Goal**: settle the open visual question.
- **Scope**: try one screen (suggest 4b) in full BERG on the design canvas; compare on-device
  legibility vs gruvbox TUI chrome; document verdict in design spec + this board.
- **Acceptance**: written decision; follow-up reskin cards created OR question closed as "keep mix".
