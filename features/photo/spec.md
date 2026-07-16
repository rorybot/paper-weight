# Feature: photo

Lane owner for **H1** (service) + **H2** (screen 4g).  
Protocol envelope: `docs/architecture/host-device-protocol-v1.md`.

## Cards

| ID | Issue | Title | Status |
|----|-------|-------|--------|
| H1 | [#14](https://github.com/rorybot/paper-weight/issues/14) | Photo source + rotation service | **Done** |
| H2 | [#15](https://github.com/rorybot/paper-weight/issues/15) | Screen 4g UI | Backlog |

## Ownership (only these paths)

| Area | Path |
|------|------|
| Host service | `host/lib/paper_weight/photo/**` (+ `photo.ex`) |
| Host tests | `host/test/paper_weight/photo/**` |
| Device screen | `src/device-ui/src/screens/photo/**` |
| Payload types | `src/device-ui/src/protocol/photo.ts` |
| Fixtures | under own test dirs |

**Do not touch:** `application.ex`, `mix.exs`, shell, design tokens, other lanes.  
**Dither:** call existing `PaperWeight.Dither` (P5) — do not modify dither modules; optional thin wrapper under `photo/` for H2. H1 ships `art_pbm_base64: null` unless a test injects grayscale.

## Channel

`channel: "photo"`

## Payload contract (H1 freezes this)

```ts
/** Host → device payload for channel "photo" */
type PhotoSnapshotV1 = {
  as_of: string;                 // ISO-8601
  stale: boolean;
  source: string;                // library label / path
  empty: boolean;
  /** 1-based N in "photo N/M"; 0 when empty */
  index: number;
  /** M in "photo N/M" */
  total: number;
  caption: string;
  /** stable id (basename without ext); null when empty */
  id: string | null;
  /** host path for dither pipeline; null when empty */
  path: string | null;
  /** pin: auto-rotation does not advance while true */
  kept: boolean;
  /** ceil remaining minutes until auto-reprint; 0 when due */
  reprints_in_min: number;
  reprint_interval_min: number;
  /** pre-dithered slot; null until H2/host art path produces it */
  art_pbm_base64: string | null;
};
```

Display chrome (H2): `photo N/M · reprints in X min`.

## Interaction rules (H1 pure + service)

| Input | Effect |
|-------|--------|
| **skip** (wheel) | Advance to next photo (wrap); clear `kept`; reset reprint timer |
| **keep** (press) | Toggle `kept` on current photo |
| **timer tick** | If not `kept` and deadline passed → same as skip (advance + reset) |
| **keep + timer** | While `kept`, timer may still count down but **does not** change photo |

### Ordering

- Library = scan `library_dir` for image extensions (default: `.jpg` `.jpeg` `.png` `.webp` `.gif` `.bmp` `.pbm` `.pgm`).
- Sort by basename (case-insensitive), stable.
- Caption: optional sidecar `<basename>.txt` next to the image; else humanized basename.

### Ingest

- Drop files into `library_dir` (or subdirs **not** walked in v1 — flat dir only).
- `rescan` reloads the ordered list; if current `id` still exists, keep index on that id; else clamp to 0.

## Host API (H1)

| Function | Role |
|----------|------|
| `Library.scan(dir) → [entry]` | impure edge (filesystem) |
| `Rotate.skip/keep/tick(state, now_ms)` | pure rotation |
| `Snapshot.assemble(parts)` | pure payload map |
| `Service.get_snapshot` / `skip` / `keep` / `rescan` | OTP |

### Supervisor child (later wave — do not register yourself)

```elixir
{PaperWeight.Photo.Service, []}
```

## Screen (H2) — local only

- Mockup: `spec/photo-4g.png` (**pending** manual download — DesignSync truncates).
- Cream frame + real Atkinson dither of user photo + serif caption + N/M · reprints line.
- Wheel = skip; press = keep on show.

## Acceptance

### H1
- [x] Fixture library scan orders + captions
- [x] N/M and `reprints_in_min` correct after skip / keep / tick
- [x] Keep blocks auto-advance; skip clears keep and resets timer
- [x] Snapshot matches `PhotoSnapshotV1`
- [x] No Application / mix.exs edits

### H2
- [ ] Matches `photo-4g.png` with a real user photo

## Next Session Context Chunk

- **H1 Done** (local): `host/lib/paper_weight/photo/**` + `photo.ex` — Library scan, pure `Rotate` (skip/keep/tick), Snapshot, GenServer Service; 20 tests green via WSL `mix test test/paper_weight/photo/`.
- Payload frozen in this file + `src/device-ui/src/protocol/photo.ts`. `art_pbm_base64` always null in H1.
- Do **not** register Service in `application.ex` (wave 3). Default interval 5 min; flat `library_dir` only.
- **H2 next**: needs `spec/photo-4g.png` (manual download); cream frame + dither path + footer `photo N/M · reprints in X min`.
