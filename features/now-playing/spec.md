# Feature: now-playing

Lane owner for **N1** (Spotify service) + **N2** (screen 4a) + later **N3** (lyrics).  
Parallel rules: `docs/architecture/parallel-lanes-v1.md`.  
Protocol envelope: `docs/architecture/host-device-protocol-v1.md`.

## Cards

| ID | Issue | Title | Status |
|----|-------|-------|--------|
| N1 | [#6](https://github.com/rorybot/paper-weight/issues/6) | Spotify data service | **Done** |
| N2 | [#7](https://github.com/rorybot/paper-weight/issues/7) | Screen 4a UI | Backlog (wave 2) |
| N3 | [#8](https://github.com/rorybot/paper-weight/issues/8) | Lyrics overlay | Backlog (after N2) |

## Ownership (only these paths)

| Area | Path |
|------|------|
| Host service | `host/lib/paper_weight/spotify/**` |
| Host tests | `host/test/paper_weight/spotify/**` |
| Device screen | `src/device-ui/src/screens/now-playing/**` |
| Payload types | `src/device-ui/src/protocol/now_playing.ts` |
| Fixtures | under own test dirs |

**Do not touch:** `application.ex`, `mix.exs`, shell, design tokens, other lanes.  
**Dither:** call existing `PaperWeight.Dither` (P5) — do not modify dither modules; optional thin wrapper under `spotify/` for album art slots only.

## Channel

`channel: "now_playing"`

## Payload contract (N1 freezes this)

```ts
type NowPlayingSnapshotV1 = {
  as_of: string;
  stale: boolean;
  track: null | {
    title: string;
    artist: string;
    album: string;
    /** host-relative or data URL for pre-dithered 1-bit art; may be null while loading */
    art_pbm_base64: string | null;
    duration_ms: number;
    progress_ms: number;
  };
  /** display-only; wheel does NOT scroll this */
  queue: { title: string; artist: string }[];
  volume: {
    /** 0–100 */
    level: number;
  };
  /** N3 may use later; N1 may stub null */
  lyrics: null | { lines: { t_ms: number; text: string }[] };
};
```

## Host API (N1)

| Function | Role |
|----------|------|
| `now_playing() → snapshot` | from cache / last poll |
| `queue() → list` | subset of snapshot |
| `set_volume(delta) → {:ok, level} \| {:error, _}` | impure; clamped 0–100 |
| Token refresh | internal to spotify client |

### Intents (device → host)

```json
{ "v": 1, "type": "intent", "name": "set_volume", "args": { "delta": 1 } }
```

### Constraints
- **NO play/pause** API or UI.
- Wheel = volume only (shell already emits `adjust-volume`).

### Supervisor child (wave 3)

```elixir
{PaperWeight.Spotify.Service, []}
```

## Screen (N2) — local only

- Shell: wheel → `adjust-volume` command (forward as intent in wave 3); press → lyrics overlay (shell).
- Mockup: `spec/now-playing-4a.png`.
- Chrome: gruvbox TUI until D3.
- Queue pane display-only.

## Acceptance

### N1
- [x] Mocked Spotify HTTP tests
- [x] `set_volume(delta)` clamps and returns new level
- [x] Snapshot matches `NowPlayingSnapshotV1`
- [x] No play/pause endpoints
- [x] No Application / mix.exs edits

### N2
- [ ] Matches now-playing-4a intent
- [ ] Shows art / title / queue / volume affordance
- [ ] No transport controls
- [ ] No shell edits

## Deps request

- mix: none added — client/auth use Erlang `:httpc` (like the weather lane), injected
  as an HTTP fn so tests never hit the network.
  (reason: Spotify Web API + Accounts token exchange over HTTPS)
- For **live** (non-test) calls, wave-3 orchestrator needs to add `:inets` and `:ssl`
  to `extra_applications` in `host/mix.exs` — same requirement weather already has.
  Mocked tests do not need this.

## Next Session Context Chunk

- N1 done: `host/lib/paper_weight/spotify/{config,json_lite,auth,client,volume,snapshot,fetch,art,service}.ex`
  + full test suite under `host/test/paper_weight/spotify/` (31 tests, mocked HTTP, no live network).
  Run: `cd host && mix test test/paper_weight/spotify/`.
- Public API: `PaperWeight.Spotify.Service.now_playing/1`, `.queue/1`, `.set_volume/2` (delta,
  clamped 0..100, best-effort persisted to Spotify then cached even on API failure).
  **No** play/pause/skip/previous anywhere in the module.
- Snapshot assembly (`Snapshot.assemble/1`) is pure and matches `NowPlayingSnapshotV1` exactly;
  `art_pbm_base64` ships `null` — `Spotify.Art.dither_to_base64/3` wraps P5 dither (untouched)
  for when N2/L1 wire real album-art bytes in.
  On poll failure the service keeps the last-good snapshot and flips `stale: true`.
- Token refresh (`Auth.refresh_access_token/2`) and the Spotify client are both HTTP-injected;
  swap in `Auth.default_http_post/0` / `Client.default_http/0` (both use `:httpc`) for wave-3 wiring.
- Volume intent name frozen: `set_volume`. Use P5 dither as library; don't edit it.
- Not done (by design, N1 scope): Preact screen (N2), lyrics content (N3), Application/mix.exs
  registration (wave 3), playlist play-by-id (L1).
