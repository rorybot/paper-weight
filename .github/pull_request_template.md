## Summary

<!-- What card / why this PR -->

Closes #

## Checklist

- [ ] **One card** — work matches a single kanban issue (or labeled `cross-lane` / `chore/*` branch)
- [ ] **Status** — GitHub project Status set to In progress while working; Done after merge
- [ ] **Ownership** — only own lane paths (see `features/<name>/spec.md`); no drive-by other lanes
- [ ] **Frozen files** — no `application.ex` / `mix.exs` / shell / envelope unless the card says so
- [ ] **Tests** — host `mix test` and/or `npm run check` for touched trees; Screen modules have tests
- [ ] **Mirror** — after GH succeeds: `kanban/board.md` + feature `spec.md` card table
- [ ] **No secrets** in logs (no `gh auth token`)

## Test plan

- [ ] CI green (`ci` check)
- [ ] Local: relevant `mix test` / `npm run check` / input-bridge check

## Notes

<!-- Screenshots / follow-ups / wave-3 wire-up left undone -->
