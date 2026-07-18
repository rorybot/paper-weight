# Agent B handoff — P6-H #83

Work exactly one card: [P6-H #83 — Host production service](https://github.com/rorybot/paper-weight/issues/83).

## Context

P6-H and P6-N run concurrently and jointly unblock P6-I #82. Other agents may prepare W4, F3,
N4, and P8 in separate worktrees. All worktrees share one filesystem: preserve every unrelated
change and never edit another agent's worktree.

```text
P6-H + P6-N -> P6-I -> P7/P8 -> W4/F3/N4 -> P9
```

## Mandatory startup

1. Read repository `AGENTS.md` and `PROJECT_INSTRUCTIONS.md`.
2. Run `scripts/check-gh-auth.sh`; do not reauthenticate if it passes.
3. Read only issue #83 and its `features/platform/spec.md` slice.
4. Do not read design-project files, the full design spec, other feature folders, or mockup PNGs.

Use branch `feat/p6h-host-production-service` in `.worktrees/p6h-host-service`. Inspect
`git worktree list` first. Create the worktree from `origin/master` only if it does not exist.
Never work in or clean the original dirty #82 checkout.

## Goal and ownership

Own the production host runtime:

- salvage and harden the existing untracked
  `/run/host/home/rory/repos/paper-weight/scripts/run-device-fixture.sh`;
- serve the production UI at `172.16.42.1:8080`;
- serve the fixture gateway at `172.16.42.1:9138`;
- install/document a resilient host user service;
- handle USB unplug/replug without manual repair;
- provide explicit HTTP and WebSocket health checks;
- recover after host reboot.

Copy/salvage the launcher into this worktree without modifying the source #82 checkout.

## Boundaries

- Do not edit device Nix configuration, live lane services, `application.ex`, shell, frozen
  envelopes, or #82 cold-boot evidence.
- Keep fixture behavior; P7 owns live activation and EnvironmentFile configuration.
- The kiosk URL contract remains
  `http://172.16.42.1:8080/?bridge=0&gateway=ws://172.16.42.1:9138/`.
- Inspect existing processes on ports 8080/9138 before testing. Replace or stop the temporary demo
  deliberately; do not blindly kill unrelated processes.
- Functional style: small pure helpers, composition, immutable configuration.

## Workflow and acceptance

Move #83 to In progress only when real work begins. Keep GitHub, `kanban/board.md`, and the
platform card table synchronized, preserving concurrent entries.

Complete every issue acceptance item:

- production build/check;
- service start, stop, status, and restart;
- both health checks;
- USB unplug/replug recovery;
- host reboot recovery;
- required `ci`.

Append a 3–5-line P6-H Next Session Context Chunk. Commit all intended work, push the branch, open
a PR, wait for required `ci`, merge, set Project status Done, close #83, and synchronize both
mirrors. Never commit directly to master or leave uncommitted card work.

Final report: branch/worktree, files changed, test and physical results, PR/merge URL, issue/project
state, and clean-worktree confirmation.

