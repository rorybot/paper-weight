# PROJECT_INSTRUCTIONS.md — CarThing custom app (living doc)

Operating framework: **Token-Optimized Multi-Agent Functional Development Framework v0.4**
(full template: `docs/CLAUDE_PROJECT_TEMPLATE.md`). Treat the principles below as immutable.

## Project links
- **Design spec (source of truth for UI)**: `docs/design/carthing-context.md`
- **Design canvas + screen PNGs**: https://claude.ai/design/p/b8c05a93-b6c5-4a77-ad4b-6c106e533c3f?file=CarThing+Explorations.dc.html
- **Kanban**: https://github.com/users/rorybot/projects/1 (mirror: `kanban/board.md`)
- **Status updates**: `scripts/set-card-status.ps1` via `gh` (not MCP alone). See `AGENTS.md` / `CLAUDE.md` kanban rules.
- **GitHub auth check**: `scripts/check-gh-auth.ps1` — Windows `gh` keyring is SoT; do not reauth unless it fails.
- **CI / PR process**: `docs/architecture/ci-and-pr.md` — **no direct commits to `master`**; open a PR; required check is **`ci`**.

## Immutable principles
1. **Token optimization first** — high-signal artifacts only (specs, contracts, pseudo-code);
   structured output (tables/bullets/task cards) over prose; new session per major card;
   persist context in files, never in chat history.
2. **Functional + SOLID** — pure functions, composition, immutability. SRP = small focused
   functions; DIP = pass functions/contracts as parameters.
3. **Multi-agent pipeline** — Architect → Compression → Designer → PM (kanban) → Junior impl →
   Senior selective review. Each role sees only its compressed slice.
4. **Handoffs via immutable contracts** — Goal + Scope + Constraints + Acceptance per card;
   never re-explain the whole system.
5. **Maintainability** — heavy modularization, this living doc, automation in `scripts/`.

## Stack (decided — see `docs/architecture/workflow-v1.md`)
- **Host companion**: Elixir/OTP services (Spotify, weather, feed, photo, etymology, P5 dither).
- **Device**: Chromium kiosk @ 800×480 + Preact/TypeScript/Tailwind pure `state→view` UI +
  thin evdev input bridge. **Not** Remix/Node on device; **not** BEAM+Chromium co-located.
- Host↔device: versioned WebSocket JSON; device keeps last-snapshot cache for host-down.
- Functional paradigm everywhere; Elixir retained on host (justified placement, not abandoned).

## Workflow per feature
1. Architect writes `features/<name>/spec.md` (AC, data flow, function signatures, pseudo).
2. Compress (tables, Goal/Scope/Constraints/Acceptance cards; LLMLingua-style pruning for
   anything long).
3. Designer output (if UI work beyond the locked spec) → `features/<name>/design.md`.
4. PM breaks spec into kanban cards → GitHub project + `features/<name>/cards.md`.
5. Junior implements from the compressed card ONLY, in `features/<name>/impl/` → merged to `src/`.
6. Open a **PR** from a branch (`lane/*`, `chore/*`, `fix/*`, …); wait for **`ci`** green; merge to `master`.
7. Senior reviews critical paths, security, and function purity only (selective).

## Parallel multi-agent lanes (screen epics)
When running **weather + feed + Spotify** agents together, follow
`docs/architecture/parallel-lanes-v1.md` (path ownership, frozen WS envelope, wave 1 services
then wave 2 screens then wave 3 wire-up). Prompts: `features/_lanes/agent-prompts.md`.

## Escalation rules (senior review required)
- Anything touching the input daemon or screen router (shared platform code).
- External API contracts (Spotify, NWS, OpenUV, X, Wiktionary).
- Any deviation from the locked design spec or the template stack.

## Compression checklist (before every handoff)
- [ ] Structured format (table/bullets/card), not prose.
- [ ] Only the slice the next role needs — no full-system context.
- [ ] Tool/API outputs summarized, never pasted raw.
- [ ] Long specs pruned (LLMLingua-style: drop low-information tokens).

## Session rule
End every major response / work session with a **3–5 line "Next Session Context Chunk"**
appended to the relevant card or `features/<name>/spec.md`, so the next session resumes cheaply.
