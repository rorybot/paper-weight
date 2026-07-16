# TASK 3 — Spotify / Now Playing lane agent

**You are the Spotify (now-playing) agent only.** Other agents own Weather and Feed in parallel.  
If the human says “Task 3”, this entire file is your brief.

| Field | Value |
|-------|--------|
| **Lane** | Now Playing / Spotify |
| **Wave-1 card** | **N1** — issue **#6** |
| **Wave-2 card (later)** | N2 — issue #7 (UI; only if human asks) |
| **Wave-3 later** | N3 lyrics overlay design — **not** Task 3 |
| **Channel** | `"now_playing"` |
| **Branch** | `lane/spotify-n1` |
| **Worktree (suggested)** | `.worktrees/spotify` |

---

## 1. Project context (read this, then ignore the rest of the repo)

Custom app for a reflashed Spotify Car Thing (800×480).  
**Host** = Elixir/OTP (you). **Device** = Preact kiosk (not wave 1).

Product rules that matter to you:
- **NO play/pause** anywhere (global flag) — do not implement transport controls or APIs that start/stop for UI.
- **Wheel = volume** (shell already emits `adjust-volume` with a delta).
- Queue is **display-only** (wheel does not scroll the queue).
- Lyrics may appear later (N3); you may stub `lyrics: null` or a minimal structure.

**P5 dither** already exists: `host/lib/paper_weight/dither/**`. You may **call** it for album art → 1-bit; **do not edit** dither modules. If art pipeline is heavy, `art_pbm_base64: null` is OK in v1 tests with a separate pure unit that dithers a fixture when wired.

---

## 2. Your mission (wave 1 = N1 only)

**Goal:** Spotify data service on host:

- Now-playing metadata  
- Up-next queue  
- Volume get + `set_volume(delta)` with clamp  
- Token refresh internal  
- Snapshot matching protocol types  
- Mocked API tests  

**Out of scope for Task 3:**
- Preact screen N2 (`spec/now-playing-4a.png`)
- Lyrics overlay design N3  
- Playlist grid L1 (may call you later for play-by-id — not now)  
- `Application` registration / WebSocket gateway  
- Weather / Feed code  

**Done when:** acceptance checklist in §8 is green.

---

## 3. Paths you MAY edit

| Path | Purpose |
|------|---------|
| `host/lib/paper_weight/spotify/**` | All Elixir for this lane |
| `host/test/paper_weight/spotify/**` | Tests + fixtures |
| `src/device-ui/src/protocol/now_playing.ts` | Payload types |
| `features/now-playing/spec.md` | Deps request + Next Session chunk |

### Suggested module layout

```text
host/lib/paper_weight/spotify/
  service.ex          # GenServer: poll NP + queue + volume cache
  client.ex           # impure Spotify Web API (injectable)
  auth.ex             # token refresh (impure; mock in tests)
  volume.ex           # pure: clamp level 0..100 after delta
  snapshot.ex         # assemble NowPlayingSnapshot
  art.ex              # optional: fetch image bytes → call PaperWeight.Dither
  config.ex           # client id/secret/refresh via env

host/test/paper_weight/spotify/
  fixtures/
  volume_test.exs
  snapshot_test.exs
  client_test.exs     # mocked HTTP
  service_test.exs
```

---

## 4. Paths you MUST NOT edit

| Path | Why |
|------|-----|
| `host/lib/paper_weight/application.ex` | Wave 3 |
| `host/mix.exs` | Deps request only |
| `host/lib/paper_weight/protocol/**` | Frozen envelope |
| `host/lib/paper_weight/dither/**` | Call only — P5 locked |
| `host/lib/paper_weight/weather/**` | Weather agent |
| `host/lib/paper_weight/feed/**` | Feed agent |
| `src/device-ui/src/shell/**` | P3 frozen |
| `src/device-ui/src/design/**` | P4 frozen |
| `src/device-ui/src/main.tsx`, `ShellApp.tsx` | Wave 3 |
| `src/device-ui/src/protocol/envelope.ts` | Frozen |
| `src/device-ui/src/protocol/weather.ts`, `feed.ts` | Other lanes |
| `src/device-ui/src/screens/**` | Wave 2 unless asked |

Deps:

```md
## Deps request
- mix: <package> ~> <ver>  (reason: Spotify HTTP)
```

in `features/now-playing/spec.md` only.

---

## 5. Snapshot contract (must match)

`src/device-ui/src/protocol/now_playing.ts`:

```ts
type NowPlayingTrackV1 = {
  title: string;
  artist: string;
  album: string;
  art_pbm_base64: string | null;  // pre-dithered 1-bit; null OK while loading
  duration_ms: number;
  progress_ms: number;
};

type NowPlayingSnapshotV1 = {
  as_of: string;                  // ISO-8601
  stale: boolean;
  track: NowPlayingTrackV1 | null;
  queue: { title: string; artist: string }[];  // display-only
  volume: { level: number };      // 0–100
  lyrics: null | { lines: { t_ms: number; text: string }[] };
};
```

### Envelope

```json
{ "v": 1, "ts": …, "channel": "now_playing", "gen": 3, "payload": { /* snapshot */ } }
```

### Device → host intent (you implement handler in service; not WS server)

```json
{ "v": 1, "type": "intent", "name": "set_volume", "args": { "delta": 1 } }
```

Public function shape:

```elixir
set_volume(delta :: integer()) :: {:ok, new_level :: 0..100} | {:error, term()}
```

- Apply delta to cached level (or Spotify API).  
- **Clamp** to 0..100.  
- Tests must cover positive delta, negative delta, clamp at 0 and 100.

---

## 6. Host API surface (card contract)

| API | Behavior |
|-----|----------|
| `now_playing()` | Current snapshot or track section from cache |
| `queue()` | Queue list (subset of snapshot) |
| `set_volume(delta)` | As above; **no** play/pause |
| Token refresh | Internal to client/auth; tests mock tokens |

### Explicit bans

- No `play`, `pause`, `skip`, `previous` in public API for this card  
- No transport fields on the snapshot meant for UI buttons  

### Supervisor child (document only)

```elixir
{PaperWeight.Spotify.Service, []}
```

---

## 7. Product notes (for N2 later)

Mockup `spec/now-playing-4a.png`: dithered art, title/meta, up-next pane, footer `⟲ volume · press words`.  
Chrome: gruvbox TUI until design decision D3.  
Wheel press → lyrics overlay (shell toggles overlay; N3 fills content).

Your volume + snapshot fields must feed that UI. You do not build the UI in Task 3.

### Using P5 dither (optional in N1)

```elixir
# conceptual — use existing PaperWeight.Dither / Image pipeline
# Input: grayscale or RGB buffer from album art download
# Output: packed bitmap / PBM → Base64 for art_pbm_base64
```

If wiring art is large, ship `art_pbm_base64: null` in happy-path fixtures and unit-test dither integration separately with a tiny fixture image.

---

## 8. Acceptance checklist (N1)

- [ ] Mocked Spotify HTTP tests (no live network required for CI)
- [ ] `set_volume(delta)` tested: up, down, clamp 0, clamp 100
- [ ] Snapshot matches `NowPlayingSnapshotV1` field set
- [ ] Queue present and display-oriented (list of title/artist)
- [ ] **No** play/pause public API
- [ ] Stale path when poll fails (keep last snapshot + `stale: true`)
- [ ] `mix test test/paper_weight/spotify/` green
- [ ] No forbidden path edits; dither modules untouched
- [ ] Deps request if needed
- [ ] Next Session Context Chunk on `features/now-playing/spec.md`

---

## 9. GitHub / board hygiene

```powershell
powershell -File scripts/set-card-status.ps1 -Issue 6 -Status "In progress"
# when done:
powershell -File scripts/set-card-status.ps1 -Issue 6 -Status "Done"
```

Update only now-playing / N1 status in specs/board. Do not touch W1/F1 cards.

---

## 10. Code style

- Functional pure cores (`volume` clamp, snapshot map)
- Impure client/auth at edges
- Injectable HTTP for tests
- Secrets only via env/config — never commit tokens

---

## 11. Start sequence

1. Work on `lane/spotify-n1` (or `.worktrees/spotify`).
2. Set #6 → **In progress**.
3. Read this file + `features/now-playing/spec.md` + `src/device-ui/src/protocol/now_playing.ts`.
4. Optionally skim `host/lib/paper_weight/dither.ex` public API (do not edit).
5. Implement + test.
6. Green → Done + context chunk.
7. Stop. Do not start N2/N3 unless asked.

---

## 12. What “good” looks like

```text
cd host
mix test test/paper_weight/spotify/
```

Mocked client returns a full snapshot; `set_volume(5)` and `set_volume(-100)` behave correctly; no transport controls exist in the module API.
