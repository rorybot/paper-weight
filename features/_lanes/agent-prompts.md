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
