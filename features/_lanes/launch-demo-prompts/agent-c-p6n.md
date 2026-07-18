# Agent C handoff — P6-N #84

Work exactly one card: [P6-N #84 — Declarative NixOS kiosk](https://github.com/rorybot/paper-weight/issues/84).

## Context

P6-N and P6-H run concurrently and jointly unblock P6-I #82. Other agents may prepare W4, F3,
N4, and P8 in separate worktrees. All worktrees share one filesystem: preserve every unrelated
change and never edit another agent's worktree.

```text
P6-H + P6-N -> P6-I -> P7/P8 -> W4/F3/N4 -> P9
```

## Mandatory startup

1. Read repository `AGENTS.md` and `PROJECT_INSTRUCTIONS.md`.
2. Run `scripts/check-gh-auth.sh`; do not reauthenticate if it passes.
3. Read only issue #84 and its `features/platform/spec.md` slice.
4. Do not read design-project files, the full design spec, other feature folders, or mockup PNGs.

Use branch `feat/p6n-declarative-nixos-kiosk` in `.worktrees/p6n-nixos-kiosk`. Inspect
`git worktree list` first. Create the worktree from `origin/master` only if it does not exist.
Never work in or clean the original dirty #82 checkout.

## Goal and ownership

Create the minimal repo-owned declarative NixOS kiosk/deployment path:

- pin `nixos-superbird` revision `0d2b239683907c19583c51134c6795ded087437d`;
- set `superbird.gui.kiosk_url` to
  `http://172.16.42.1:8080/?bridge=0&gateway=ws://172.16.42.1:9138/`;
- evaluate/build through the privileged upstream builder;
- deploy to `root@172.16.42.2`;
- preserve and demonstrate the prior generation as rollback;
- document status, generation selection, deployment, reboot, and rollback.

Inside Distrobox use `/run/host/usr/bin/podman`; outside it use `podman`. Do not look for or
install nested Docker.

## Boundaries

- Do not use or extend `scripts/device-kiosk.sh`, `/etc/kiosk_url` replacement, a systemd override,
  or the untracked `device/` override implementation in the original checkout.
- Remove invalid override code only if it exists on this branch and the declarative replacement is
  present; never delete unrelated user WIP.
- Do not edit the host launcher/service, live lanes, `application.ex`, shell, or frozen envelopes.
- Preserve the current generation until rollback has been demonstrated.

## Workflow and acceptance

Move #84 to In progress only when real work begins. Keep GitHub, `kanban/board.md`, and the
platform card table synchronized, preserving concurrent entries.

Complete every issue acceptance item:

- Nix evaluation and host-Podman build;
- deployment to `172.16.42.2`;
- physical reboot into the production fullscreen kiosk;
- previous-generation rollback and return to the new generation;
- required `ci`.

Append a 3–5-line P6-N Next Session Context Chunk. Commit all intended work, push the branch, open
a PR, wait for required `ci`, merge, set Project status Done, close #84, and synchronize both
mirrors. Never commit directly to master or leave uncommitted card work.

Final report: branch/worktree, files changed, build/deployment/rollback evidence, PR/merge URL,
issue/project state, and clean-worktree confirmation.

