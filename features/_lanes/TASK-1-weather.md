# TASK 1 — Weather lane agent

**You are the Weather agent only.** Other agents own Feed and Spotify in parallel.  
If the human says “Task 1”, this entire file is your brief.

| Field | Value |
|-------|--------|
| **Lane** | Weather |
| **Wave-1 card** | **W1** — issue **#9** |
| **Wave-2 card (later)** | W2 — issue #10 (do **not** start unless human asks) |
| **Channel** | `"weather"` |
| **Branch** | `lane/weather-w1` |
| **Worktree (suggested)** | `.worktrees/weather` |

---

## 1. Project context (read this, then ignore the rest of the repo)

Custom app for a reflashed Spotify Car Thing (800×480).  
**Host** = Elixir/OTP services (you work here).  
**Device** = Chromium kiosk + Preact UI (not your job in wave 1).

Stack decision: `docs/architecture/workflow-v1.md` (already done).  
Shell (presets, wheel, back) is **done** — weather wheel already maps to command `toggle-weather-range` for a future screen.  
You ship a **host data service** that can build a versioned **snapshot** the UI will consume later.

---

## 2. Your mission (wave 1 = W1 only)

**Goal:** Host weather data service: NWS forecast + OpenUV, walk-verdict text, cache + refresh, tests.

**Out of scope for Task 1:**
- Device UI / Preact screens (W2)
- WebSocket server / host gateway
- Editing the shell router
- Touching Spotify or Feed code
- Registering yourself in `Application` supervision tree (wave 3)

**Done when:** acceptance checklist in §8 is all green.

---

## 3. Paths you MAY edit

| Path | Purpose |
|------|---------|
| `host/lib/paper_weight/weather/**` | All Elixir modules for this lane |
| `host/test/paper_weight/weather/**` | Tests + JSON fixtures |
| `src/device-ui/src/protocol/weather.ts` | Payload types (keep in sync with snapshot) |
| `features/weather/spec.md` | Append Deps request + Next Session chunk only |

### Suggested module layout (you may refine names)

```text
host/lib/paper_weight/weather/
  service.ex          # GenServer: poll, cache, last snapshot, stale flag
  fetch.ex            # impure: HTTP to NWS + OpenUV (inject client for tests)
  nws.ex              # pure-ish parse NWS JSON → intermediate
  open_uv.ex          # pure-ish parse OpenUV JSON → intermediate
  grade.ex            # pure: UV index → :extreme | :high | :low
  verdict.ex          # pure: walk_verdict/1 sentence
  snapshot.ex         # pure: assemble WeatherSnapshot map for protocol
  config.ex           # lat/lon, refresh interval, User-Agent (NWS requires one)

host/test/paper_weight/weather/
  fixtures/           # saved API JSON
  grade_test.exs
  verdict_test.exs
  snapshot_test.exs
  fetch_test.exs      # mocked HTTP
  service_test.exs
```

---

## 4. Paths you MUST NOT edit

| Path | Why |
|------|-----|
| `host/lib/paper_weight/application.ex` | Orchestrator wires children in wave 3 |
| `host/mix.exs` | Request deps in feature spec only |
| `host/lib/paper_weight/protocol/**` | Frozen envelope |
| `host/lib/paper_weight/feed/**` | Feed agent |
| `host/lib/paper_weight/spotify/**` | Spotify agent |
| `host/lib/paper_weight/dither/**` | P5 done — not weather |
| `src/device-ui/src/shell/**` | P3 frozen |
| `src/device-ui/src/design/**` | P4 frozen |
| `src/device-ui/src/main.tsx`, `ShellApp.tsx` | Wave 3 |
| `src/device-ui/src/protocol/envelope.ts` | Frozen |
| `src/device-ui/src/protocol/feed.ts`, `now_playing.ts` | Other lanes |
| `src/device-ui/src/screens/**` | Wave 2 only if asked |
| Other agents’ `features/*` specs | Except you may only append to `features/weather/spec.md` |

If you need a Mix dependency:

```md
## Deps request
- mix: <package> ~> <ver>  (reason: …)
```

Append to `features/weather/spec.md`. **Do not** edit `mix.exs` yourself.  
Prefer **no new deps** if `:httpc` / stdlib is enough for mocked tests.

---

## 5. Snapshot contract (must match)

Types live in `src/device-ui/src/protocol/weather.ts`. Elixir maps should use **string keys** or a documented atom↔JSON convention that serializes to this shape:

```ts
type WeatherSnapshotV1 = {
  location_label: string;       // e.g. "Castle Rock, CO"
  as_of: string;                // ISO-8601
  stale: boolean;
  current: {
    temp_f: number;
    summary: string;
  };
  walk_verdict: string;         // plain-spoken one-liner for UI quote
  uv: {
    index: number;              // 0–11+ style
    grade: "extreme" | "high" | "low";
  };
  days5: WeatherDayV1[];        // main pane
  days7: WeatherDayV1[];        // wheel toggles to this
  hourly_uv: { hour_local: string; index: number }[];
};

type WeatherDayV1 = {
  date: string;                 // YYYY-MM-DD
  high_f: number;
  low_f: number;
  summary: string;
};
```

### UV grade rules (locked)

| Grade | Rule |
|-------|------|
| `extreme` | index ≥ 8 |
| `high` | 6 ≤ index < 8 |
| `low` | index < 6 |

### Walk verdict

Pure function: inputs = temp / UV / precip (or simplified windows from fixtures) → **one** plain-spoken English sentence (no emoji spam).  
Document rules in tests (e.g. high UV + hot → caution outdoor language; cold + precip → different line). Keep deterministic for the same inputs.

### Envelope (you do not implement WS)

Host will later wrap your payload as:

```json
{ "v": 1, "ts": 1721150000000, "channel": "weather", "gen": 42, "payload": { /* WeatherSnapshotV1 */ } }
```

Optional helper: `PaperWeight.Protocol.Envelope.wrap(:weather, gen, payload)` already exists — you may **call** it in tests; do not modify that module.

---

## 6. Host API surface

| Function / behavior | Notes |
|---------------------|--------|
| `fetch_snapshot(config)` | Impure; `{:ok, snapshot}` \| `{:error, reason}` |
| `grade_uv(index)` | Pure |
| `walk_verdict(inputs)` | Pure |
| GenServer service | Periodic refresh; keep last good snapshot; on failure keep last good + `stale: true` |
| Config | lat/lon (default Castle Rock / Denver metro OK), refresh interval, NWS User-Agent string |

**NWS:** free, no key; requires a descriptive User-Agent.  
**OpenUV:** typically needs API key via config/env — support `OPENUV_API_KEY` or config; tests must **never** call real network (mock).

### Supervisor child (document only — do not register)

```elixir
{PaperWeight.Weather.Service, []}
```

Keep that line in `features/weather/spec.md` under Supervisor child.

---

## 7. Design / product notes (for data shape, not UI)

Future W2 UI (`spec/weather-4b.png`): topbar, UV “WALK?” band (~¼ height), big temp + 5-day, wheel toggles 5↔7 day.  
Your snapshot fields must be enough for that UI. You do **not** build the UI in Task 1.

Shell already routes weather wheel → `toggle-weather-range` (screen-local later).

---

## 8. Acceptance checklist (W1)

- [ ] Mocked HTTP tests for NWS + OpenUV adapters (no live network in CI)
- [ ] Pure tests for UV grade (all three grades)
- [ ] Pure tests for walk_verdict phrasing rules
- [ ] Snapshot assembly matches `WeatherSnapshotV1` field set
- [ ] Failure path: last good cache + `stale: true`
- [ ] `mix test` passes for `host/test/paper_weight/weather/` (and does not break other host tests)
- [ ] No edits to forbidden paths
- [ ] Deps request noted if needed
- [ ] Append 3–5 line **Next Session Context Chunk** to `features/weather/spec.md`

---

## 9. GitHub / board hygiene

```powershell
# when you start real work:
powershell -File scripts/set-card-status.ps1 -Issue 9 -Status "In progress"

# when acceptance met:
powershell -File scripts/set-card-status.ps1 -Issue 9 -Status "Done"
# (script may close issue; if not: gh issue close 9 --repo rorybot/paper-weight)
```

Then update **only** weather rows in:
- `kanban/board.md` (W1 heading/status if you touch board)
- `features/weather/spec.md` card table

Do **not** change other cards’ statuses.

Auth: Windows `gh` keyring. Run `scripts/check-gh-auth.ps1` if needed. Do not re-login unless that fails.

---

## 10. Code style

- Functional: pure cores, impure edges, immutability
- Small single-purpose modules
- Prefer injectable HTTP client (fn or behaviour) for tests
- No play/pause anything (not your domain anyway)

---

## 11. Start sequence

1. Confirm cwd is this repo (or weather worktree on `lane/weather-w1`).
2. Set #9 → **In progress**.
3. Read only this file + `features/weather/spec.md` + existing `src/device-ui/src/protocol/weather.ts`.
4. Implement modules + tests under your paths.
5. Run weather tests; fix until green.
6. Mark Done + Next Session chunk when checklist complete.
7. Stop. Do not start W2 unless human explicitly assigns screen work.

---

## 12. What “good” looks like

A reviewer can:

```text
cd host
mix test test/paper_weight/weather/
```

and see clear fixture-driven coverage, and can `PaperWeight.Weather.Service` (or equivalent) return a full snapshot map without opening a browser or editing shared app startup.
