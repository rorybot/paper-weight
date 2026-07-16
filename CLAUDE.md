# CarThing custom app

Custom app for a reflashed Spotify Car Thing (800×480, wheel/buttons via evdev). UI direction is
LOCKED — see `docs/design/carthing-context.md`. Workflow rules: `PROJECT_INSTRUCTIONS.md`.

## Token rules (mandatory, from PROJECT_INSTRUCTIONS.md)
- Work **one kanban card per session**. Read only that card + its `features/<name>/spec.md`
  slice — do NOT re-read the whole design spec or other features' folders unless the card says to.
- Screen mockup PNGs live locally in `spec/` — Read ONLY the one for the card being worked.
  (`photo-4g.png` is pending manual download from claude.ai/design — DesignSync truncates it.)
- Never fetch the design canvas (`CarThing Explorations.dc.html`) or design-project files into
  context; the text spec + local `spec/` PNGs are authoritative.
- Outputs: structured (tables, bullets, Goal/Scope/Constraints/Acceptance cards), not prose.
  Summarize tool/API outputs instead of pasting them.
- End major work by appending a 3–5 line "Next Session Context Chunk" to the feature's spec.md.

## Code rules
- Functional style: pure functions, composition, immutability; small single-purpose modules.
- Stack is decided in `docs/architecture/workflow-v1.md` (until that exists, don't write src/ code).
- Kanban: https://github.com/users/rorybot/projects/1 — keep `kanban/board.md` in sync when
  creating/closing cards (`gh project item-create 1 --owner rorybot ...`).
