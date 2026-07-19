# Feature: now-playing

Lane owner for **N1** (Spotify service) + **N2** (screen 4a) + later **N3** (lyrics).  
Parallel rules: `docs/architecture/parallel-lanes-v1.md`.  
Protocol envelope: `docs/architecture/host-device-protocol-v1.md`.

## Cards

| ID | Issue | Title | Status |
|----|-------|-------|--------|
| N1 | [#6](https://github.com/rorybot/paper-weight/issues/6) | Spotify data service | **Done** |
| N2 | [#7](https://github.com/rorybot/paper-weight/issues/7) | Screen 4a UI | **Done** (PR #39) |
| N3 | [#8](https://github.com/rorybot/paper-weight/issues/8) | Lyrics overlay | **Done** (PR #36) |
| N4 | [#89](https://github.com/rorybot/paper-weight/issues/89) | Live Spotify acceptance | **Done** (PR #96) |

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

## Lyrics overlay (N3) — design snippet (approved direction)

Not on the design canvas; card + design-spec interaction map are authoritative:

| Element | Spec |
|---------|------|
| Layer | Shell `overlay: "lyrics"` over 4a (not a top-level screen) |
| Backdrop | Existing shell dim (`[data-shell-layer="overlay"]`) |
| Card | BERG **paper** card, hard outline + accent offset shadow |
| Content | Timed lines from `snapshot.lyrics`; active = last `t_ms ≤ progress_ms` |
| Empty | `lyrics: null` or empty lines → “no lyrics for this track” |
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
- [ ] Wave-3: `ShellApp.renderOverlay("lyrics")` → `LyricsOverlay`

## Deps request

- mix: none added — client/auth use Erlang `:httpc` (like the weather lane), injected
  as an HTTP fn so tests never hit the network.
  (reason: Spotify Web API + Accounts token exchange over HTTPS)
- For **live** (non-test) calls, wave-3 orchestrator needs to add `:inets` and `:ssl`
  to `extra_applications` in `host/mix.exs` — same requirement weather already has.
  Mocked tests do not need this.

## Next Session Context Chunk

- N2 screen: `NowPlayingScreen` + pure `buildNowPlayingViewModel` (progress, volume segments,
  display-only queue). Gruvbox TUI chrome; PBM art via photo `pbm` decode.
- N3 overlay: `LyricsOverlay` + `lyricsModel` (already on master, PR #36). Shared fixture
  carries timed lyrics + N2 queue/art; `nowPlayingFixtureNoLyrics` for empty overlay.
- Shell: wheel → `adjust-volume`; press → `lyrics` overlay — **do not edit shell**.
- Wave-3: wire `now-playing` → `NowPlayingScreen` and `renderOverlay("lyrics")` → `LyricsOverlay`.
- Host: `cd host && mix test test/paper_weight/spotify/` (N1, 31 tests); lyrics still null from host.

## Wave-3 card table

| Card | Status | Dependencies | Scope |
|------|--------|--------------|-------|
| W3-G #49 | **Done** (PR #75) | W3-E #48, W3-P1 #43 | Fetch Spotify playlists into the frozen `PlaylistSnapshotV1` shape, expose generation, and replace the gateway playlist stub. |
| W3-F #50 | **Done** (PR #77) | W3-D, W3-E, W3-G | End-to-end smoke after live playlist channel lands. |

## Next Session Context Chunk

- W3-G: `Spotify.Client.playlists/3` → `Fetch.fetch_playlists/4` → pure `PlaylistSnapshot` (atom keys).
- `Service.playlists/1` + `get_playlist_gen/1` (+ `refresh_playlists/1`); gen advances only on successful poll.
- Gateway: `Publisher` takes `:playlist` input; `Socket` collects from the Spotify adapter; `PlaylistStub` removed.
- Covers always `cover_pbm_base64: nil` (no JPEG/PNG→grayscale path yet); device CSS hatch. No play/pause.
- W3-F #50 Done (PR #77): stubs host + `dev:live` + wave-3-smoke.md.

## N4 Next Session Context Chunk

- Added `host/test/paper_weight/spotify/fetch_test.exs` (new): covers `Fetch.refresh_if_needed`
  cached-token reuse, no-token/expired/near-buffer refresh, and `fetch_snapshot`/`fetch_playlists`
  propagating both refresh failure and downstream API failure without a spurious client call.
- Expanded `client_test.exs`: malformed/partial JSON on now-playing/queue/playlists, plus non-200
  status on each read endpoint and on `set_volume`.
- Expanded `service_test.exs`: stale→fresh recovery asserting `gen`/`playlist_gen` advance again
  after a later successful poll (previously only failure-path stale-marking was covered).
- `host/lib/paper_weight/spotify/**` untouched — this was gap-filling test coverage only, no
  behavior change. `cd host && mix test test/paper_weight/spotify/` → 56 passed.
- Branch `lane/spotify-n4-live-acceptance`, worktree `.worktrees/n4-spotify-live`, draft PR opened.
  Resume after P7 lands: rebase, wire the EnvironmentFile contract, get out-of-band credentials, then
  do physical Now Playing/playlist/volume/failure/reconnect acceptance and close out #89.

## Next Session Context Chunk — N4 (2026-07-18)

- N4 #89 is Backlog until P7 #85 supplies the shared EnvironmentFile activation contract.
- Own only Spotify paths; keep frozen `now_playing`/`playlist` envelopes and the no-play/pause rule.
- Accept mocked token/failure recovery plus live metadata, playlists, and volume on the device.

## Next Session Context Chunk — N4 (2026-07-19)

- PR #96 rebased onto current `origin/master`; Spotify tests pass 56/56 and diff-check is clean.
- P7 #85 remains open with Project Status Ready, so no live activation or physical acceptance ran.
- N4 #89 remains open and In progress; board mirror and this card table now match GitHub.
- Resume only after P7 is Done: wire its runtime contract, use out-of-band credentials, validate device/reconnect, then close out.

## Next Session Context Chunk — N4 (2026-07-19, P7 unblocked)

- Rebased onto master with P7 #85/PR #106; shared live-runtime wiring is inherited unchanged.
- Spotify tests pass 56/56 and the full host suite passes 191/191; Car Thing `172.16.42.2` is reachable.
- No ignored `.env` or exported Spotify credentials are present; the host user manager still loads the old P6-I unit.
- Resume with out-of-band credentials and a host-native P7 unit install, then run physical live/failure/reconnect acceptance.

## Next Session Context Chunk — N4 (2026-07-19, closed)

- Physical acceptance passed: live metadata + 50 real playlists on device; scripted ethernet-outage
  drill confirmed stale=true frozen snapshot then gen 1670→1688 fresh recovery (`.n4-drill.log`).
- Waived/deferred: playlist *selection* (no shell-router path reaches PlaylistScreen — presets 1–4
  only; needs a future shell card) and wheel volume (kiosk runs `bridge=0`; P8 owns input).
- Known quirks: stale flag only reaches *new* WS connections (gen doesn't advance on failure);
  `art_pbm_base64` stays nil; USB replug drops host `172.16.42.1` (re-add + kiosk restart —
  see `.n4-failure-drill.py` preflight).
