# CarThing custom app

Custom app for a reflashed Spotify Car Thing (800×480, wheel/buttons via evdev). UI direction is
LOCKED — see `docs/design/carthing-context.md`. Workflow rules: `PROJECT_INSTRUCTIONS.md`.

## Workspace / worktree discipline (mandatory — read first, applies to every rule below)

This repo runs many parallel worktrees (`.worktrees/*`, `.claude/worktrees/*`) plus a shared
checkout, often on different branches at different points relative to `master`. Treating "the
checkout I happen to be in" as authoritative has repeatedly produced wrong diagnoses, wrong
commands, and whole sessions of work built on instructions that were already stale on `master`.

### Session-start gate (do this before any card work)

**The branch/cwd you land in is not the job.** Agents have repeatedly resumed a leftover
checkout (e.g. an old `agent/*` branch from a closed card) and piled unrelated WIP onto it.
That is a process failure, not a convenience.

1. Identify the **single issue number** for this session (e.g. `#161`).
2. `git fetch origin master`.
3. Run:
   - `git rev-parse --show-toplevel`
   - `git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD`
4. **Abort and relocate** unless **both** are true:
   - cwd is a **dedicated worktree** for this card (path under `.worktrees/<card-slug>/` or
     equivalent — not the bare repo root unless this is a read-only status question); **and**
   - branch name is for **this** issue (`lane/…`, `chore/…`, `fix/…` and includes the issue
     number or an unambiguous card slug). Detached HEAD, `master`, or any branch for a
     **different** / **closed** card → **not acceptable**.
5. If the gate fails, do **not** `git switch` the shared root and do **not** keep working
   there. From the **repo root** only:
   ```text
   git fetch origin
   git worktree add .worktrees/<card-slug> -b <prefix>/<card-slug>-<N> origin/master
   cd .worktrees/<card-slug>
   ```
   Then re-run step 3 until the gate passes. All implementation happens in that worktree.
6. Never "return to" a branch because it was already checked out, had uncommitted files, or
   looked familiar. Stale `agent/*` branches for closed issues are poison — delete them
   locally when discovered; do not resume them.

### Ongoing rules

- **Before running or recommending ANY command**, state out loud which directory / worktree /
  branch it targets, and confirm that's the one tied to the card actually being worked. Never
  hand a bare command without the exact path attached — see "Host paths vs agent paths" below.
- **Never assume a checkout is current — including this file.** `AGENTS.md`/`CLAUDE.md` in the
  shared checkout have themselves been found stale (missing entire mandatory sections present on
  `master`) mid-session, causing real downstream mistakes (a validation script that skipped a
  mandatory launcher pattern because the rule requiring it wasn't in the copy being read). At the
  start of any nontrivial session, `git fetch origin master` and diff `AGENTS.md`/`CLAUDE.md`
  against `origin/master`'s copies before trusting the local working tree's rules.
- Before asserting a card/PR/doc is "done," "current," or "buggy," run `git fetch origin master`
  and diff against `origin/master:<path>` rather than trusting the working tree in front of you.
- **When a command fails or behaves unexpectedly**, first ask "which workspace is this actually
  running in, and is it the right one for this card?" before concluding it's a code or toolchain
  bug. A surprising failure in the wrong worktree is not evidence of a real bug.
- **One worktree = one card.** Do not reuse a worktree across unrelated cards, and do not let a
  long-lived worktree sit unrefreshed while claiming it reflects current `master`.
- **Repo-root checkout stays clean.** Do not leave the shared root on a feature/`agent/*`
  branch with WIP. Prefer detached `origin/master` or a clean `master` when nothing else owns
  that ref. Card work lives only in `.worktrees/<card-slug>/`.

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

## MVP-first planning (mandatory)

- Every new milestone or multi-card plan must name a **First Visible Slice** before creating its
  supporting cards. Its acceptance must be something Rory can see or operate in the real target
  environment; tests, services, protocols, and successful builds alone are not a visible slice.
- The First Visible Slice must be deliverable within the first two cards of the milestone. If it
  would sit behind three or more prerequisite cards, stop and redesign the plan vertically or get
  Rory's explicit approval for that dependency depth.
- Fixture data, manual launch commands, disabled unfinished integrations, and temporary diagnostic
  controls are valid for the First Visible Slice unless Rory explicitly requires production data,
  cold boot, or final hardware interaction. Do not silently redefine MVP to include polish,
  automation, live credentials, reconnect behavior, or production deployment.
- After completing one card whose acceptance is not user-visible, the next completed card must
  produce or improve the visible target-device slice. Starting another invisible prerequisite
  requires Rory's explicit approval and a written explanation of why the visible slice cannot
  proceed first.
- When Rory states a near-term demo goal (for example, "one working screen tonight"), that outcome
  becomes the active planning gate. Preserve unrelated WIP safely, but do not start or continue
  infrastructure work that is not required for that exact demo until the demo is accepted or Rory
  explicitly changes priority.
- Before implementation begins, publish a **Vertical-slice check** containing:
  - the exact first screen/action Rory will see;
  - the smallest fixture/manual path that can produce it;
  - the cards and expensive operations that truly block it;
  - the features intentionally deferred until after the visible slice.
- At every pre-MVP card closeout, state the exact visible blocker removed and the next command/card
  that advances the First Visible Slice. If no direct visible blocker was removed, the card was
  mis-prioritized and the remaining plan must be re-reviewed before more work starts.

## Ticket sizing and expensive hardware work (mandatory)

- One card must have one primary deliverable and one acceptance boundary. Ordinary implementation
  plus its unit tests may stay together; independently failing discovery, integration, physical
  acceptance, and release steps may not be hidden inside one "deployment" card.
- Split hardware/device work into dependent cards when it spans these phases:
  1. device discovery and physical mapping (read-only probes);
  2. package/service implementation (unit tests and package-only build);
  3. candidate installation and physical/reconnect acceptance;
  4. production enablement (feature-flag removal and final system deploy).
- Before moving a proposed card to Ready, identify its slow lifecycle operations: remote builds,
  full system/image builds, flashes, deploys, reboots, and destructive migrations. If the card is
  expected to require more than one full build/deploy cycle, split it or get Rory's explicit
  approval for the exception.
- Before the first slow lifecycle operation, publish a **Cycle budget**: the exact expensive
  commands expected, what evidence must exist before each command, and its abort conditions.
  Do not give a duration estimate without measurements from the same current execution path.
- Finish discovery before building. Never run a full system build with provisional device paths,
  numeric mappings, credentials, URLs, or acceptance behavior. Prefer read-only probes,
  fake-device tests, and package-only candidate builds before assembling an image.
- Treat commands by behavior, not by name. If `deploy` performs a build, do not schedule a
  separate `build` unless its output is proven reusable. An ephemeral builder store means a prior
  standalone build is validation evidence, not a cache for deployment.
- If independent acceptance boundaries emerge after work starts, stop before the next slow
  operation, preserve the current WIP, and propose the new cards/dependency order to Rory. Create
  or re-scope GitHub cards only after approval; do not silently absorb the extra scope.

## Build/deploy failure diagnosis (mandatory)

A real build had never succeeded once, for about a week, because sessions kept re-diagnosing
device-level symptoms (dead buttons, stuck generation, corrupted flash) instead of reading the
actual build/deploy error text — which had the answer in plain English the whole time. See
`resolutions/nixbuild-aarch64-exec-format-error.md` ("Process failure" section).

- When a build/deploy command fails, **read the full raw error output yourself before proposing
  a fix**. Do not pattern-match a failure to a previously-seen device symptom (input-bridge
  crash, stuck generation, corrupted flash) without first confirming the literal error text
  actually says that. A failure on the host/builder side is a build problem, not a device
  problem, until the error text proves otherwise.
- Grep `resolutions/` for the exact error string (or a distinctive substring) before treating a
  build/deploy failure as novel.
- If a fix is genuinely new, **write it and commit it in the same session** — the script/config
  edit plus a `resolutions/*.md` entry. A fix only described in chat does not survive past that
  conversation; the next session re-pays the diagnosis cost.
- If the same class of failure recurs despite an existing `resolutions/` entry claiming it's
  fixed, check `git log` for the file/behavior that entry describes before re-diagnosing from
  scratch — the fix may have been said out loud but never actually committed.

## Code rules
- Functional style: pure functions, composition, immutability; small single-purpose modules.
- Stack is decided in `docs/architecture/workflow-v1.md` (host Elixir + device Preact kiosk + evdev bridge).

## Reuse check before implementation

- Before designing a new module, provider, or integration, run a targeted search across sibling
  repos under `/run/host/home/rory/repos` for an existing implementation that can inform the work.
- This is a narrow exception to the token rules: inspect only the relevant module, its focused
  tests, and directly related setup notes; never sweep an entire repo into context.
- Exclude generated/vendor/data trees and secrets (`node_modules`, build outputs, caches, `.env`,
  credentials). Reuse compatible patterns and interfaces, never secret values.
- Card ownership and frozen contracts still win. Record the reused project/module in the active
  card or feature spec, or note briefly why the existing implementation was not compatible.

## Launchers and dependency preflight (mandatory)

- A canonical launcher must own dependency readiness for every stack it starts. Check/bootstrap
  missing dependencies before starting any child process or opening any listener; do not expose a
  briefly healthy UI port and then tear it down because a second process failed.
- Run dependency commands from the directory containing their manifest (`host/mix.exs`,
  `src/device-ui/package.json`, etc.). Before handing Rory a recovery command, inspect the launcher
  and give the exact `cd` plus command instead of assuming the repository root is a project root.
- A skip-build flag skips compilation only. It must not skip dependency checks, configuration
  validation, required artifact checks, or other startup preconditions.
- Prefer one idempotent launcher over a sequence of undocumented manual setup commands. A clean
  checkout with toolchains installed should either become ready from that command or fail before
  side effects with one precise corrective error.
- When Rory identifies a valid intended recovery (for example `mix deps.get`), verify its required
  context and help execute that path. Do not replace it with a different workflow merely because
  another path could also work.

## Parallel lanes (weather / feed / spotify)
- Playbook: `docs/architecture/parallel-lanes-v1.md`
- Envelope (frozen): `docs/architecture/host-device-protocol-v1.md`
- Copy-paste agent prompts: `features/_lanes/agent-prompts.md`
- Wave 1 = three host services in parallel (W1/F1/N1); **do not** edit `application.ex`, shell, or other lanes.
- Each agent owns only its tree under `host/lib/paper_weight/{weather,feed,spotify}/` + matching tests + `src/device-ui/src/protocol/<channel>.ts`.

## Host paths vs agent paths (mandatory)

Agent sessions may see the machine through a Distrobox bind mount (`/run/host/...`). Rory's own
shell does not have that prefix — his working tree sits at the equivalent path *without*
`/run/host`. Before handing Rory any `cd` / command meant for his terminal (builds, deploys,
anything outside the sandbox), strip the `/run/host` prefix first. A `/run/host/...` path handed
to Rory points at a location that doesn't exist on his machine.

Every command handed to Rory must also be self-contained: either begin with `cd` to the exact
host-native working directory or use absolute host-native paths. Never assume his shell is still
in the repository or the intended worktree. For worktree sessions, include the complete
`.worktrees/<name>` path in the `cd`.

Additionally, **verify the file exists at the exact handed path before sending it** (`ls` the
agent-side `/run/host` equivalent). Never `~` or relative paths. A file merged to `master` is
NOT reachable through a checkout sitting on another branch — if the session's worktree was
removed after merge, materialize a fresh worktree of `origin/master` and hand that full
`.worktrees/<name>/...` path; do not delete a worktree Rory still needs to run something from.

## Podman / Distrobox — preserve runtime wiring (mandatory)

Normal use of the already-working container toolchain is allowed: repo build/test
commands, native `podman` in the current shell, an already-functional
`distrobox-host-exec podman ...`, and read-only `podman ps` / `distrobox list`.
Do not ask merely to run those established paths.

Never repair, replace, bridge, or reconfigure the host/container runtime from an
agent session:
- no `CONTAINERS_CONF*` / `CONTAINER_HOST`, custom `containers.conf`, helper-path
  overrides, runtime wrappers/symlinks, or host-library injection;
- no direct `/run/host/usr/bin/podman` fallback from inside Distrobox;
- no touching/removing `pause.pid`, sockets, storage, `conmon`, `crun`, `netavark`,
  `host-spawn`, or Distrobox plumbing;
- no installing helpers, stopping/removing/recreating Distroboxes, or
  `podman system reset`.

If a normal invocation reports stale-pause removal, missing helpers, or
host-exec status `126`/`127`, stop. Do not try alternate wiring or auto-install
anything. Report the exact error and, when useful, hand Rory a host-native
command with `/run/host` stripped from repo paths.

Ask Rory first and wait for a clear yes only for an intentional engine or
container lifecycle change not already requested by the active card.

**Known limitation (P6-N #84):** even a working `distrobox-host-exec podman` cannot cross-build
aarch64 here — rootless Podman gets a private `binfmt_misc` per container, so registering
qemu-aarch64, even as real host root, never becomes visible to a nested build sandbox. Builds
needing aarch64 emulation must run directly on the physical host, outside any container nesting.
See `docs/architecture/device-nixos-kiosk.md` for the full writeup.

## Git / PR (mandatory)

- **Never commit directly to `master`.** Branch → PR → wait for required check **`ci`** → merge.
- Path-filtered jobs: device-ui (`npm run check`), host (`mix test`), input-bridge (fmt/test/clippy),
  lane-guard, screen-test co-location. Docs: `docs/architecture/ci-and-pr.md`.
- Multi-lane code changes need label `cross-lane` or branch `chore/*`.
- **CI green is not validation for device-affecting changes.** For `device/` paths CI runs
  lane-guard/label jobs only — it proves nothing about on-device behavior. If a card's
  acceptance needs the physical device (or anything only Rory can run), do **not** merge on
  green CI: keep the PR open, hand Rory the verification run from the **branch worktree**
  (self-locating scripts deploy the branch, not master; exact host path rules above), and
  merge only after the logged physical pass. Learned on #111: attempt A merged on green CI
  and failed on hardware.

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
- Update the GitHub issue checklist immediately as each scope or acceptance item is verified.
  Do not batch checkbox updates at session close; GitHub must show incremental progress while
  work is underway, then mirror the verified evidence in `kanban/board.md` and the feature spec.
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
6. Card work remains on its **own** branch/worktree; the **repo-root** checkout is not left on
   that branch (park root at clean `origin/master` / detached master when possible).
7. Do not leave the next agent a zombie `agent/*` branch for a closed card — delete or ignore it.
