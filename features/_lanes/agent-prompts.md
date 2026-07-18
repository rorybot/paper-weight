# Agent prompts — wave 1 (three parallel services)

Use **one worktree + one issue per agent**. Read only the files listed.  
Orchestrator doc: `docs/architecture/parallel-lanes-v1.md`.

---

## Shared preamble (every agent)

```text
Repo: paper-weight (Car Thing). Stack: host Elixir services + device Preact UI.
You are ONE parallel lane agent. Follow docs/architecture/parallel-lanes-v1.md ownership.
Do NOT edit: host application.ex, mix.exs, shell/, design/, other lanes, envelope protocol.
If you need a Mix dep, append "## Deps request" to your feature spec only.
Set your GitHub issue In progress via scripts/set-card-status.ps1 when you start;
Done only when acceptance checklist in your feature spec is met (close issue + board).
Work functional: pure cores, impure edges. Small modules.
```

---

## Agent A — Weather (W1 #9)

```text
[shared preamble]

Card: W1 #9 — Weather data service (NWS + OpenUV).
Read ONLY:
- features/weather/spec.md
- docs/architecture/host-device-protocol-v1.md
- docs/architecture/parallel-lanes-v1.md (ownership section)
- host/lib/paper_weight/dither/** is off-limits; you don't need it

Implement under:
- host/lib/paper_weight/weather/
- host/test/paper_weight/weather/
- src/device-ui/src/protocol/weather.ts (payload types only)

Acceptance: mocked NWS/OpenUV tests; UV grade + walk_verdict pure tests;
WeatherSnapshotV1; stale path; mix test green for your tests.
Do not start W2 UI in this session unless fixtures-only and separate commit.
```

---

## Agent B — Feed (F1 #12)

```text
[shared preamble]

Card: F1 #12 — X/Twitter snapshot service (read-only).
Read ONLY:
- features/feed/spec.md
- docs/architecture/host-device-protocol-v1.md
- docs/architecture/parallel-lanes-v1.md (ownership section)

Implement under:
- host/lib/paper_weight/feed/
- host/test/paper_weight/feed/
- src/device-ui/src/protocol/feed.ts (payload types only)

Acceptance: fixture ≥3 posts; stable accents; atomic snapshot replace;
stale path; no write APIs; mix test green for your tests.
Do not modify src/device-ui/src/sample/FeedSample.tsx (P4 fixture).
```

---

## Agent C — Spotify (N1 #6)

```text
[shared preamble]

Card: N1 #6 — Spotify data service.
Read ONLY:
- features/now-playing/spec.md
- docs/architecture/host-device-protocol-v1.md
- docs/architecture/parallel-lanes-v1.md (ownership section)
- host/lib/paper_weight/dither/** (call only, do not edit)

Implement under:
- host/lib/paper_weight/spotify/
- host/test/paper_weight/spotify/
- src/device-ui/src/protocol/now_playing.ts (payload types only)

Acceptance: mocked Spotify API tests; set_volume(delta) clamp 0–100;
NowPlayingSnapshotV1; NO play/pause; mix test green for your tests.
Intent name frozen: set_volume.
```

---

## How to launch (human / orchestrator)

```bash
# from repo root, after parallel-lanes doc is on master
git worktree add .worktrees/weather -b lane/weather-w1 master
git worktree add .worktrees/feed    -b lane/feed-f1    master
git worktree add .worktrees/spotify -b lane/spotify-n1 master

scripts/set-card-status.sh --issue 9  --status "In progress"
scripts/set-card-status.sh --issue 12 --status "In progress"
scripts/set-card-status.sh --issue 6  --status "In progress"
```

Open three agent sessions with cwd = each worktree; paste the matching prompt.

---

## Wave 2 prompts (after wave 1 green)

Same ownership tables in `parallel-lanes-v1.md`; cards W2 #10, F2 #13, N2 #7.  
Read own feature spec + **only** your mockup PNG under `spec/`.  
Do not edit shell; export screen component for wave-3 registry.

---

## Wave 3 Day-1 prompts (W3-A + W3-B parallel)

**Prerequisite:** PR #53 (W3-P1, protocol v1.1) must be merged to `master` first — W3-A's
fixture store needs the `playlist` channel already in `ChannelV1`. Do not start these agents
against an unmerged `master`.

Zero file overlap: W3-A is device-only (`src/device-ui/**`), W3-B is host-only (`host/**`).
Safe to run at the same time in separate worktrees. Neither is blocked by the other.

### Shared preamble (both agents)

```text
Repo: paper-weight (Car Thing). Stack: host Elixir services + device Preact UI.
You are ONE parallel wave-3 agent. Follow docs/architecture/parallel-lanes-v1.md ownership
and the constraints in your own card below — they override the wave-1 ownership table where
they differ (this is platform wiring, not a domain lane).
Set your GitHub issue In progress via scripts/set-card-status.sh when you start;
Done only when your card's acceptance is met (close issue + update kanban/board.md +
features/platform/spec.md card table, and append a Next Session Context Chunk there).
Work functional: pure cores, impure edges. Small modules. No unrelated refactors.
```

### Agent A — W3-A #44 (device shell screen map + channel store)

```text
[shared preamble]

Card: W3-A #44 — Device shell screen map + channel store.
Read ONLY:
- features/platform/spec.md
- docs/architecture/host-device-protocol-v1.md (envelope + channel union, read-only)
- src/device-ui/src/protocol/*.ts (payload types, read-only — do not edit)
- src/device-ui/src/shell/ShellApp.tsx, model.ts, router.ts, ScreenShell.tsx (read for context — model.ts/router.ts are off-limits to edit)

Goal: render every built screen and overlay from a single channel-to-snapshot store, seeded
by fixtures; route shell commands to screen props without networking.

Implement under:
- src/device-ui/src/shell/channelStore.ts (new) — pure applyEnvelope, stale-generation
  rejection, unknown-channel ignore, fixture store including playlist.
- src/device-ui/src/shell/ShellApp.tsx — wire real Now Playing, Feed, Photo, Playlist,
  Settings, Lyrics, and feed-detail components (currently only Weather/Home are wired).

Constraints:
- Branch: feat/w3a-shell-screen-map.
- Do NOT edit bridge.ts, router.ts, model.ts, screens/**, protocol/**, or anything under host/.
- No WebSocket/network code, no new dependencies, no play/pause.

Acceptance:
- Every ScreenId and overlay renders the real component from fixture data.
- Stale-generation and unknown-channel behavior are unit tested.
- npm run check passes (typecheck + tests + build).
```

### Agent B — W3-B #45 (host deps, Application children, runtime config)

```text
[shared preamble]

Card: W3-B #45 — Host deps, Application children, and runtime config.
Read ONLY:
- features/platform/spec.md
- docs/architecture/host-device-protocol-v1.md (read-only, for context only)
- host/lib/paper_weight/application.ex (current: Dither.Cache + weather_children/0 only)
- host/mix.exs
- host/config/config.exs

Goal: supervise all four service GenServers with per-service enablement and add the locked
WebSocket dependencies/configuration plumbing (nothing starts Bandit yet — that's W3-C).

Implement under:
- host/mix.exs — add bandit, websock_adapter, plug (and lockfile).
- host/lib/paper_weight/application.ex — generalize into a pure, testable children/1 that
  supports Weather, Spotify, Feed, and Photo as :enabled | :disabled each. Weather stays
  enabled by default; Spotify/Feed/Photo default to :disabled so zero-env tests pass.
- host/config/config.exs (or runtime.exs) — runtime config for Spotify auth, photo directory,
  feed URLs.
- host/test/ — tests for child specs across enable/disable combinations.

Constraints:
- Branch: feat/w3b-host-app-children.
- Do NOT modify service modules (weather/, spotify/, feed/, photo/ internals), envelope, or
  any device UI.
- Do NOT start Bandit or open a socket — deps + config only.

Acceptance:
- mix test passes with zero environment (all non-weather services disabled).
- All-enabled config yields four service child specs.
- Weather default behavior is unchanged.
- New dependencies compile in CI.
```

### How to launch (human / orchestrator)

```bash
# from repo root, once PR #53 is merged to master
git fetch
git worktree add .worktrees/w3a -b feat/w3a-shell-screen-map master
git worktree add .worktrees/w3b -b feat/w3b-host-app-children master

scripts/set-card-status.sh --issue 44 --status "In progress"
scripts/set-card-status.sh --issue 45 --status "In progress"
```

Open two agent sessions with cwd = each worktree; paste the matching prompt. Merge order
doesn't matter (disjoint trees) — land whichever finishes review first. Once both are Done,
W3-C #46 and W3-D #47 unblock (each still needs W3-P1 merged, which is already satisfied).
