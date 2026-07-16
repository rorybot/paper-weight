# Parallel lanes v1 — Weather · Feed · Spotify

**Goal:** run three agents at once without merge thrash.  
**Waves:** services first (W1 / F1 / N1), then screens (W2 / F2 / N2), then one wire-up pass.

---

## Waves

| Wave | Cards | Parallel? | Shared code? |
|------|-------|-----------|--------------|
| **0** | Protocol + this doc + feature specs | No (orchestrator) | Envelope frozen here |
| **1** | **W1** · **F1** · **N1** (host services) | **Yes — 3 agents** | No cross-edits |
| **2** | **W2** · **F2** · **N2** (device screens) | **Yes — 3 agents** | No cross-edits |
| **3** | Wire host gateway + `ShellApp` screen map | No (orchestrator) | Only integration files |

Do **not** start wave 2 for a domain until that domain’s wave-1 acceptance is green (or use frozen fixtures only for UI — see “UI-ahead”).

### UI-ahead option

A screen agent may start wave 2 **using fixture payloads only** (no live host), if they:

- Import payload types from `src/device-ui/src/protocol/<channel>.ts` only
- Do not invent alternate field names
- Mark card status honestly (UI with fixtures ≠ service Done)

---

## Lane roster

| Lane | Service card | Screen card | Host tree | Device tree | Mockup (screen only) |
|------|--------------|-------------|-----------|-------------|----------------------|
| **Weather** | W1 #9 | W2 #10 | `host/lib/paper_weight/weather/` | `src/device-ui/src/screens/weather/` | `spec/weather-4b.png` |
| **Feed** | F1 #12 | F2 #13 | `host/lib/paper_weight/feed/` | `src/device-ui/src/screens/feed/` | `spec/feed-4f.png` |
| **Spotify** | N1 #6 | N2 #7 | `host/lib/paper_weight/spotify/` | `src/device-ui/src/screens/now-playing/` | `spec/now-playing-4a.png` |

Also own:

| Lane | Feature spec | Host tests | Device tests | Protocol payload types |
|------|--------------|------------|--------------|------------------------|
| Weather | `features/weather/spec.md` | `host/test/paper_weight/weather/` | `…/screens/weather/*.test.*` | `…/protocol/weather.ts` |
| Feed | `features/feed/spec.md` | `host/test/paper_weight/feed/` | `…/screens/feed/*.test.*` | `…/protocol/feed.ts` |
| Spotify | `features/now-playing/spec.md` | `host/test/paper_weight/spotify/` | `…/screens/now-playing/*.test.*` | `…/protocol/now_playing.ts` |

---

## Hard ownership rules (mandatory)

### May edit (own lane only)

- Paths in the table above
- That lane’s `features/<name>/spec.md` (append Next Session chunks; don’t rewrite other lanes’ contracts)
- Own fixture files under own test dirs

### Must not edit

| Path | Why |
|------|-----|
| `host/lib/paper_weight/application.ex` | Wave 3 wires children |
| `host/lib/paper_weight/protocol/**` | Frozen envelope |
| `host/mix.exs` | Deps via **deps request note** (below) |
| `src/device-ui/src/shell/**` | P3 done — frozen |
| `src/device-ui/src/design/**` | P4 done — frozen |
| `src/device-ui/src/main.tsx` / `ShellApp.tsx` | Wave 3 wires screens |
| `src/device-ui/src/protocol/envelope.ts` | Frozen |
| Other lanes’ trees | No drive-bys |
| `kanban/board.md` for other cards | Only your issue status |

### Deps request (mix.exs / npm)

If you need a new dependency, **do not** edit `mix.exs` / root package files in a lane PR. Append to your feature `spec.md`:

```md
## Deps request
- mix: req ~> 0.5  (reason: HTTP client for NWS)
```

Orchestrator adds deps once and rebases lanes.

### Application children

Export a child spec from your service module:

```elixir
# e.g. PaperWeight.Weather.Service.child_spec/1 already via use GenServer
def child_spec(opts), do: %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}}
```

Document in spec:

```md
## Supervisor child (wave 3)
{PaperWeight.Weather.Service, []}
```

Orchestrator adds the line to `Application` in wave 3.

---

## Branch / worktree convention

| Lane | Branch | Worktree (suggested) |
|------|--------|----------------------|
| Weather | `lane/weather-w1` | `.worktrees/weather` |
| Feed | `lane/feed-f1` | `.worktrees/feed` |
| Spotify | `lane/spotify-n1` | `.worktrees/spotify` |

```text
git fetch
git worktree add .worktrees/weather -b lane/weather-w1 master
git worktree add .worktrees/feed    -b lane/feed-f1    master
git worktree add .worktrees/spotify -b lane/spotify-n1 master
```

Merge order (wave 1): **any order** if ownership held. Prefer merge **weather → feed → spotify** only when `mix.exs` deps collide after orchestrator dep PR.

Each agent: **one GitHub issue** status → In progress while working; Done only when acceptance met.

---

## Shared contracts (read-only for agents)

1. `docs/architecture/host-device-protocol-v1.md` — envelope
2. This file — ownership
3. `docs/architecture/workflow-v1.md` — stack
4. Own `features/<lane>/spec.md` + own kanban card
5. Design interaction map (shell already implements routing) — screens only handle **commands** shell emits

### Shell commands already reserved (do not rename)

| Screen | Wheel | Press | Lane handles command? |
|--------|-------|-------|------------------------|
| now-playing | `adjust-volume` | lyrics overlay (shell) | N1 volume intent; N2 UI |
| weather | `toggle-weather-range` | — | W2 local UI state; W1 data |
| feed | `scroll-feed` | feed-detail overlay | F2 local UI; F1 data |

---

## Acceptance per wave-1 service agent

| Check | Weather W1 | Feed F1 | Spotify N1 |
|-------|------------|---------|------------|
| Pure domain core + impure HTTP edge | ✓ | ✓ | ✓ |
| Fixture/mocked HTTP tests | ✓ | ✓ | ✓ |
| Builds snapshot matching protocol payload types | ✓ | ✓ | ✓ |
| Stale/error path documented + tested | ✓ | ✓ | ✓ |
| Does **not** open WS server / edit Application | ✓ | ✓ | ✓ |
| `mix test` green for own tests | ✓ | ✓ | ✓ |

---

## Acceptance per wave-2 screen agent

| Check | W2 | F2 | N2 |
|-------|----|----|-----|
| Pure `view(state)` / local reduce for wheel UI state | ✓ | ✓ | ✓ |
| Uses protocol payload type (fixture OK) | ✓ | ✓ | ✓ |
| Matches mockup PNG for card | weather-4b | feed-4f | now-playing-4a |
| Uses P4 `Card` / tokens only (no new design system) | ✓ | ✓ | ✓ |
| No edits to shell router | ✓ | ✓ | ✓ |
| `npm run check` green | ✓ | ✓ | ✓ |

---

## Orchestrator wave-3 checklist

- [ ] Merge three service branches; add deps from Deps requests
- [ ] Register three children in `Application`
- [ ] Minimal host gateway: WS push of envelopes (can be stub publisher first)
- [ ] Wire `ShellApp` / screen registry: preset 1–4 → real screens
- [ ] Device store: `channel` → screen props
- [ ] End-to-end smoke: fixture host → UI on desktop 800×480

---

## Copy-paste agent prompts

See `features/_lanes/agent-prompts.md`.

---

## Status mapping

| Lane wave-1 issue | Promote to |
|-------------------|------------|
| W1 #9 | Ready (then In progress when agent starts) |
| F1 #12 | Ready |
| N1 #6 | Ready |

Never mark two cards In progress for the **same** agent session. Three agents ⇒ three In progress OK.
