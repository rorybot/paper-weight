# PROJECT_INSTRUCTIONS.md — CarThing custom app (living doc)

Operating framework: **Token-Optimized Multi-Agent Functional Development Framework v0.4**
(full template: `docs/CLAUDE_PROJECT_TEMPLATE.md`). Treat the principles below as immutable.

## Project links
- **Design spec (source of truth for UI)**: `docs/design/carthing-context.md`
- **Design canvas + screen PNGs**: https://claude.ai/design/p/b8c05a93-b6c5-4a77-ad4b-6c106e533c3f?file=CarThing+Explorations.dc.html
- **Kanban**: https://github.com/users/rorybot/projects/1 (mirror: `kanban/board.md`)

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

## Stack
- Template default: Elixir backend, Remix/React + TypeScript + Tailwind frontend.
- **PENDING**: card `[platform] Architecture spike` must validate this against Car Thing
  hardware (ARM, limited RAM, reflashed Linux, evdev input, 800×480 panel) before any src/ code
  is written. Deviations from the template stack must be justified in
  `docs/architecture/workflow-v1.md`.

## Workflow per feature
1. Architect writes `features/<name>/spec.md` (AC, data flow, function signatures, pseudo).
2. Compress (tables, Goal/Scope/Constraints/Acceptance cards; LLMLingua-style pruning for
   anything long).
3. Designer output (if UI work beyond the locked spec) → `features/<name>/design.md`.
4. PM breaks spec into kanban cards → GitHub project + `features/<name>/cards.md`.
5. Junior implements from the compressed card ONLY, in `features/<name>/impl/` → merged to `src/`.
6. Senior reviews critical paths, security, and function purity only.

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
