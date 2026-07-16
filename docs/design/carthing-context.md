# CarThing custom app — design context / handoff

> Imported 2026-07-15 from claude.ai/design project **"CarThing custom app UI designs"**
> (`b8c05a93-b6c5-4a77-ad4b-6c106e533c3f`). Screen mockup PNGs are in `spec/` at the repo root
> (except `photo-4g.png` — over the API size cap, download manually from the design project).
> The full canvas (`CarThing Explorations.dc.html`) was NOT imported — view it at:
> https://claude.ai/design/p/b8c05a93-b6c5-4a77-ad4b-6c106e533c3f?file=CarThing+Explorations.dc.html

Context file for building the real app in another project. This is a **design spec**, not
production code. It describes the locked UI direction, the six screens, the hardware model,
and the exact visual tokens used in the mockups (`CarThing Explorations.dc.html`).

---

## Device & platform

- **Spotify Car Thing**, reflashed with a custom app. 3.97" LCD, **800 × 480**, touch-capable
  but driven primarily by hardware.
- **Hardware inputs** (the app must be fully usable without touch):
  - **Wheel / rotary encoder** — turn to scroll or move selection; the encoder is exposed as a
    Linux `evdev` device.
  - **Wheel press** — select / enter / confirm (context-dependent per screen).
  - **4 preset buttons (1–4)** — hard-switch top-level screens.
  - **Button-hold** — return to home.
  - **Back button** — up one level / dismiss overlay.
- App is **read-only / glanceable** for most surfaces (feed, weather, etymology are snapshots,
  not live-interactive services). Music is the one truly interactive surface.

### Global feature flags / decisions
- **play/pause is HIDDEN** (flagged off). No transport controls on screen; the wheel press on
  Now Playing toggles **lyrics**, not play state.
- **Lyrics** = a press-to-toggle **overlay** over Now Playing (not a separate top-level screen).
- **Settings** = hidden screen, opened via **konami code**; not in the 1–4 preset rotation.
- **Home** = reachable by **button-hold** from any screen.

---

## House style — "BERG / Little Printer" (LOCKED)

The chosen aesthetic is the BERG Little Printer language: warm, characterful, a little device
that "speaks" to you. Two layers:

1. **Chrome / desk** — dark, near-black background (the "desk" the paper sits on).
2. **Content** — sits on **thermal-cream paper cards** with a **hard black outline + hard
   offset drop-shadow** (no soft blur), 1-bit / dithered imagery, serif display headers mixed
   with mono UI labels, and friendly lowercase copy.

### Color tokens
| Role | Hex |
|---|---|
| Desk / background (BERG) | `#20201d` / `#17130f` (darker) |
| Thermal-cream paper | `#f2e9d4` / `#f4ecd8` |
| Ink (near-black, outlines & text on cream) | `#17130f` / `#26211a` |
| Muted ink (labels on cream) | `#6b6151` / `#8a7f66` |
| Mustard / action bar | `#f7b301` |
| Red accent (alerts, "live" dot, extreme UV) | `#e2402c` / `#fb4934` / `#b0421a` |
| Pink accent (feed handle / rail) | `#d3869b` |
| Teal accent (feed handle) | `#83a598` |
| Gold/amber (high UV, secondary) | `#fabd2f` |

The TUI/gruvbox palette from Round 3 (`#282828`/`#1d2021` desk, `#ebdbb2` text, gruvbox accents)
is the **fallback** if BERG proves too heavy at this scale — some screens (4a np, 4b wx, 4c pl)
are still rendered in that TUI chrome and can be reskinned to full BERG.

### Type
- **Display / headers**: `DM Serif Display` (serif) — song titles, mastheads, the device's
  "voice" quotes (italic).
- **UI labels / metadata / handles**: `JetBrains Mono` (mono).
- **Body**: `Space Grotesk` (BERG screens).
- Min sizes at this resolution: **never below ~13px**; body copy 18–25px; hero numbers 80px+.

### Signature card recipe
```
background:#f4ecd8; color:#26211a; border-radius:11px;
box-shadow:0 0 0 3px #17130f, 6px 7px 0 <accent>;   /* hard outline + hard offset */
```

---

## The six screens (FINAL PICKS — locked)

Reference the mockup IDs in `CarThing Explorations.dc.html`; matching PNGs in the design
project's `handoff/images/`.

| Screen | Pick | Image |
|---|---|---|
| Now Playing | **4a** | `images/now-playing-4a.png` |
| Weather | **4b** | `images/weather-4b.png` |
| Playlist | **4c** | `images/playlist-4c.png` |
| Feed (Twitter/X) | **4f** | `images/feed-4f.png` |
| Photo frame | **4g** | `images/photo-4g.png` |
| Etymology | **2a → 2b → 2c** (one drill-down flow, 3 depths) | `images/etymology-2a-depth0.png`, `-2b-depth1.png`, `-2c-depth2.png` |

1. **Now Playing** → **4a** (TUI chrome, art+metadata fused with queue). Art shown as **1-bit
   dithered** square. Right/lower area = **up-next queue**, wheel scrolls it. Wheel **press →
   lyrics overlay**. No play/pause. Footer: "⟲ volume · press words".
2. **Weather** → **4b**. Layout: thin status topbar → **UV "WALK?" band** across the top
   (compact, ~1/4 height) → big current temp (left) + **real 5-day forecast** (right) → footer.
   - The device gives a **plain-spoken walk verdict** as an italic quote ("good window right now
     — but be home by 5…").
   - **UV bar is graded by strength**: solid fill = extreme, dithered **lines** = high, **faint
     tone** = low. Legend: ▮extreme ▤high ▮low.
   - Wheel turns today ↔ 7-day. Data source intent: NWS + OpenUV.
3. **Playlist** → **4c**. 2×3 (or 4-wide) **cover grid**, dithered/hatched tiles, fat labels,
   selected tile pops onto a paper card with ▶. Wheel walks the grid, press plays.
4. **Feed (Twitter/X)** → **4f**. **3d's renderer** (dark desk, per-handle accent colors,
   selected post on a cream paper card) pushed toward BERG: hard-outline+offset reading card,
   serif post bodies, mono handles, dashed paper dividers, mustard footer, receipt-roll progress
   rail on the right. **~3 posts visible**, big type, tuned for the tiny panel. Read-only
   snapshot. Wheel scrolls, press enlarges. (The "mini-newspaper / Grus Gazette" concept was
   **rejected** — do not build it.)
5. **Photo frame** → **4g**. Cream frame, true **1-bit Atkinson-dither** look over a real dropped
   photo, printed serif caption + "photo N/M · reprints in X min". Wheel skips, press keeps.
6. **Etymology** → **2a / 2b / 2c are ONE flow, not three options** — the three depths of a
   drill-down on the day's word:
   - **2a — depth 0**: root of the day + full trace ladder. Wheel scrolls the stages; press digs
     into the highlighted stage.
   - **2b — depth 1**: pressed a stage (e.g. `travailler`) — breadcrumb grows, focus narrows to
     that stage's own sub-trace. The word itself is emphasized.
   - **2c — depth 2**: the root — you hit bottom (e.g. the literal "three stakes" reveal), dead
     end marked. Back walks the breadcrumb up.
   Build all three as states of the same screen driven by wheel-scroll (move) + press (dig in) +
   back (up one level).

### Also needed, not yet designed in BERG
- **Home** screen (button-hold target).
- **Settings** screen (konami-opened).
- **Lyrics overlay** styling (confirmed as overlay over 4a/4d).

---

## Interaction map (per screen)

| Screen | Wheel turn | Wheel press | 1–4 | hold | back |
|---|---|---|---|---|---|
| Now Playing | volume | toggle lyrics overlay | switch screen | home | — |
| Weather | today ↔ 7-day | — | switch screen | home | — |
| Playlist | move selection in grid | play selected | switch screen | home | — |
| Feed | scroll posts | enlarge post | switch screen | home | collapse post |
| Photo | skip photo | keep on show | switch screen | home | — |
| Settings (konami) | move field | edit/confirm | — | home | exit |

---

## Still to design (not yet mocked — flag as tickets)
1. **Home** screen (button-hold target).
2. **Settings** screen (konami-opened).
3. **Lyrics overlay** styling (confirmed as an overlay over 4a).
4. Whether to reskin the TUI-chrome screens (4a/4b/4c) into full BERG, or keep the current
   two-layer mix (dark chrome + cream cards). 4a/4b/4c ship in gruvbox TUI chrome today; 4f/4g
   are full BERG.

## Data / integration notes for tickets
- **Spotify**: Now Playing metadata + queue + volume (wheel). No transport UI (play/pause off).
- **Weather**: current + 5-day + hourly UV. Intent: NWS forecast + OpenUV index.
- **Feed**: read-only Twitter/X snapshot, refreshed periodically, ~3 posts on screen.
- **Etymology**: day's word + nested origin trace (Wiktionary-style data).
- **Photo**: local photo source, dithered to 1-bit on device.

---

## Files in the design project (NOT imported — fetch on demand only)
- `CarThing Explorations.dc.html` — the canvas with every explored option (IDs like 4a, 4b, 3d…).
- `image-slot.js` — drag-and-drop photo slot component used by the photo frame (4g).
- `handoff/images/*.png` — final-pick screen renders (8 files).
