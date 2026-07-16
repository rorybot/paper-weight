# Workflow v1 — runtime & stack decision (P1)

**Status:** decided  
**Card:** P1 [platform] Architecture spike  
**Date:** 2026-07-15  
**Hardware baseline:** Spotify Car Thing (superbird) — Amlogic S905D2-class ARM, **~512 MB RAM**, 4 GB eMMC-class storage, 800×480 LCD, Linux after reflash, wheel/buttons via **evdev**.

---

## Goal

Pick the on-device (and companion) stack **before any `src/` application code**.  
Template default was Elixir backend + Remix/React + TypeScript + Tailwind frontend. That default is **not** viable as a full dual-process stack **on the device**.

---

## Options evaluated

| # | Option | On-device footprint | Design fidelity (BERG) | Functional fit | Notes |
|---|--------|--------------------|------------------------|----------------|-------|
| A | **Template dual-stack on device** — BEAM (Phoenix) + Chromium + Remix | **Fail** — BEAM + Chromium often exceeds ~512 MB under load | High (web CSS) | Excellent (Elixir) | Rejected for on-device co-location |
| B | **Chromium kiosk only on device** — static/SPA UI, local or remote APIs | **OK** if browser is the heavy process | High | UI = pure `state→view` TS; services elsewhere | Proven community pattern (debian-kiosk / DeskThing-class) |
| C | **Native framebuffer** — Rust/C++/Scenic/Qt drawing pixels | **Best** RAM/CPU | Medium — fonts, hard-offset cards, complex layout cost more eng | Strong (Rust/Elixir Scenic) | Slow path to locked mockups |
| D | **Host-serves / device-renders** — host runs services; device thin UI | **Best for device** | High if UI is web | Host Elixir + pure UI fns | Matches glanceable/snapshot product model |

### Hardware constraints that force the decision

| Constraint | Implication |
|------------|-------------|
| ~512 MB RAM | Cannot co-locate Chromium **and** a comfortable OTP node for API work |
| 800×480, BERG tokens, web-designed mockups | Web/CSS is the cheapest path to locked visual recipe |
| evdev-only primary input | Need a thin input bridge into the UI process (not touch-first) |
| Glanceable snapshots (feed, weather, etymology, photos) | Periodic fetch + cache fits a **host companion**; device can show last good frame |
| Functional paradigm non-negotiable | Prefer pure modules + composition everywhere; keep Elixir where OTP shines |

---

## Decision (locked for v1)

### Architecture: **D + B hybrid**

```
┌──────────────────────────── HOST (always-on PC / Pi / NAS) ───────────────────────────┐
│  Elixir (OTP) — Phoenix (optional HTTP) + supervised services                         │
│    N1 Spotify · W1 NWS/OpenUV · F1 X snapshot · E1 etymology · H1 photos · P5 dither  │
│    Token refresh, caches, golden-image pipeline, WS/SSE fanout                        │
└───────────────────────────────────────┬───────────────────────────────────────────────┘
                                        │ LAN / USB tether (JSON over WebSocket preferred)
┌───────────────────────────────────────▼───────────────────────────────────────────────┐
│  DEVICE (Car Thing Linux)                                                             │
│    1. Chromium (or equivalent) **kiosk** @ 800×480                                    │
│    2. UI app: TypeScript, pure `state → view`, Tailwind tokens (BERG + gruvbox fallback)│
│       Prefer **Preact** (or solid-js) over full Remix SSR — no Node server on device   │
│    3. Input bridge: small process (e.g. Rust/Go/Python) reads evdev → WS/stdin → UI    │
│    4. Local last-snapshot cache (disk) for offline / host-down                        │
└───────────────────────────────────────────────────────────────────────────────────────┘
```

### What we chose and why

| Layer | Choice | Rationale |
|-------|--------|-----------|
| **Device UI runtime** | Chromium kiosk + pure-function TS UI | Matches mockups (fonts, hard outline+offset cards, dither canvases); community-proven on superbird |
| **Device UI framework** | **Preact + TypeScript + Tailwind** (not Remix SSR) | Remix expects a Node server; on-device Node+Chromium is wasteful. SPA/static build is enough |
| **Device input** | Thin **evdev → event bus** daemon (P2) | Keeps input pure/testable; UI never talks to `/dev/input` directly |
| **Host services** | **Elixir / OTP** | Template default retained where it fits: concurrent API clients, supervision, pure cores + impure edges |
| **Host↔device protocol** | WebSocket JSON (versioned messages) | Push snapshots + accept volume/play intents; simple to mock in tests |
| **Image dither (P5)** | **Host-side precompute + cache**; device displays bitmaps | Keeps CPU/RAM off the 512 MB device; golden tests run on host CI |
| **Offline** | Device holds last N snapshots | Product is glanceable, not live-trading |

### Explicit rejections

| Rejected | Why |
|----------|-----|
| Phoenix + Chromium **both on device** | RAM budget; thrashing risk |
| Remix (or any SSR Node) **on device** | Extra runtime with no benefit for a fixed kiosk |
| **Phoenix LiveView (web) as device UI** | Faster single-language path, but weaker offline/last-snapshot story and wheel ticks risk LAN round-trips; v1 prefers local Preact `reduce` + host services. Tradeoffs: `README.md` |
| **LiveView Native** | SwiftUI/Jetpack only — not Car Thing Linux; upstream archived (2026-02) |
| Full native framebuffer as v1 default | Higher cost to hit BERG fidelity; revisit only if kiosk fails RAM/FPS budget on real hardware |
| Elixir Scenic as primary UI | Functional-friendly but weak match for locked web mockups without major design rework |
| "No host" pure-online device APIs | Possible later; v1 assumes a companion host so Spotify/X tokens and heavy work stay off-device |

> Expanded pros/cons for Preact vs LiveView vs LVN vs on-device dual-stack: **`README.md`** (UI stack tradeoffs).

### Elixir deviation (justified)

- **Constraint:** functional paradigm non-negotiable; deviation from Elixir must be justified.
- **Justification:** Elixir remains the **service/runtime of record on the host**. It is **not** the on-device UI VM because BEAM+Chromium exceeds the Car Thing RAM envelope. On-device code is pure-function TypeScript (same functional rules: immutability, small modules, DIP via injected ports). That is a **placement** decision, not abandonment of the template stack.

---

## Module map (feeds P2–P5 and screen epics)

| Module | Runs on | Responsibility | Downstream cards |
|--------|---------|----------------|------------------|
| `input_bridge` | device | evdev → typed events | P2 |
| `screen_shell` | device UI | router, overlays, back stack, konami | P3 |
| `design_tokens` + `card` | device UI | BERG tokens, card recipe, gruvbox fallback | P4 |
| `dither` | **host** (+ optional pure port for tests) | image → 1-bit Atkinson @ slot size | P5 |
| `*_service` | host Elixir | Spotify, weather, feed, photo, etymology | N1, W1, F1, H1, E1 |
| `*_screen` | device UI | pure `state → view` per locked mockup | N2, W2, L1, F2, H2, E2 |
| `host_gateway` | host | WS protocol, auth to local LAN only | all data screens |
| `snapshot_store` | device | last-good frames for host-down | all data screens |

### Functional rules (all languages)

- Screens: **pure** `reduce(state, event) → state` and `view(state) → tree`.
- I/O only at edges: input bridge, WS client, Elixir ports/HTTP clients.
- No play/pause UI (global flag); volume and lyrics overlay per design spec.

---

## Deploy story

### Target environments

| Env | Role |
|-----|------|
| **Dev host** | Elixir services + Vite/Preact UI served to desktop browser at 800×480 for UI work |
| **Device** | Reflashed Car Thing Linux — **decided 2026-07-15: [nixos-superbird](https://github.com/JoeyEamigh/nixos-superbird)** (build via [template](https://github.com/JoeyEamigh/nixos-superbird-template) Docker builder; SSH `root@172.16.42.2` over USB gadget net) |
| **Companion host** | Same Elixir release as dev, running on LAN machine or USB-tethered Pi |

### Device image (v1 assumptions)

1. Linux aarch64 with working **framebuffer / X11 or Wayland** path to 800×480.
2. **Chromium** (or Chromium-based) launchable in kiosk: fixed window, no browser chrome.
3. **evdev** nodes readable by the input bridge user.
4. Local writable path for snapshot cache + static UI assets (`/opt/paper-weight/` or similar).
5. Network: Wi‑Fi **or** USB tether to companion host (deployment docs pick one primary; both supported).

### Build artifacts

| Artifact | Build where | Install where |
|----------|-------------|----------------|
| `ui/` static bundle (Preact+TS+Tailwind) | CI / dev machine | device `/opt/paper-weight/ui` |
| `input_bridge` binary | CI (aarch64) | device systemd unit |
| `kiosk.service` | repo unit file | device — starts Chromium → `file://` or `http://127.0.0.1:…` |
| `paper_weight` Elixir release | CI (host arch) | companion host |
| Optional local static file server | tiny (caddy/nginx or Chromium `file://`) | device |

### Runtime sequence (cold boot)

1. Device boots Linux → `input_bridge.service` → `kiosk.service`.
2. UI loads last snapshot from disk; shows stale/empty states per screen rules.
3. UI opens WebSocket to configured host (`ws://<host>:…/v1`).
4. Host pushes current snapshots (NP, weather, feed, …) on connect + interval.
5. Input events stay local (low latency); only intents that need host APIs (volume via Spotify, play playlist, etc.) cross the wire.

### Dev loop (no device required for most cards)

1. `mix phx.server` / Elixir services with fixtures.
2. `pnpm dev` UI at `localhost` with `?w=800&h=480` shell.
3. Fake input: keyboard map (wheel = arrows, press = Enter, presets = 1–4, hold = H, back = Escape).
4. Device smoke only when touching input_bridge, kiosk flags, or perf.

### Config (device)

```
HOST_WS_URL=ws://192.168.x.x:4000/v1
HOLD_MS=600
UI_PATH=/opt/paper-weight/ui/index.html
```

---

## Risk register

| Risk | Mitigation |
|------|------------|
| Chromium still too heavy alone on 512 MB | Profile on real hardware early (after P3 shell); fallback plan = native framebuffer or WPE WebKit |
| GPU/Mali X11 pain | Prefer known-good superbird image; software render OK at 800×480 |
| Host dependency | Snapshot cache; clear "host offline" chrome; desk use assumes host present |
| Remix muscle-memory | Document Preact pure-view pattern in feature specs; no Remix APIs |
| Protocol drift | Version field on every WS message; fixture contract tests on host |

---

## Acceptance (P1)

| Criterion | Met? |
|-----------|------|
| Decision written | **Yes** — D+B hybrid above |
| Rationale vs template + hardware | **Yes** — options table + Elixir placement justification |
| Deploy story | **Yes** — artifacts, boot sequence, dev loop |
| Blocks `src/` app code until this exists | **Lifted** for platform work **following this doc** |

---

## Implications for next cards

| Card | Notes from P1 |
|------|----------------|
| **P0** Device smoke | **Hardware go/no-go** for Chromium kiosk + preset 1–4 → `spec/*.png` frames (`device-smoke/`); write `device-smoke.md`; amend this doc if kiosk/input fails |
| **P2** Input daemon | On-device only; typed events; fake-evdev tests on host arch OK |
| **P3** Screen shell | Device UI module; pure router; fake keyboard input in dev |
| **P4** Design tokens | Tailwind/CSS tokens in UI package; gruvbox theme switch |
| **P5** Atkinson dither | **Host Elixir** (or pure NIFs/port) + golden images; UI only displays results |
| Screen services (N1…) | **Host Elixir** |
| Screen UIs (N2…) | Device Preact pure views |

---

## Next Session Context Chunk

- P1 **done**: stack = host Elixir services + device Chromium kiosk + Preact/TS pure UI + evdev bridge; P5 dither on host.
- Do **not** put Phoenix+Chromium together on device; do **not** use Remix on device.
- Next card **P2**: input daemon contract + fake-evdev tests; event types for wheel/buttons/hold/back.
- Dev loop: 800×480 browser + keyboard map until real device smoke.
- Update board: move P1 → Done; P2 → Ready/In progress when started.
