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
  (`photo-4g.png` is pending manual download from claude.ai/design — DesignSync truncates it.)
- Never fetch the design canvas (`CarThing Explorations.dc.html`) or design-project files into
  context; the text spec + local `spec/` PNGs are authoritative.
- Outputs: structured (tables, bullets, Goal/Scope/Constraints/Acceptance cards), not prose.
  Summarize tool/API outputs instead of pasting them.
- End major work by appending a 3–5 line "Next Session Context Chunk" to the feature's spec.md.

## Code rules
- Functional style: pure functions, composition, immutability; small single-purpose modules.
- Stack is decided in `docs/architecture/workflow-v1.md` (host Elixir + device Preact kiosk + evdev bridge).

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

## Device deploy hygiene (mandatory)

A device build/deploy costs real minutes-to-an-hour; a wasted build-and-rollback cycle from a
foreseeable, checkable condition is not an acceptable cost of doing business.

- Before telling Rory (or running yourself) `scripts/device-nixos.sh deploy` — or any command
  that activates a service on a fixed port/socket on the physical device — **first check the
  device's actual runtime state for that resource**: `ssh ... "ss -tlnp | grep <port>"` and
  `ps aux | grep <daemon>`, confirming anything already holding it is the systemd-managed
  instance. That check costs seconds; running it up front preserves a completed build instead of
  losing it to an activation failure and deploy-rs auto-rollback. See
  `resolutions/deploy-rollback-from-stray-manual-input-bridge.md`.
- When asked how much of a build will be reused, cached, or fast on a retry, **answer only from
  something you've actually verified** about deploy-rs/Nix behavior for this case. State
  uncertainty plainly ("not sure how much this reuses") when you haven't checked — that costs
  far less of Rory's time than a wrong confident guess.
- When adding or touching a deploy path for a fixed-port/singleton service, **write its preflight
  conflict check into the script in that same pass** — treat the check as part of the deploy
  path's definition of done, not a follow-up.
- When manually starting a daemon on-device for a quick proof-of-concept (e.g. `input_bridge`
  outside systemd), **kill it before ending the session**. A live orphaned process is the kind of
  device state a future session needs to be able to trust is clean.

## Host paths vs agent paths (mandatory)

Agent sessions may see the machine through a Distrobox bind mount (`/run/host/...`). Rory's own
shell does not have that prefix — his working tree sits at the equivalent path *without*
`/run/host`. Before handing Rory any `cd` / command meant for his terminal (builds, deploys,
anything outside the sandbox), strip the `/run/host` prefix first. A `/run/host/...` path handed
to Rory points at a location that doesn't exist on his machine.

Every command handed to Rory must also be self-contained: either begin with `cd` to the exact
host-native working directory or use absolute host-native paths — never `~` or relative paths.
Include the complete `.worktrees/<name>` path for worktree files, and **verify the file exists
at the exact handed path before sending it** (`ls` the agent-side `/run/host` equivalent). A
file merged to `master` is NOT reachable through a checkout sitting on another branch — if the
session's worktree was removed after merge, materialize a fresh `origin/master` worktree and
hand that path; do not delete a worktree Rory still needs to run something from.

**Creating a worktree is not exempt.** `git worktree add` bakes the *absolute invocation-time
path* into persistent pointer files (the new worktree's `.git` file, and the main repo's
`.git/worktrees/<name>/gitdir`) — unlike most commands, that path outlives the command and is
read later by whichever shell (agent or Rory's) next touches the worktree. Always run
`git worktree add` from a cwd under `/home/rory/...` (host-native), never under
`/run/host/home/rory/...`, even though both resolve to the same files from inside the
container. Getting this wrong doesn't just mis-hand a command — it corrupts the worktree so
`git` fails with a cryptic `fatal: not a git repository: (null)` from Rory's shell (and from
any other agent that later inherits the same worktree). If you ever see that exact error,
check the two pointer files above for a leaked `/run/host` path before assuming anything else
is broken. The underlying rule is general, not just about `cd`/paths: respect workspaces and
branches as shared, persistent state — every action that creates or touches one must work
correctly for whichever context (container or host) next reads it, not just the one that
created it.

## Parallel lanes (weather / feed / spotify)
- Playbook: `docs/architecture/parallel-lanes-v1.md`
- Envelope (frozen): `docs/architecture/host-device-protocol-v1.md`
- Copy-paste agent prompts: `features/_lanes/agent-prompts.md`
- Wave 1 = three host services in parallel (W1/F1/N1); **do not** edit `application.ex`, shell, or other lanes.

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
