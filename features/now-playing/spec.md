# Feature: now-playing

Lane owner for **N1** (Spotify service) + **N2** (screen 4a) + later **N3** (lyrics).  
Parallel rules: `docs/architecture/parallel-lanes-v1.md`.  
Protocol envelope: `docs/architecture/host-device-protocol-v1.md`.

## Cards

| ID | Issue | Title | Status |
|----|-------|-------|--------|
| N1 | [#6](https://github.com/rorybot/paper-weight/issues/6) | Spotify data service | **Ready** (lane wave 1) |
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
- [ ] Mocked Spotify HTTP tests
- [ ] `set_volume(delta)` clamps and returns new level
- [ ] Snapshot matches `NowPlayingSnapshotV1`
- [ ] No play/pause endpoints
- [ ] No Application / mix.exs edits

### N2
- [ ] Matches now-playing-4a intent
- [ ] Shows art / title / queue / volume affordance
- [ ] No transport controls
- [ ] No shell edits

## Deps request

_(lane agents append here — e.g. HTTP client for Spotify)_

## Next Session Context Chunk

- Parallel lane ready: own only `host/lib/paper_weight/spotify/` + tests + protocol now_playing types.
- Volume intent name frozen: `set_volume`. Use P5 dither as library; don’t edit it.
