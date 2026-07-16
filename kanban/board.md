# Kanban mirror â€” CarThing custom app

Remote board: https://github.com/users/rorybot/projects/1  
Issues: https://github.com/rorybot/paper-weight/issues  
Status helper: `scripts/set-card-status.ps1`  
Create helper (legacy): `scripts/push-cards.ps1` â€” do **not** re-run for existing cards.

Card format: **Goal / Scope / Constraints / Acceptance** (compressed contracts â€” a junior agent
implements from the card + its feature spec only). Epic prefix in title. Each card maps to a
**repo issue** (`#N`) on the project board â€” **not draft items**.

Dependency order: **P0-1** (device flash) â†’ **P0** (hardware smoke) in parallel with host work;
**P0â€“P5 done** (platform foundation complete); screen
epics parallel now; design epic anytime.

**Status = GitHub project Status field.** This file is a mirror only. Never mark a card
In progress / Done here unless the same change succeeded on the remote project.

Status snapshot (2026-07-16, verified against remote project):
| Status | Cards |
|--------|--------|
| **Done** | P0-1 #22 Â· P0 #21 Â· P1 #2 Â· P2 #1 Â· P3 #3 Â· **P3-1 #23** Â· P4 #4 Â· P5 #5 Â· **W1 #9 Â· W2 #10 Â· F1 #12 Â· F2 #13 Â· N1 #6 Â· N3 #8 Â· L1 #11 Â· D2 #19 Â· E1 #16 Â· E2 #17 Â· H1 #14 Â· H2 #15** |
| **In progress** | â€” |
| **In review** | **N2 #7** (PR #39) |
| **Ready** | **D1 #18 Â· D3 #20** |
| **Backlog** | â€” |

Parallel playbook: `docs/architecture/parallel-lanes-v1.md` Â· prompts: `features/_lanes/agent-prompts.md`

---

## Epic: platform (foundation â€” blocks everything)

### P0-1 [platform] Device bootstrap â€” backup, flash, shell Â· #22 âœ… Done
- **Goal**: prepare stock Car Thing so P0 can run on a known Chromium-capable image.
- **Scope**: stock backup + hashes; choose image; flash (no fastboot); shell + file-transfer path;
  record image/tools/Chromium @ 800Ã—480 in `docs/architecture/device-smoke.md`.
- **Constraints**: stop if backup unverified; do not run P0 mock acceptance or build P2 here.
- **Acceptance**: device boots selected image; shell + copy works; P0 unblocked at `device-smoke/`.
- **Done**: owner accepted the completed flash, shell/file-transfer, Chromium, and successful P0
  hardware run as sufficient; project Status set to Done and #22 closed on 2026-07-16.

### P0 [platform] Device smoke â€” Chromium kiosk paints a frame Â· #21 âœ… Done
- **Goal**: prove Chromium kiosk + preset buttons work on real Car Thing before platform/UI.
- **Scope**: kiosk @ 800Ã—480 loads `device-smoke/index.html`; **buttons 1â€“4 switch mock frames**
  from `spec/`: 1â†’`now-playing-4a` Â· 2â†’`weather-4b` Â· 3â†’`playlist-4c` Â· 4â†’`feed-4f`. Record
  image, flags, RAM, `/dev/input`, presetâ†’page mapping (keys / evdev bridge).
- **Constraints**: static HTML only (no Elixir/Preact). Photo/etymology not on 1â€“4 for this smoke.
- **Acceptance**: each preset shows the correct mockup (captures); `docs/architecture/device-smoke.md`
  with go/no-go (or fallback if kiosk/input fails).
- **Done**: flashed via nixos-superbird (manual pyamlboot fallback); USB CDC-NCM gadget network
  routed through WSL (Windows lacks a driver for the Linux gadget's NCM interface); kiosk confirmed
  loading `device-smoke/` at exact 800Ã—480; all four presets verified correct one-at-a-time via
  CDP screenshots (gpio-keys emits standard `KEY_1`â€“`KEY_4`, no injector needed). GO verdict
  recorded in `docs/architecture/device-smoke.md`.

### P1 [platform] Architecture spike â€” runtime & stack decision Â· #2 âœ… Done
- **Goal**: pick the on-device stack before any src/ code.
- **Scope**: evaluate template default (Elixir backend + web frontend) vs alternatives
  (webview/kiosk browser on device, native framebuffer app, host-serves/device-renders split)
  against Car Thing hardware: ARM SoC, ~512MB RAM, reflashed Linux, evdev input, 800Ã—480 LCD.
- **Constraints**: functional paradigm non-negotiable; deviation from Elixir must be justified.
- **Acceptance**: `docs/architecture/workflow-v1.md` with decision, rationale, deploy story.
- **Decision**: host Elixir services + device Chromium kiosk + Preact/TS pure UI + evdev bridge;
  P5 dither on host. See `docs/architecture/workflow-v1.md`.

### P2 [platform] Input daemon â€” evdev â†’ event bus Â· #1 âœ… Done
- **Goal**: one process/module normalizing all hardware input.
- **Scope**: wheel turn (Â±ticks), wheel press, buttons 1â€“4, button-hold (â†’home), back. Emit
  typed events on an internal bus; screens subscribe.
- **Constraints**: app must be fully usable without touch; hold-vs-press debounce; pure handlers.
- **Acceptance**: fake-evdev test feed produces the exact event stream; hold threshold configurable.
- **Done**: `src/input-bridge/` provides configurable 64-bit Linux evdev normalization, a versioned loopback SSE bus, systemd unit, and 14 passing tests.

### P3 [platform] Screen shell â€” router, overlays, back stack Â· #3 âœ… Done
- **Goal**: top-level navigation container.
- **Scope**: presets 1â€“4 hard-switch screens; holdâ†’Home from anywhere; back = up one level /
  dismiss overlay; overlay layer (lyrics); konami-code listener â†’ Settings.
- **Constraints**: screens are pure `state â†’ view` functions; router owns all input routing.
- **Acceptance**: interaction map in design spec Â§Interaction reproduced exactly in tests.
- **Done**: `src/device-ui/src/shell/` pure `routeShellInput` + `ScreenShell` + P2 SSE bridge
  adapter + dev keyboard map; interaction-map tests (presets/hold/back/konami/wheel/press per
  screen). `npm run check` 41 tests. Harness: `ShellApp` (`?bridge=0` keyboard-only).

### P3-1 [platform] Fix swapped preset 2/3 preview routing Â· #23 âœ… Done
- **Goal**: preset 2 opens Playlist and preset 3 opens Weather everywhere.
- **Scope**: correct the Preact shell mapping and standalone device-smoke frame order; add explicit regression assertions.
- **Constraints**: keep evdev numeric translation unchanged; preserve presets 1 and 4; do not edit data-service lanes.
- **Acceptance**: both previews route 2 â†’ Playlist and 3 â†’ Weather; device UI checks pass.
- **Done**: Preact shell and device-smoke mappings corrected; explicit preset 2/3 regression assertions added; 53 device-UI tests pass.

### P4 [platform] BERG design system tokens + card component Â· #4 âœ… Done
- **Goal**: shared visual layer for all screens.
- **Scope**: color tokens, DM Serif Display / JetBrains Mono / Space Grotesk, signature card
  recipe (hard outline + hard offset shadow), dark-desk chrome, min-size rules (â‰¥13px).
- **Constraints**: 800Ã—480 fixed; gruvbox TUI palette kept available as fallback theme.
- **Acceptance**: token module + card component render a sample screen matching the spec recipe.
- **Done**: `src/device-ui/` provides immutable BERG/gruvbox tokens, bundled fonts, reusable
  hard-outline/offset-shadow `Card`, and a visually checked 800Ã—480 feed sample; 6 tests pass.

### P5 [platform] 1-bit Atkinson dither utility Â· #5 âœ… Done
- **Goal**: shared image pipeline for album art (NP), covers (Playlist), photos (Photo frame).
- **Scope**: image â†’ 1-bit Atkinson-dithered bitmap sized for target slot; cache results.
- **Constraints**: host-side (P1); pure core fn; golden-image tests required.
- **Acceptance**: golden-image tests; visually matches mockups' dither character.
- **Done**: `host/lib/paper_weight/` provides Image/Resize/Atkinson/Bitmap/Cache; 11 tests pass,
  including the 8Ã—8 gradient golden PBM; user approved and #5 closed.

## Epic: now-playing (screen 4a)

### N1 [now-playing] Spotify data service Â· #6 Â· Done (lane wave 1)
- **Goal**: now-playing metadata, up-next queue, volume control.
- **Scope**: Spotify API/connect client; expose `now_playing()`, `queue()`, `set_volume(delta)`.
- **Constraints**: NO play/pause anywhere (flagged off); token refresh handled internally.
  Own only `host/lib/paper_weight/spotify/**` â€” see `features/now-playing/spec.md`.
- **Acceptance**: mocked-API tests; volume responds to wheel-tick deltas. Done: 31 mocked
  tests green under `host/test/paper_weight/spotify/`, see spec.md Next Session chunk.

### N2 [now-playing] Screen 4a UI Â· #7 Â· In review (PR #39)
- **Goal**: build final pick 4a.
- **Scope**: 1-bit dithered art square (P5), title/metadata, up-next queue pane (wheel scrolls
  queue is WRONG â€” wheel = volume; queue is display-only), footer "âŸ² volume Â· press words".
- **Constraints**: TUI/gruvbox chrome for now (reskin decision = D3); wheel press â†’ lyrics (N3).
- **Acceptance**: matches `now-playing-4a.png`; wheel=volume, press=lyrics overlay, no transport UI.
- **PR WIP**: pure Preact 4a screen â€” PBM art, metadata, progress, volume, display-only queue @
  800Ã—480; coexists with N3 `LyricsOverlay` on same tree after master merge.

### N3 [now-playing] Lyrics overlay â€” design + build Â· #8 âœ… Done
- **Goal**: press-to-toggle overlay over 4a (NOT a top-level screen). Not yet mocked.
- **Scope**: design in BERG language first (paper card over dimmed 4a suggested), then build;
  synced or static lyrics per what Spotify service exposes; press again / back dismisses.
- **Acceptance**: design snippet approved on the claude.ai/design canvas; overlay toggles on
  device without disturbing NP state.
- **Done**: PR #36 â€” `LyricsOverlay` BERG paper card + pure active-line sync; shell owns toggle;
  design snippet in feature spec; wave-3 wires `renderOverlay`.

## Epic: weather (screen 4b)

### W1 [weather] Weather data service â€” NWS + OpenUV Â· #9 âœ… Done
- **Goal**: current conditions, 5-day + 7-day forecast, hourly UV index.
- **Scope**: NWS forecast API + OpenUV client; walk-verdict generator (plain-spoken italic quote
  from temp/UV/precip windows); cache + periodic refresh (glanceable snapshot, not live).
  Own only `host/lib/paper_weight/weather/**` â€” see `features/weather/spec.md`.
- **Acceptance**: fixture tests incl. verdict phrasing rules; graceful stale-data state.
- **Done**: mocked NWS/OpenUV + pure grade/verdict/snapshot + stale path; `mix test test/paper_weight/weather/` green.

### W2 [weather] Screen 4b UI Â· #10 âœ… Done
- **Goal**: build final pick 4b.
- **Scope**: thin status topbar â†’ compact UV "WALK?" band (~Â¼ height; solid=extreme,
  dithered-lines=high, faint=low, legend â–®â–¤â–®) â†’ big current temp left + 5-day right â†’ footer.
  Wheel toggles today â†” 7-day.
- **Acceptance**: matches `weather-4b.png`; UV grading renders all three strengths correctly.
- **Done**: fixture-driven `WeatherScreen` @ 800Ã—480; pure `toggle-weather-range` 5dâ†”7d;
  UV bars/legend for extreme/high/low; no shell edits (wave 3 wires screen map).

## Epic: playlist (screen 4c)

### L1 [playlist] Playlist grid screen 4c Â· #11 âœ… Done
- **Goal**: build final pick 4c.
- **Scope**: 2Ã—3 (or 4-wide) dithered cover grid (P5), fat labels; selected tile pops onto paper
  card with â–¶; wheel walks grid, press plays via Spotify service (N1).
- **Acceptance**: matches `playlist-4c.png`; press starts playback and switches to Now Playing.
- **Done**: `screens/playlist/**` + `protocol/playlist.ts` (PR #34); pure reduce for wheel/play;
  fixture mockup names; play â†’ `play_playlist` args; NP host/navigate remains wave 3.

## Epic: feed (screen 4f)

### F1 [feed] X/Twitter snapshot service Â· #12 Â· Done
- **Goal**: periodic read-only feed snapshot.
- **Scope**: fetch N recent posts from followed handles/list; strip to text+handle+time;
  per-handle accent color assignment; refresh on interval.
  Own only `host/lib/paper_weight/feed/**` â€” see `features/feed/spec.md`.
- **Constraints**: read-only; snapshot semantics (no live updates mid-view).
- **Acceptance**: fixture snapshot renders â‰¥3 posts; refresh swaps atomically.

### F2 [feed] Screen 4f UI Â· #13 âœ… Done
- **Goal**: build final pick 4f (BERG-pushed 3d renderer).
- **Scope**: dark desk, ~3 posts visible, selected post on cream hard-outline+offset card, serif
  bodies, mono handles, dashed dividers, mustard footer, receipt-roll progress rail (right).
  Wheel scrolls, press enlarges, back collapses.
- **Constraints**: "Grus Gazette" mini-newspaper concept is REJECTED â€” do not build.
- **Acceptance**: matches `feed-4f.png`; big type readable on the 3.97" panel.
- **Done**: `src/device-ui/src/screens/feed/**` pure `reduceFeedUi` + `FeedScreen` @ 800Ã—480 BERG;
  ~3-post window, cream selected card, mustard footer, receipt rail; enlarge/collapse; 12 tests;
  no shell edits. Branch `lane/feed-f2`.

## Epic: photo (screen 4g)

### H1 [photo] Photo source + rotation service Â· #14 âœ… Done
- **Goal**: local photo library with slideshow rotation.
- **Scope**: photo ingest (local dir/drop), rotation timer ("reprints in X min"), ordering,
  "keep on show" pin (wheel press), skip (wheel turn); caption metadata.
- **Acceptance**: N/M counter + reprint countdown correct across skip/keep interactions.
- **Done**: `host/lib/paper_weight/photo/**` pure Rotate + Library scan + Service; 20 tests;
  payload frozen in `features/photo/spec.md` + `protocol/photo.ts`. No Application registration.

### H2 [photo] Screen 4g UI Â· #15 âœ… Done
- **Goal**: build final pick 4g.
- **Scope**: cream frame, true 1-bit Atkinson dither over the real photo (P5), printed serif
  caption, "photo N/M Â· reprints in X min" line.
- **Acceptance**: matches `photo-4g.png` with a real user photo.
- **Done**: `src/device-ui/src/screens/photo/**` BERG cream frame + P4â†’BMP art + status line;
  pure skip/keep local reducer; fixture Atkinson PBM; 10 photo tests. Mock PNG still pending
  for pixel QA. No shell / Application edits.

## Epic: etymology (screens 2aâ†’2bâ†’2c)

### E1 [etymology] Word-origin data service Â· #16 âœ… Done
- **Goal**: day's word + nested origin trace.
- **Scope**: Wiktionary-style source; recursive trace structure (stage â†’ sub-trace â†’ â€¦ â†’ root);
  daily selection; cache the day's tree.
- **Acceptance**: `travailler`-style fixture yields a â‰¥3-depth tree with a terminal root.
- **Done**: `host/lib/paper_weight/etymology/**` catalog + recursive tree + day cache GenServer;
  travel/travailler fixture depth â‰¥3 with trepÄlium terminal root; 16 tests green; payload
  frozen in `features/etymology/spec.md` + `protocol/etymology.ts`. No Application registration.

### E2 [etymology] Drill-down screen (one state machine, 3 depths) Â· #17 Â· In progress
- **Goal**: build 2a/2b/2c as ONE screen with depth states â€” not three screens.
- **Scope**: depth 0 = root-of-day + trace ladder (wheel scrolls stages); press digs into
  highlighted stage (depth 1, breadcrumb grows); bottom = dead-end reveal (depth 2); back walks
  breadcrumb up.
- **Acceptance**: matches all three `etymology-*.png` states; back from depth 0 does nothing.

## Epic: design (remaining design work â€” can run anytime)

### D1 [design] Home screen â€” design + build Â· #18 Â· Ready
- **Goal**: the button-hold target. Not yet mocked.
- **Scope**: design in BERG language on the claude.ai/design canvas, get approval, then build;
  likely a glanceable launcher/status card for the 6 screens.
- **Acceptance**: mock approved; hold from any screen lands here; presets 1â€“4 still work from it.

### D2 [design] Settings screen â€” design + build (konami entry) Â· #19 âœ… Done
- **Goal**: hidden config screen. Not yet mocked.
- **Scope**: konami-code entry (P3 hook), wheel moves field / press edits / back exits;
  minimal fields (wifi, brightness, feed handles, photo source, hold-threshold).
- **Acceptance**: mock approved; unreachable via presets; full wheel-only operation.
- **Done**: PR #37 â€” `screens/settings/**` BERG card + pure move/edit reduce; shell owns
  konami/back; wave-3 wires `SettingsScreen`.

### D3 [design] Decision â€” reskin 4a/4b/4c TUIâ†’BERG or keep two-layer mix Â· #20 Â· Ready
- **Goal**: settle the open visual question.
- **Scope**: try one screen (suggest 4b) in full BERG on the design canvas; compare on-device
  legibility vs gruvbox TUI chrome; document verdict in design spec + this board.
- **Acceptance**: written decision; follow-up reskin cards created OR question closed as "keep mix".
