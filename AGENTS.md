# CarThing custom app

Custom app for a reflashed Spotify Car Thing (800×480, wheel/buttons via evdev). UI direction is
LOCKED — see `docs/design/carthing-context.md`. Workflow rules: `PROJECT_INSTRUCTIONS.md`.

## Token rules (mandatory, from PROJECT_INSTRUCTIONS.md)
- Work **one kanban card per session**. Read only that card + its `features/<name>/spec.md`
  slice — do NOT re-read the whole design spec or other features' folders unless the card says to.
- Screen mockup PNGs live locally in `spec/` — Read ONLY the one for the card being worked.
  (`photo-4g.png` is pending manual download from the design tool — DesignSync truncates it.)
- Never fetch the design canvas (`CarThing Explorations.dc.html`) or design-project files into
  context; the text spec + local `spec/` PNGs are authoritative.
- Outputs: structured (tables, bullets, Goal/Scope/Constraints/Acceptance cards), not prose.
  Summarize tool/API outputs instead of pasting them.
- End major work by appending a 3–5 line "Next Session Context Chunk" to the feature's spec.md.

## Code rules
- Functional style: pure functions, composition, immutability; small single-purpose modules.
- Stack is decided in `docs/architecture/workflow-v1.md` (host Elixir + device Preact kiosk + evdev bridge).

## Parallel lanes (weather / feed / spotify)
- Playbook: `docs/architecture/parallel-lanes-v1.md`
- Envelope (frozen): `docs/architecture/host-device-protocol-v1.md`
- Copy-paste agent prompts: `features/_lanes/agent-prompts.md`
- Wave 1 = three host services in parallel (W1/F1/N1); **do not** edit `application.ex`, shell, or other lanes.
- Each agent owns only its tree under `host/lib/paper_weight/{weather,feed,spotify}/` + matching tests + `src/device-ui/src/protocol/<channel>.ts`.

## Git / PR (mandatory)

- **Never commit directly to `master`.** Branch → PR → wait for required check **`ci`** → merge.
- Path-filtered jobs: device-ui (`npm run check`), host (`mix test`), input-bridge (fmt/test/clippy),
  lane-guard, screen-test co-location. Docs: `docs/architecture/ci-and-pr.md`.
- Multi-lane code changes need label `cross-lane` or branch `chore/*`.

## Kanban rules (mandatory — GitHub is source of truth)

Board: https://github.com/users/rorybot/projects/1  
Issues: https://github.com/rorybot/paper-weight/issues  
Mirror: `kanban/board.md` (update **after** GitHub succeeds, never instead of).

### GitHub CLI + auth (do not thrash this)
- Use the native toolchain for the current shell:
  - Linux/macOS/WSL/container: `gh` + `scripts/*.sh`.
  - Windows PowerShell: `gh` + `scripts/*.ps1`.
- **Never invoke PowerShell or `gh.exe` from a Linux shell merely because a Windows helper
  exists.** Do not assume another OS's keyring is the source of truth.
- Smoke test: `scripts/check-gh-auth.sh` on POSIX, or
  `powershell -File scripts/check-gh-auth.ps1` on Windows (exit 0 = good).
- Expected scopes already include `repo` + `project` + `read:org`. Do **not** run
  `gh auth login` / `gh auth refresh` unless the native smoke test exits 1.
- Prefer **`gh` CLI** for issues/projects. GitHub MCP often returns
  `Resource not accessible by integration` for Projects — that is **not** a reauth signal;
  fall back to `gh`, do not nag the human to re-login.
- Never print tokens (`gh auth token`, `gh auth status -t`).

### Do
- Use `scripts/set-card-status.sh --issue <N> --status "<Status>"` on POSIX,
  `scripts/set-card-status.ps1 -Issue <N> -Status "<Status>"` on Windows, or equivalent
  `gh project item-edit`.
- Status vocabulary: `Backlog` | `Ready` | `In progress` | `In review` | `Done`.
- **In progress** only when real work for that card exists or is actively started this session.
- **Done** only when acceptance is met: set Status → Done, **and** `gh issue close <N>`, **and**
  update `kanban/board.md` + `features/<name>/spec.md` card table.
- New cards: `gh issue create --repo rorybot/paper-weight ...` then
  `gh project item-add 1 --owner rorybot --url <issue-url>` then set Status (default Ready/Backlog).
  **No draft project items.**

### Do not
- Edit only `kanban/board.md` and claim the board is updated.
- Leave a card **In progress** with no matching code/docs for that card.
- Leave substantial WIP while the card stays **Ready** / **Backlog**.
- Use `scripts/push-cards.ps1` for existing cards (legacy draft creator).
- Invent Status values or skip remote update because MCP failed — fall back to `gh`.
- Ask the human to reauthenticate GitHub when the native `check-gh-auth` script would pass.

### Session end checklist (every card session)
1. GitHub project Status matches reality.
2. Issue open/closed matches Done vs not.
3. `kanban/board.md` status line + card heading match GH.
4. Feature `spec.md` card table matches.
5. Uncommitted work for the card is either committed or explicitly noted as local-only WIP.
