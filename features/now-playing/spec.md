# Feature: now-playing

Lane owner for **N1** (Spotify service) + **N2** (screen 4a) + later **N3** (lyrics).  
Parallel rules: `docs/architecture/parallel-lanes-v1.md`.  
Protocol envelope: `docs/architecture/host-device-protocol-v1.md`.

## Cards

| ID | Issue | Title | Status |
|----|-------|-------|--------|
| N1 | [#6](https://github.com/rorybot/paper-weight/issues/6) | Spotify data service | **Done** |
| N2 | [#7](https://github.com/rorybot/paper-weight/issues/7) | Screen 4a UI | **In review** (`PR #39`) |
| N3 | [#8](https://github.com/rorybot/paper-weight/issues/8) | Lyrics overlay | **Done** (PR #36) |

## Ownership (only these paths)

| Area | Path |
|------|------|
| Host service | `host/lib/paper_weight/spotify/**` |
| Host tests | `host/test/paper_weight/spotify/**` |
| Device screen | `src/device-ui/src/screens/now-playing/**` |
| Payload types | `src/device-ui/src/protocol/now_playing.ts` |
| Fixtures | under own test dirs |

**Do not touch:** `application.ex`, `mix.exs`, shell, design tokens, other lanes.  
**Dither:** call existing `PaperWeight.Dither` (P5) â€” do not modify dither modules; optional thin wrapper under `spotify/` for album art slots only.

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
    /** 0â€“100 */
    level: number;
  };
  /** N3 may use later; N1 may stub null */
  lyrics: null | { lines: { t_ms: number; text: string }[] };
};
```

## Host API (N1)

| Function | Role |
|----------|------|
| `now_playing() â†’ snapshot` | from cache / last poll |
| `queue() â†’ list` | subset of snapshot |
| `set_volume(delta) â†’ {:ok, level} \| {:error, _}` | impure; clamped 0â€“100 |
| Token refresh | internal to spotify client |

### Intents (device â†’ host)

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

## Screen (N2) â€” local only

- Shell: wheel â†’ `adjust-volume` command (forward as intent in wave 3); press â†’ lyrics overlay (shell).
- Mockup: `spec/now-playing-4a.png`.
- Chrome: gruvbox TUI until D3.
- Queue pane display-only.

## Lyrics overlay (N3) â€” design snippet (approved direction)

Not on the design canvas; card + design-spec interaction map are authoritative:

| Element | Spec |
|---------|------|
| Layer | Shell `overlay: "lyrics"` over 4a (not a top-level screen) |
| Backdrop | Existing shell dim (`[data-shell-layer="overlay"]`) |
| Card | BERG **paper** card, hard outline + accent offset shadow |
| Content | Timed lines from `snapshot.lyrics`; active = last `t_ms â‰¤ progress_ms` |
| Empty | `lyrics: null` or empty lines â†’ â€œno lyrics for this trackâ€ |
| Dismiss | Shell: press again or **back** (no local state mutation of NP) |
| Wheel | Still volume on now-playing (shell); overlay is display-only |

Device tree: `src/device-ui/src/screens/now-playing/{LyricsOverlay,lyricsModel,fixture}.*`

## Acceptance

### N1
- [x] Mocked Spotify HTTP tests
- [x] `set_volume(delta)` clamps and returns new level
- [x] Snapshot matches `NowPlayingSnapshotV1`
- [x] No play/pause endpoints
- [x] No Application / mix.exs edits

### N2
- [x] Matches now-playing-4a intent
- [x] Shows art / title / queue / volume affordance
- [x] No transport controls
- [x] No shell edits

### N3
- [x] BERG paper-card overlay UI (fixture-driven)
- [x] Pure active-line sync from `progress_ms`
- [x] Empty state when `lyrics` null
- [x] No shell / Application edits (shell already toggles `lyrics`)
- [ ] Wave-3: `ShellApp.renderOverlay("lyrics")` â†’ `LyricsOverlay`

## Deps request

- mix: none added â€” client/auth use Erlang `:httpc` (like the weather lane), injected
  as an HTTP fn so tests never hit the network.
  (reason: Spotify Web API + Accounts token exchange over HTTPS)
- For **live** (non-test) calls, wave-3 orchestrator needs to add `:inets` and `:ssl`
  to `extra_applications` in `host/mix.exs` â€” same requirement weather already has.
  Mocked tests do not need this.

## Next Session Context Chunk

- N2 screen: `NowPlayingScreen` + pure `buildNowPlayingViewModel` (progress, volume segments,
  display-only queue). Gruvbox TUI chrome; PBM art via photo `pbm` decode.
- N3 overlay: `LyricsOverlay` + `lyricsModel` (already on master, PR #36). Shared fixture
  carries timed lyrics + N2 queue/art; `nowPlayingFixtureNoLyrics` for empty overlay.
- Shell: wheel â†’ `adjust-volume`; press â†’ `lyrics` overlay â€” **do not edit shell**.
- Wave-3: wire `now-playing` â†’ `NowPlayingScreen` and `renderOverlay("lyrics")` â†’ `LyricsOverlay`.
- Host: `cd host && mix test test/paper_weight/spotify/` (N1, 31 tests); lyrics still null from host.
