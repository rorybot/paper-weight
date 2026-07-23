# Agent prompts — wave 1 (three parallel services)

Use **one worktree + one issue per agent**. Read only the files listed.  
Orchestrator doc: `docs/architecture/parallel-lanes-v1.md`.

---

## ⚠️ ISOLATION IS MANDATORY — one worktree (or container) per agent

**Never run two agents in the same checkout.** `HEAD` is global per working tree: another
agent's `git switch` moves it mid-session and your commit silently lands on *their* branch.
This is not hypothetical — in Wave-3 Day-2 (2026-07-18) the E2 agent's commit landed on
W3-C's branch because all three sessions shared the repo-root checkout, and it took ref
surgery (`git push <sha>:refs/heads/…`, `branch -f`, `reset --hard`) to untangle.

**Also not hypothetical (2026-07-22):** agents keep resuming a leftover root checkout on an
old `agent/*` branch from a **closed** card and dumping new-card WIP there. The cwd/branch
you inherit is **not** the job. Full rule: `AGENTS.md` / `CLAUDE.md` → **Session-start gate**.

**Every future parallel wave (and every single-card agent) MUST paste this block verbatim
at the top of each agent's prompt** (fill in `<lane-or-card>` / `<branch>` / `<issue-N>`):

```text
ISOLATION + SESSION-START GATE (mandatory — do this FIRST, before any other git command):
You share this machine with other concurrent agents. The repo-root checkout is SHARED —
never `git switch` it and never commit from it.

1) Name your issue: #<issue-N>.
2) git fetch origin master
3) Check:
     git rev-parse --show-toplevel
     git symbolic-ref --short HEAD 2>/dev/null || echo DETACHED
4) If cwd is NOT .worktrees/<lane-or-card> OR branch is NOT exactly for #<issue-N>
   (detached / master / some other agent/* or closed-card branch):
     STOP working in place. From the repo root only:
       git worktree add .worktrees/<lane-or-card> -b <your-exact-branch> origin/master
       cd .worktrees/<lane-or-card>
   Never resume a familiar leftover branch. Delete local zombie agent/* branches for
   closed issues when you find them.
5) Then do ALL work with cwd inside that worktree for the entire session.
Before EVERY commit and push, re-verify in the same compound command:
  git rev-parse --show-toplevel    → must be your .worktrees/<lane-or-card> path
  git symbolic-ref --short HEAD    → must be your exact branch for #<issue-N>
Stage only your own paths — other agents' WIP may be loose in a shared tree.
If worktrees are not possible in your environment (cwd is pinned, toolchain or port
conflicts with other lanes), isolate harder: run inside your own distrobox container with
its own full clone (distrobox create -n lane-<lane>; git clone inside it) — anything but
a shared HEAD. If you cannot achieve isolation, STOP and report instead of proceeding.
```

Orchestrator side: launch each session with cwd already set to its worktree (or its
container's clone) — do not rely on the agent to relocate itself. Park the **repo-root**
checkout at clean `origin/master` (or detached) between cards so the next session does not
inherit a zombie branch.

---

## Shared preamble (every agent)

```text
Repo: paper-weight (Car Thing). Stack: host Elixir services + device Preact UI.
You are ONE parallel lane agent. Follow docs/architecture/parallel-lanes-v1.md ownership.
Do NOT edit: host application.ex, mix.exs, shell/, design/, other lanes, envelope protocol.
If you need a Mix dep, append "## Deps request" to your feature spec only.
Set your GitHub issue In progress via scripts/set-card-status.ps1 when you start;
Done only when acceptance checklist in your feature spec is met (close issue + board).
Work functional: pure cores, impure edges. Small modules.
```

---

## Agent A — Weather (W1 #9)

```text
[shared preamble]

Card: W1 #9 — Weather data service (NWS + OpenUV).
Read ONLY:
- features/weather/spec.md
- docs/architecture/host-device-protocol-v1.md
- docs/architecture/parallel-lanes-v1.md (ownership section)
- host/lib/paper_weight/dither/** is off-limits; you don't need it

Implement under:
- host/lib/paper_weight/weather/
- host/test/paper_weight/weather/
- src/device-ui/src/protocol/weather.ts (payload types only)

Acceptance: mocked NWS/OpenUV tests; UV grade + walk_verdict pure tests;
WeatherSnapshotV1; stale path; mix test green for your tests.
Do not start W2 UI in this session unless fixtures-only and separate commit.
```

---

## Agent B — Feed (F1 #12)

```text
[shared preamble]

Card: F1 #12 — X/Twitter snapshot service (read-only).
Read ONLY:
- features/feed/spec.md
- docs/architecture/host-device-protocol-v1.md
- docs/architecture/parallel-lanes-v1.md (ownership section)

Implement under:
- host/lib/paper_weight/feed/
- host/test/paper_weight/feed/
- src/device-ui/src/protocol/feed.ts (payload types only)

Acceptance: fixture ≥3 posts; stable accents; atomic snapshot replace;
stale path; no write APIs; mix test green for your tests.
Do not modify src/device-ui/src/sample/FeedSample.tsx (P4 fixture).
```

---

## Agent C — Spotify (N1 #6)

```text
[shared preamble]

Card: N1 #6 — Spotify data service.
Read ONLY:
- features/now-playing/spec.md
- docs/architecture/host-device-protocol-v1.md
- docs/architecture/parallel-lanes-v1.md (ownership section)
- host/lib/paper_weight/dither/** (call only, do not edit)

Implement under:
- host/lib/paper_weight/spotify/
- host/test/paper_weight/spotify/
- src/device-ui/src/protocol/now_playing.ts (payload types only)

Acceptance: mocked Spotify API tests; set_volume(delta) clamp 0–100;
NowPlayingSnapshotV1; NO play/pause; mix test green for your tests.
Intent name frozen: set_volume.
```

---

## How to launch (human / orchestrator)

```bash
# from repo root, after parallel-lanes doc is on master
git worktree add .worktrees/weather -b lane/weather-w1 master
git worktree add .worktrees/feed    -b lane/feed-f1    master
git worktree add .worktrees/spotify -b lane/spotify-n1 master

scripts/set-card-status.sh --issue 9  --status "In progress"
scripts/set-card-status.sh --issue 12 --status "In progress"
scripts/set-card-status.sh --issue 6  --status "In progress"
```

Open three agent sessions with cwd = each worktree; paste the matching prompt.

---

## Wave 2 prompts (after wave 1 green)

Same ownership tables in `parallel-lanes-v1.md`; cards W2 #10, F2 #13, N2 #7.  
Read own feature spec + **only** your mockup PNG under `spec/`.  
Do not edit shell; export screen component for wave-3 registry.

---

## Wave 3 Day-1 prompts (W3-A + W3-B + E1 parallel)

**Prerequisite met:** PR #53 (W3-P1, protocol v1.1) is merged to `master` — the `playlist`
channel is in `ChannelV1`, so W3-A's fixture store can include it.

Zero file overlap, three-way parallel-safe:
- W3-A is device-only (`src/device-ui/src/shell/`)
- W3-B is host-only (`host/mix.exs`, `application.ex`, `config/`)
- E1 is a new isolated tree (`host/lib/paper_weight/etymology/`,
  `src/device-ui/src/protocol/etymology.ts`)

None of the three is blocked by either of the others — safe to run all three at once in
separate worktrees.

### Shared preamble (both agents)

```text
Repo: paper-weight (Car Thing). Stack: host Elixir services + device Preact UI.
You are ONE parallel wave-3 agent. Follow docs/architecture/parallel-lanes-v1.md ownership
and the constraints in your own card below — they override the wave-1 ownership table where
they differ (this is platform wiring, not a domain lane).
Set your GitHub issue In progress via scripts/set-card-status.sh when you start;
Done only when your card's acceptance is met (close issue + update kanban/board.md +
features/platform/spec.md card table, and append a Next Session Context Chunk there).
Work functional: pure cores, impure edges. Small modules. No unrelated refactors.
```

### Agent A — W3-A #44 (device shell screen map + channel store)

```text
[shared preamble]

Card: W3-A #44 — Device shell screen map + channel store.
Read ONLY:
- features/platform/spec.md
- docs/architecture/host-device-protocol-v1.md (envelope + channel union, read-only)
- src/device-ui/src/protocol/*.ts (payload types, read-only — do not edit)
- src/device-ui/src/shell/ShellApp.tsx, model.ts, router.ts, ScreenShell.tsx (read for context — model.ts/router.ts are off-limits to edit)

Goal: render every built screen and overlay from a single channel-to-snapshot store, seeded
by fixtures; route shell commands to screen props without networking.

Implement under:
- src/device-ui/src/shell/channelStore.ts (new) — pure applyEnvelope, stale-generation
  rejection, unknown-channel ignore, fixture store including playlist.
- src/device-ui/src/shell/ShellApp.tsx — wire real Now Playing, Feed, Photo, Playlist,
  Settings, Lyrics, and feed-detail components (currently only Weather/Home are wired).

Constraints:
- Branch: feat/w3a-shell-screen-map.
- Do NOT edit bridge.ts, router.ts, model.ts, screens/**, protocol/**, or anything under host/.
- No WebSocket/network code, no new dependencies, no play/pause.

Acceptance:
- Every ScreenId and overlay renders the real component from fixture data.
- Stale-generation and unknown-channel behavior are unit tested.
- npm run check passes (typecheck + tests + build).
```

### Agent B — W3-B #45 (host deps, Application children, runtime config)

```text
[shared preamble]

Card: W3-B #45 — Host deps, Application children, and runtime config.
Read ONLY:
- features/platform/spec.md
- docs/architecture/host-device-protocol-v1.md (read-only, for context only)
- host/lib/paper_weight/application.ex (current: Dither.Cache + weather_children/0 only)
- host/mix.exs
- host/config/config.exs

Goal: supervise all four service GenServers with per-service enablement and add the locked
WebSocket dependencies/configuration plumbing (nothing starts Bandit yet — that's W3-C).

Implement under:
- host/mix.exs — add bandit, websock_adapter, plug (and lockfile).
- host/lib/paper_weight/application.ex — generalize into a pure, testable children/1 that
  supports Weather, Spotify, Feed, and Photo as :enabled | :disabled each. Weather stays
  enabled by default; Spotify/Feed/Photo default to :disabled so zero-env tests pass.
- host/config/config.exs (or runtime.exs) — runtime config for Spotify auth, photo directory,
  feed URLs.
- host/test/ — tests for child specs across enable/disable combinations.

Constraints:
- Branch: feat/w3b-host-app-children.
- Do NOT modify service modules (weather/, spotify/, feed/, photo/ internals), envelope, or
  any device UI.
- Do NOT start Bandit or open a socket — deps + config only.

Acceptance:
- mix test passes with zero environment (all non-weather services disabled).
- All-enabled config yields four service child specs.
- Weather default behavior is unchanged.
- New dependencies compile in CI.
```

### Agent C — E1 #16 (word-origin data service)

```text
[shared preamble]

Card: E1 #16 — Word-origin data service.
Read ONLY:
- docs/design/carthing-context.md — §Etymology sections only (day's-word + nested origin
  trace description; do not read the rest of the design spec)
- spec/etymology-2a-depth0.png, etymology-2b-depth1.png, etymology-2c-depth2.png (mockups,
  for shape/context only — this card builds the data service, not the screen)
- docs/architecture/host-device-protocol-v1.md (envelope, read-only — `etymology` stays an
  ignored/omitted channel for now, do not add it to the channel union)
- docs/architecture/parallel-lanes-v1.md (ownership section)

Unlike the other lanes, there is no features/etymology/spec.md yet — write one as you work,
following the same Goal/Scope/Acceptance shape as features/weather/spec.md, and record your
payload type there once decided.

Goal: day's word + nested origin trace (Wiktionary-style source), recursive trace structure
(stage → sub-trace → … → root), daily selection, cache the day's tree.

Implement under:
- host/lib/paper_weight/etymology/ (new)
- host/test/paper_weight/etymology/ (new)
- src/device-ui/src/protocol/etymology.ts (new — payload types only)
- features/etymology/spec.md (new — write this as you go)

Constraints:
- Branch: feat/e1-word-origin-service.
- Do NOT edit host/lib/paper_weight/application.ex, mix.exs, shell/, protocol/envelope.ts,
  envelope.ex, or any other lane's tree — this stays a standalone, unwired service.
- Do NOT add `etymology` to the ChannelV1 / channel union — that's a future protocol card.

Acceptance:
- A `travailler`-style fixture yields a ≥3-depth tree with a terminal root.
- mix test green for your tests.
- features/etymology/spec.md exists and documents the payload shape.
```

### How to launch (human / orchestrator)

```bash
# from repo root — PR #53 is already merged to master
git fetch
git worktree add .worktrees/w3a -b feat/w3a-shell-screen-map master
git worktree add .worktrees/w3b -b feat/w3b-host-app-children master
git worktree add .worktrees/e1  -b feat/e1-word-origin-service master

scripts/set-card-status.sh --issue 44 --status "In progress"
scripts/set-card-status.sh --issue 45 --status "In progress"
scripts/set-card-status.sh --issue 16 --status "In progress"
```

Open three agent sessions with cwd = each worktree; paste the matching prompt. Merge order
doesn't matter (disjoint trees) — land whichever finishes review first. Once W3-A and W3-B
are both Done, W3-C #46 and W3-D #47 unblock (each still needs W3-P1 merged, which is
already satisfied). Once E1 is Done, E2 #17 unblocks.

---

## Wave 3 Day-2 prompts (W3-C + W3-D + E2 parallel)

Three agents are operating concurrently on #46, #47, and #17. Their dependencies (W3-B, W3-A,
E1) are all merged and Done, so all three cards are Ready now.

Ownership is disjoint by design:
- W3-C is host-only (`host/lib/paper_weight/gateway/**`)
- W3-D is device-only (`src/device-ui/src/shell/gateway.ts`, `shell/intents.ts`, `main.tsx`,
  plus the minimal `ShellApp`/`channelStore` seam for live envelopes)
- E2 is a new isolated tree (`src/device-ui/src/screens/etymology/**`)

The one conflict found during review: both W3-D and E2 could otherwise need `ShellApp.tsx`.
Resolved by giving `ShellApp` exclusively to W3-D this wave — E2 exports a stable
fixture-backed screen API and gets wired into `ShellApp` only after W3-D merges.

### Shared preamble (all three agents)

```text
Repo: paper-weight (Car Thing). Stack: host Elixir services + device Preact UI.
You are ONE of three parallel wave-3 Day-2 agents, operating concurrently on issues #46
(W3-C), #47 (W3-D), and #17 (E2). Follow docs/architecture/parallel-lanes-v1.md ownership
and the constraints in your own card below.

FIRST: follow the mandatory ISOLATION block (top of this file) — create your own worktree
(or distrobox clone) and work only there. The shared repo-root checkout is off-limits for
git switch/commit. [Historical note: this wave originally said "switch to master … create
your exact feature branch" in a shared checkout, which caused the E2/W3-C branch collision.]

Before editing: in YOUR worktree, git fetch, run scripts/check-gh-auth.sh, and set ONLY
your own issue to In progress via scripts/set-card-status.sh. Never edit another agent's
paths or Project status.

Before pushing: git fetch and inspect `git diff --name-only origin/master...HEAD` to confirm
you have not touched another agent's files. Rebase only for a real dependency/conflict; never
merge another in-flight feature branch. Never push to master. One branch, one issue, one PR.

Mark your issue In review when you open your PR. Move to Done and close it only after CI is
green and the PR is merged, updating kanban/board.md and your feature spec's card table.

If you find yourself needing to cross into another agent's owned paths, stop and document the
seam in your card's spec instead of crossing it.

Work functional: pure cores, impure edges. Small modules. No unrelated refactors.

Your handoff must report: files touched, tests added, CI/PR status, any remaining
cross-lane seam, and a 3–5 line Next Session Context Chunk appended to your feature spec.
```

### Agent A — W3-C #46 (host WebSocket gateway snapshot push)

```text
[shared preamble]

Card: W3-C #46 — Host WebSocket gateway snapshot push.
Branch: feat/w3c-ws-gateway-push.
Own:
- host/lib/paper_weight/gateway/** (new)
- host/test/paper_weight/gateway/** (new)
- the smallest possible child/config append in application.ex to register the gateway
- W3-C's own status/context docs only

Goal: build a Bandit/WebSock endpoint on port 9138 that publishes one frozen-v1 envelope per
enabled service on connect and on every generation advance.

Implementation shape:
- Pure snapshot collection / envelope assembly, with service adapters injected — keep the
  network edge (socket handling) thin and separate from the pure assembly logic.
- Use the existing W3-B dependencies only (bandit, websock_adapter, plug already in mix.exs);
  do NOT edit mix.exs or mix.lock.
- Publish actual now_playing/weather/feed/photo snapshots using each service's real API:
  Weather get_snapshot/1 + get_gen/1; Spotify now_playing/1, queue/1, get_gen/1; Feed
  current/1 (returns state including snapshot/gen); Photo get_snapshot/1 + get_gen/1.
- Playlist channel: a valid fixture/stub is fine until W3-G lands.
- Omit etymology entirely — it stays outside Wave 3.
- Drop inbound frames for now (frame handling is W3-E's job) — this card is publish-only.
- The gateway must bind no port under `MIX_ENV=test`.

Constraints:
- No device UI edits, no protocol/envelope.ex changes.
- Do not react to inbound frames yet — that's W3-E #48.

Acceptance:
- Publisher edge-case tests (missing/disabled service, stale gen, etc).
- Socket connect / generation-advance / disconnect tests.
- Application/config tests covering the new child.
- Moduledoc documents an `iex -S mix` + `websocat` smoke path.
- mix format / mix test / CI green.
```

### Agent B — W3-D #47 (device WebSocket client feeding channel store)

```text
[shared preamble]

Card: W3-D #47 — Device WebSocket client feeding channel store.
Branch: feat/w3d-device-ws-client.
Own:
- src/device-ui/src/shell/gateway.ts (new) + tests
- src/device-ui/src/shell/intents.ts (new) + tests
- src/device-ui/src/main.tsx + focused tests
- only the minimal ShellApp/channelStore seam needed to feed it live envelopes
- W3-D's own status/context docs only

Goal: when a `?gateway=ws://...` query param is present, connect to the host gateway and feed
live envelopes into the existing W3-A channelStore.applyEnvelope path; when it is absent,
fixture mode must behave exactly as it does today.

Implementation shape:
- Pure parsing, backoff, and command-to-intent mapping — keep the WebSocket edge thin.
- Tolerant envelope decode that funnels into channelStore's applyEnvelope; ignore malformed,
  wrong-version, unknown-channel, or stale-generation frames safely (no throws).
- Deterministic, bounded reconnect/backoff.
- Allowed outbound intents: set_volume, play_playlist, refresh_channel. No play/pause.
- Preserve the existing P2 EventSource/keyboard path unchanged.

Constraints:
- Do NOT edit bridge.ts, router.ts, model.ts, ScreenShell.tsx, screens/**, protocol/**, or
  anything under host/.
- Do NOT wire E2/etymology — that integration lands after this card merges.

Acceptance:
- Mock-WebSocket coverage: connect, envelope update, malformed/ignore, send, reconnect,
  backoff cap, and dispose.
- Existing keyboard/EventSource fixture path still green.
- npm run check and CI green.
```

### Agent C — E2 #17 (etymology drill-down screen)

```text
[shared preamble]

Card: E2 #17 — Etymology drill-down screen (one state machine, 3 depths).
Branch: feat/e2-etymology-drilldown.
Own exclusively:
- src/device-ui/src/screens/etymology/** (new)
- E2's own status/context docs only

Read only:
- The E2 feature-spec slice
- The frozen EtymologySnapshotV1 payload type (from E1, src/device-ui/src/protocol/etymology.ts)
- The three local etymology PNGs in spec/

Goal: build ONE pure state machine/component covering depths 0/1/2 — not three screens: depth
0 = root-of-day + trace ladder (wheel scrolls stages); press digs into the highlighted stage
(depth 1, breadcrumb grows); bottom = terminal root reveal (depth 2); back walks the
breadcrumb up one level, no-op at depth 0.

Constraints:
- No shell/main/protocol/host/package.json edits, and no edits to any other screen's tree.
- No networking, no ChannelV1 changes — this card consumes the frozen payload type only.
- Wheel selection must clamp at trace-ladder bounds; treat the payload as immutable.
- Export a stable component/fixture API — this is what W3-D's ShellApp seam wires in next,
  after this PR merges.

Acceptance:
- Reducer tests: bounds, descend, terminal root, breadcrumb, back (including no-op at depth 0).
- Component tests for all three depth states, rendered at 800×480, matching the mockup PNGs.
- npm run check and CI green.
- PR description records the remaining shell-integration seam for the W3-D follow-up.
```

### How to launch (human / orchestrator)

```bash
# from repo root — W3-B, W3-A, and E1 are all merged and Done on master
git fetch
git worktree add .worktrees/w3c -b feat/w3c-ws-gateway-push master
git worktree add .worktrees/w3d -b feat/w3d-device-ws-client master
git worktree add .worktrees/e2  -b feat/e2-etymology-drilldown master

scripts/set-card-status.sh --issue 46 --status "In progress"
scripts/set-card-status.sh --issue 47 --status "In progress"
scripts/set-card-status.sh --issue 17 --status "In progress"
```

Open three agent sessions with cwd = each worktree; paste the matching prompt above (shared
preamble + card-specific section). Merge order doesn't matter between W3-C and E2 (disjoint
trees) — land whichever finishes review first. W3-D should land before E2's shell-integration
follow-up is picked up, since E2 only gets wired into `ShellApp` after W3-D merges. Once W3-C
is Done, W3-E #48 unblocks; once W3-D, W3-E, and W3-G are all Done, W3-F #50 (final
integration smoke) unblocks.

Full roadmap + dependency graph: `docs/architecture/parallel-lanes-v1.md` §Wave-3 card plan.

---

## Resume prompts — P6-I / P7 / P8 / W4 / N4

Snapshot as of 2026-07-19: #82 P6-I is Done/closed. #85 P7 is Ready and #86 P8 is In progress;
they may resume independently. #87 W4 and #89 N4 remain transitively blocked on #85. Unattended
startup on the eventual service host and simultaneous host/Car Thing cold boot belong to
final-appliance gate #90 P9, not #82.

```
#83 P6-H + #84 P6-N → #82 P6-I (Done)
                              ├─→ #85 P7 (Ready) → #87 W4 + #89 N4
                              └─→ #86 P8 (In progress)
#85 + #86 + #87 + #88 F3 + #89 → #90 P9 (eventual-host cold boot)
```

Hand each active agent its own letter below and point it at this section only — do not let one
agent read another's block. Agent D is complete; Agents A and E can now resume independently.

### Agent A — P8 #86 (input bridge deployment)

```text
ISOLATION (mandatory — do this FIRST):
The repo-root checkout is SHARED — never `git switch` it, never commit from it.
Your worktree already exists. Run:
  cd /run/host/home/rory/repos/paper-weight/.worktrees/p8-input-bridge
  git rev-parse --show-toplevel    → must print this worktree's path
  git symbolic-ref --short HEAD    → must print feat/p8-device-input-bridge
Re-verify both before every commit and push.

Card: P8 #86 — Device input-bridge deployment. PR #98 (draft, CI green, mergeable clean).
Read ONLY:
- The current PR #98 diff/description (gh pr view 98 --repo rorybot/paper-weight)
- features/platform/spec.md — P8 section only
- docs/architecture/parallel-lanes-v1.md (ownership section)

#82 P6-I is Done. Confirm that state once, then continue below.

Status: evdev reconnect/backoff + held-key reset is done and tested (17 x86_64-musl tests,
strict Clippy, aarch64 cross-compile check, all passing). #84 P6-N is now Done, so its Nix
tree is available — this is no longer a blocker. Remaining checklist from the PR body:
  [ ] Rebase/resume onto the accepted P6-N baseline
  [ ] Add declarative device-service integration in the P6-N-owned Nix tree
  [ ] Deploy/install on the physical Car Thing
  [ ] Remove `bridge=0` from the accepted kiosk URL after input acceptance
  [ ] Validate physical wheel, press, preset, hold, back, and reconnect behavior
  [ ] Run final required `ci` on the completed integration
  [ ] Sync P8 Done status, issue closeout, board mirror, platform spec — only after all
      acceptance criteria pass

Constraints: do not edit host/, device-ui screens, or other lanes.
```

### Agent B — W4 #87 (weather live acceptance)

```text
ISOLATION (mandatory — do this FIRST):
cd /run/host/home/rory/repos/paper-weight/.worktrees/w4-weather-live
  git rev-parse --show-toplevel    → must print this worktree's path
  git symbolic-ref --short HEAD    → must print lane/weather-w4-live-acceptance
Re-verify both before every commit and push.

Card: W4 #87. PR #95 (draft, CI green, CONFLICTING against master — rebase needed).
Read ONLY: PR #95 diff/description, features/weather/spec.md (W4 section), parallel-lanes-v1.md.

Status: mocked coverage done (38/38 tests), incl. a real bug fix in Service.refresh_now/1.

Step 1: rebase onto current master, resolve conflicts, re-run
  mix test test/paper_weight/weather — confirm still green.

Step 2: check whether #85 P7 has reached Done.
  - Still open: stop after the rebase/push. Comment on PR #95 noting rebase-only status and
    the P7 block. Do not change issue status or attempt live wiring/credentials.
  - Done: resume the blocked-remainder checklist — rebase onto P7's env/runtime contract,
    live activation wiring, out-of-band NWS/OpenUV credentials (never commit them), physical
    acceptance (current conditions, 5/7-day, UV/walk verdict), network-loss/reconnect
    acceptance, required `ci` green, then Done closeout (issue close, board + spec sync).

Constraints: do not touch application.ex, mix.exs, other lanes, or device-ui beyond W2's scope.
```

### Agent C — N4 #89 (spotify live acceptance)

```text
ISOLATION (mandatory — do this FIRST):
cd /run/host/home/rory/repos/paper-weight/.worktrees/n4-spotify-live
  git rev-parse --show-toplevel    → must print this worktree's path
  git symbolic-ref --short HEAD    → must print lane/spotify-n4-live-acceptance
Re-verify both before every commit and push.

Card: N4 #89. PR #96 (draft, CI green, CONFLICTING against master — rebase needed).
Read ONLY: PR #96 diff/description, features/now-playing/spec.md (N4 section), parallel-lanes-v1.md.

Status: mocked coverage done (56 spotify tests, up from 44) — token refresh, malformed/partial
responses, stale→fresh recovery. No behavior changes to spotify/** yet.

Step 1: rebase onto current master, resolve conflicts, re-run
  mix test test/paper_weight/spotify — confirm still green.

Step 2: check whether #85 P7 has reached Done.
  - Still open: stop after rebase/push. Comment on PR #96 noting rebase-only status and the
    P7 block. Do not change issue status.
  - Done: resume the blocked-remainder checklist — rebase onto P7's env/runtime contract,
    live activation wiring, out-of-band Spotify credentials (never commit them), physical
    Now Playing / playlist selection / wheel-volume acceptance on the Car Thing, physical
    failure/reconnect acceptance, required `ci` green, then Done closeout (Project Status
    Done, issue close, board + spec sync).

Constraints: NO play/pause anywhere (still flagged off). Don't touch application.ex,
mix.exs, other lanes, or shell/.
```

### Agent D — P6-I #82 (physical integration closeout)

```text
Card complete. #82 is Done/closed and PR #102 contains the accepted runbook/evidence.
Do not resume implementation or reopen the card. Unattended eventual-host service startup,
post-boot health, and simultaneous host/Car Thing cold boot remain P9 #90 acceptance.
```

### Agent E — P7 #85 (live-runtime contract)

```text
ISOLATION (mandatory — do this FIRST, before any other git command):
The worktree already exists. Run:
  cd /run/host/home/rory/repos/paper-weight/.worktrees/p7-live-runtime-contract
Before every commit and push, re-verify:
  git rev-parse --show-toplevel    → must be this worktree's path
  git symbolic-ref --short HEAD    → must be chore/p7-live-runtime-contract

Card: P7 #85 — Live-runtime contract. No branch/PR yet.
Read ONLY:
- gh issue view 85 --repo rorybot/paper-weight (full card text)
- features/platform/spec.md — P7 section only
- docs/architecture/parallel-lanes-v1.md (ownership section)

#82 P6-I is Done and #85 is Ready. Confirm both once, set #85 In progress when real
implementation resumes, and proceed with the scope below.

Goal (once unblocked): one documented runtime activation contract for switching the host
from fixtures to live Weather, Feed, and Spotify services.

Scope:
  [ ] One EnvironmentFile contract + example with non-secret variable names
  [ ] Wire shared environment/config activation only
  [ ] Document startup validation and per-lane enable/disable behavior
  [ ] Keep Weather/OpenUV and Spotify credentials out-of-band and untracked

Constraints: do not implement or repair lane clients in this card. Keep frozen host-device
envelopes unchanged. Etymology stays local fixture-backed; Photo is outside this milestone.
Do not commit credentials or secret-bearing EnvironmentFile contents. Suggested branch
(already used above): chore/p7-live-runtime-contract.

Acceptance: one documented EnvironmentFile contract activates live Weather, Feed, and
Spotify; missing/invalid required variables fail clearly without exposing secrets; each
live lane can be enabled/disabled through the shared contract; zero-secret automated config
tests pass; required `ci` green. This unblocks W4 #87 and N4 #89 (Agents B and C above).
```
