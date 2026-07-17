# TASK 2 — Feed lane agent

**You are the Feed agent only.** Other agents own Weather and Spotify in parallel.  
If the human says “Task 2”, this entire file is your brief.

| Field | Value |
|-------|--------|
| **Lane** | Feed (X/Twitter snapshot) |
| **Wave-1 card** | **F1** — issue **#12** |
| **Wave-2 card (later)** | F2 — issue #13 (do **not** start unless human asks) |
| **Channel** | `"feed"` |
| **Branch** | `lane/feed-f1` |
| **Worktree (suggested)** | `.worktrees/feed` |

---

## 1. Project context (read this, then ignore the rest of the repo)

Custom app for a reflashed Spotify Car Thing (800×480).  
**Host** = Elixir/OTP services (you work here).  
**Device** = Chromium kiosk + Preact UI (not your job in wave 1).

There is already a **visual** fixture `src/device-ui/src/sample/FeedSample.tsx` for P4 design tokens — that is **not** your production screen and you **must not** modify it. Your job is the **host snapshot service** (+ protocol types).

Shell is done: feed wheel → `scroll-feed`, press → `feed-detail` overlay, back dismisses. You only supply data.

---

## 2. Your mission (wave 1 = F1 only)

**Goal:** Periodic **read-only** feed snapshot service: N recent posts from configured handles/list, strip to text+handle+time, per-handle accent colors, interval refresh with **atomic** replace.

**Out of scope for Task 2:**
- Device UI / F2 screen (BERG layout matching `spec/feed-4f.png`)
- Editing `FeedSample.tsx`
- Posting, liking, replying, or any write API
- WebSocket server / `Application` registration
- Weather or Spotify modules

**Done when:** acceptance checklist in §8 is all green.

---

## 3. Paths you MAY edit

| Path | Purpose |
|------|---------|
| `host/lib/paper_weight/feed/**` | All Elixir modules for this lane |
| `host/test/paper_weight/feed/**` | Tests + fixtures |
| `src/device-ui/src/protocol/feed.ts` | Payload types |
| `features/feed/spec.md` | Deps request + Next Session chunk only |

### Suggested module layout

```text
host/lib/paper_weight/feed/
  service.ex          # GenServer: refresh interval, cache, gen counter
  fetch.ex            # impure HTTP / API client (injectable)
  strip.ex            # pure: raw post → {id, handle, body, time_label}
  accent.ex           # pure: handle → stable accent color string
  snapshot.ex         # pure: assemble FeedSnapshot
  config.ex           # handles list, limit N, refresh ms, API token env

host/test/paper_weight/feed/
  fixtures/           # sample API payloads
  strip_test.exs
  accent_test.exs
  snapshot_test.exs
  fetch_test.exs
  service_test.exs
```

---

## 4. Paths you MUST NOT edit

| Path | Why |
|------|-----|
| `host/lib/paper_weight/application.ex` | Wave 3 |
| `host/mix.exs` | Deps request only |
| `host/lib/paper_weight/protocol/**` | Frozen envelope |
| `host/lib/paper_weight/weather/**` | Weather agent |
| `host/lib/paper_weight/spotify/**` | Spotify agent |
| `host/lib/paper_weight/dither/**` | Unrelated |
| `src/device-ui/src/sample/FeedSample.tsx` | P4 fixture — leave it |
| `src/device-ui/src/shell/**` | P3 frozen |
| `src/device-ui/src/design/**` | P4 frozen |
| `src/device-ui/src/main.tsx`, `ShellApp.tsx` | Wave 3 |
| `src/device-ui/src/protocol/envelope.ts` | Frozen |
| `src/device-ui/src/protocol/weather.ts`, `now_playing.ts` | Other lanes |
| `src/device-ui/src/screens/**` | Wave 2 unless asked |

Deps needed? Append to `features/feed/spec.md`:

```md
## Deps request
- mix: <package> ~> <ver>  (reason: …)
```

Prefer mocked HTTP with stdlib if possible. **No live network in tests.**

---

## 5. Snapshot contract (must match)

`src/device-ui/src/protocol/feed.ts`:

```ts
type FeedPostV1 = {
  id: string;
  handle: string;               // "@name"
  body: string;                 // plain text, stripped of junk
  time_label: string;           // "3m" / "1h" — host formats for display
  accent: string;               // CSS color or stable token string per handle
};

type FeedSnapshotV1 = {
  as_of: string;                // ISO-8601
  stale: boolean;
  posts: FeedPostV1[];          // full replace on each successful refresh
};
```

### Semantics (locked)

| Rule | Detail |
|------|--------|
| Read-only | No write endpoints |
| Snapshot | Not a live stream; device shows last full list |
| Atomic refresh | New list replaces old entirely; bump a generation counter in the service for later WS `gen` |
| Accents | Same handle → same accent across refreshes (deterministic hash or fixed palette map) |
| Minimum | Fixture must produce **≥ 3** posts |

### Envelope (do not implement WS)

```json
{ "v": 1, "ts": …, "channel": "feed", "gen": 7, "payload": { /* FeedSnapshotV1 */ } }
```

You may **call** `PaperWeight.Protocol.Envelope.wrap(:feed, gen, payload)` in tests only.

---

## 6. Host API surface

| Function / behavior | Notes |
|---------------------|--------|
| `fetch_snapshot(config)` | Impure → `{:ok, snapshot}` \| `{:error, _}` |
| `strip_post(raw)` | Pure enough to unit test |
| `assign_accents(handles)` or per-post accent | Deterministic |
| GenServer | Interval refresh; on error keep last posts + `stale: true` |
| Config | List of handles or list id; `N` posts; refresh interval; API credentials via env |

### API source note

X/Twitter access is painful (auth, paid tiers). For W1 acceptance it is **OK** to:

1. Define a narrow “raw post” internal struct, and  
2. Implement fetch behind a behaviour with a **fixture provider** default for tests, plus a real client module stubbed or clearly marked TODO if credentials missing.

Do **not** block on live X API. Acceptance is **fixture snapshot ≥3 posts** + atomic refresh + accents + stale path.

### Supervisor child (document only)

```elixir
{PaperWeight.Feed.Service, []}
```

---

## 7. Product notes (data for future F2 UI)

Mockup: `spec/feed-4f.png` — dark desk, ~3 posts, selected cream hard-outline card, mono handles, serif bodies.  
**Rejected:** “Grus Gazette” newspaper concept — do not design data for that.  
F2 will use P4 `Card` component; your posts just need handle/body/time/accent/id.

---

## 8. Acceptance checklist (F1)

- [ ] Fixture (or mocked HTTP) yields snapshot with **≥ 3** posts
- [ ] Accents stable for a fixed handle set
- [ ] Refresh replaces entire `posts` array (atomic); gen/monotonic counter covered in tests
- [ ] Strip pipeline produces plain text body + `@handle` + time_label
- [ ] Stale path on fetch failure
- [ ] No write/like/post APIs
- [ ] `mix test test/paper_weight/feed/` green
- [ ] No forbidden path edits
- [ ] Deps request if needed
- [ ] Next Session Context Chunk on `features/feed/spec.md`

---

## 9. GitHub / board hygiene

```bash
scripts/set-card-status.sh --issue 12 --status "In progress"
# when done:
scripts/set-card-status.sh --issue 12 --status "Done"
```

Update only feed rows in `features/feed/spec.md` / board if you touch status text.  
Do not change weather or Spotify cards.

---

## 10. Code style

- Pure strip/accent/snapshot; impure fetch at the edge
- Injectable client for tests
- Small modules; no shared globals with other lanes
- Functional / immutable style

---

## 11. Start sequence

1. Work on `lane/feed-f1` (or `.worktrees/feed`).
2. Set #12 → **In progress**.
3. Read this file + `features/feed/spec.md` + `src/device-ui/src/protocol/feed.ts`.
4. Implement + test under your paths only.
5. Green tests → Done + context chunk.
6. Stop. Do not start F2 unless asked.

---

## 12. What “good” looks like

```text
cd host
mix test test/paper_weight/feed/
```

Service (or pure pipeline) returns a `FeedSnapshotV1`-shaped map with ≥3 posts; second refresh with different fixture fully replaces posts; accents unchanged for same handles.
