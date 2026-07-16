# Feature: playlist

Lane owner for **L1** (screen 4c grid).  
Protocol envelope: `docs/architecture/host-device-protocol-v1.md`.  
Mockup: `spec/playlist-4c.png`.

## Cards

| ID | Issue | Title | Status |
|----|-------|-------|--------|
| L1 | [#11](https://github.com/rorybot/paper-weight/issues/11) | Playlist grid screen 4c | **In progress** |

## Ownership (only these paths)

| Area | Path |
|------|------|
| Device screen | `src/device-ui/src/screens/playlist/**` |
| Payload types | `src/device-ui/src/protocol/playlist.ts` |
| Feature spec | `features/playlist/spec.md` |
| Fixtures | under own test dirs |

**Do not touch:** `application.ex`, shell, design tokens, other lanes, envelope.

## Payload contract (L1 freezes UI shape)

```ts
type PlaylistItemV1 = {
  id: string;
  name: string;
  cover_pbm_base64: string | null; // P5 PBM; null → CSS hatch
};

type PlaylistSnapshotV1 = {
  as_of: string;
  stale: boolean;
  playlists: PlaylistItemV1[];
};
```

Host channel for playlist list is **not** frozen yet — L1 is fixture-driven UI.
Device → host play intent (envelope, frozen):

```ts
{ name: "play_playlist", args: { id: string } }
```

## Interaction (shell already emits)

| Input | Shell command | Screen effect |
|-------|---------------|---------------|
| Wheel | `move-playlist-selection` `{ delta }` | Walk selection in grid (clamp) |
| Press | `play-selected-playlist` | `onPlaySelected(item)` → intent `play_playlist` + request NP |

Wave-3 `ShellApp` wires command → screen + navigates to Now Playing after play.

## Screen layout (match `playlist-4c.png`)

- Gruvbox TUI chrome @ 800×480 (not full BERG — D3 open).
- Topbar: `[cthing]` · presets with **2:pl\*** active · `playlists · N`.
- Grid: **2×3** window (cols=3, rows=2); hatched cover tiles; fat labels under tiles.
- Selected: gold outline + ▶ overlay + accent label.
- Overflow: last visible tile may show `+K` when more playlists exist beyond window.
- Footer: `◉ wheel walk grid` · `press play` · `i / N` (1-based).

## Acceptance (L1)

- [x] Pure `reducePlaylistUi` for wheel selection.
- [x] Fixture renders mockup names + 2×3 grid + selection chrome.
- [x] Press invokes play callback with selected id (intent shape).
- [ ] Wave-3: host plays + shell navigates to Now Playing (out of L1 scope).

## Next Session Context Chunk

- L1 builds `screens/playlist/**` + `protocol/playlist.ts` on `lane/playlist-l1`.
- Shell already emits `move-playlist-selection` / `play-selected-playlist` — do not edit shell.
- Play = callback + `play_playlist` args only; NP switch is wave-3 navigation.
- CSS hatch covers when `cover_pbm_base64` is null; optional PBM path reuses photo `pbm` decode if needed later.
