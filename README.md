# paper-weight — Car Thing custom app

Custom UI for a reflashed Spotify Car Thing (800×480, wheel/buttons via evdev).  
Aesthetic is locked BERG / Little Printer language — see `docs/design/carthing-context.md`.

| Resource | Link |
|----------|------|
| Design context | `docs/design/carthing-context.md` |
| Screen mockups | `spec/*.png` |
| Architecture (P1) | `docs/architecture/workflow-v1.md` |
| Workflow rules | `PROJECT_INSTRUCTIONS.md` |
| Kanban | [GitHub project](https://github.com/users/rorybot/projects/1) · mirror `kanban/board.md` |

---

## Stack (v1)

**Host companion** runs Elixir/OTP services (Spotify, weather, feed, photo, etymology, Atkinson dither).  
**Device** runs Chromium kiosk @ 800×480 + **Preact + TypeScript + Tailwind** pure `state → view` UI + a thin **evdev → event bus** bridge.

Host ↔ device: versioned WebSocket JSON. Device keeps a last-snapshot cache for host-down.

Full decision, deploy story, and module map: **`docs/architecture/workflow-v1.md`**.

### Why this shape

| Constraint | Implication |
|------------|-------------|
| ~512 MB RAM on Car Thing | Do **not** co-locate BEAM + Chromium on device |
| Mockups are web/CSS (BERG cards, fonts, dither) | Web UI is the cheapest path to locked visuals |
| Functional paradigm non-negotiable | Pure UI functions on device; Elixir/OTP on host for services |
| Glanceable product | Snapshots + cache; not a live-only thin client |

---

## UI stack tradeoffs (explicit)

React/Preact is **not** required by the hardware — it is a deliberate choice among Elixir-friendly options. Do not re-litigate without new hardware evidence; if you change this, update `workflow-v1.md` and this section together.

### Chosen: Preact SPA on device + Elixir on host

| Pros | Cons |
|------|------|
| Local `reduce(state, event)` — wheel ticks stay snappy even if LAN blips | Two languages (Elixir + TypeScript) |
| Offline / host-down: shell + last snapshot still render | Snapshot/WS protocol to design and version |
| Matches locked HTML/CSS mockups (Tailwind, fonts, hard-offset cards) | Slightly more client surface than pure LiveView |
| Chromium-only on device (no BEAM RAM fight) | Still depends on a browser on 512 MB (profile early) |

### Considered: Phoenix LiveView (web) — no React

Server-rendered HEEx in Chromium kiosk; almost no client framework.

| Pros | Cons |
|------|------|
| Single language (Elixir end-to-end) — often **faster to write** | Interactive UI needs the host; offline glance is weaker |
| No Preact/React dependency | Wheel/volume feel degrades if every tick is a LiveView round-trip on flaky LAN (must throttle/bridge carefully) |
| Same CSS design fidelity as Preact | Does **not** remove Chromium from the device |

**Not chosen for v1:** product wants resilient local input + last-snapshot behavior; desk use still benefits from a client that can idle without a live LV socket.

### Considered: LiveView Native

| Pros | Cons |
|------|------|
| “Native” UIs driven from Elixir | Targets **SwiftUI / Jetpack** — **not** Car Thing Linux |
| — | Core project **archived** (2026-02); wrong long-term bet |
| — | No superbird / framebuffer / Chromium client path |

**Rejected:** wrong platform for this device.

### Considered: full template stack on device (Phoenix + Remix/Chromium)

| Pros | Cons |
|------|------|
| Template default; OTP + web in one place | **Fails RAM budget** (~512 MB) with BEAM + browser co-located |
| — | Remix/SSR Node on device adds cost with no kiosk benefit |

**Rejected:** placement problem, not an Elixir philosophy problem. Elixir stays on the **host**.

### Considered: native framebuffer (Rust / Scenic / etc.)

| Pros | Cons |
|------|------|
| Best RAM/CPU envelope | Higher cost to hit BERG fidelity (type, hard shadows, layout) |
| No Chromium | Diverges from web-designed mockups |

**Deferred:** fallback if kiosk fails real-device memory/FPS budget after P3 shell.

---

## Hardware baseline

- Spotify Car Thing (superbird), reflashed Linux  
- Amlogic S905D2-class ARM, **~512 MB RAM**, 800×480 LCD  
- Primary input: wheel + press, presets 1–4, hold → home, back (evdev) — app must work **without touch**

---

## Repo layout

```
docs/architecture/   # stack decision, deploy story
docs/design/         # locked UI context
features/            # per-epic specs + session chunks
kanban/              # board mirror
spec/                # screen mockup PNGs
src/                 # application code (after platform cards land)
```

## Working rules (short)

- One kanban card per session; implement from card + its feature slice only.  
- Functional style: pure functions, composition, immutability.  
- No `src/` app code that fights `workflow-v1.md`.  
- **All changes via PR** — do not push commits straight to `master` (branch protection + CI).  
- Details: `PROJECT_INSTRUCTIONS.md`, `CLAUDE.md`, **`docs/architecture/ci-and-pr.md`**.
