# Agent G handoff — P8 #86

Work exactly one card: [P8 #86 — Device input-bridge deployment](https://github.com/rorybot/paper-weight/issues/86).

## Mission and concurrency

Complete as much genuinely useful, dependency-free P8 Rust/aarch64 work as possible. Commit it,
push an isolated branch, and open a draft PR for resumption after P6-I/P6-N.

Agent C concurrently owns the declarative NixOS kiosk. Never edit or preempt its Nix tree. Agent B
owns the host service; W4/F3/N4 agents own their lanes. P8 remains blocked from installation and
physical acceptance by the accepted P6-N/P6-I baseline, so this is tested WIP, not a mergeable or
completed card.

```text
P6-H + P6-N -> P6-I -> P8 ─────────────┐
                         P7 -> W4/F3/N4 ├-> P9
```

## Mandatory startup

1. Read repository `AGENTS.md` and `PROJECT_INSTRUCTIONS.md`.
2. Run `scripts/check-gh-auth.sh`; do not reauthenticate if it passes.
3. Read only issue #86 and the P8/ownership slice in `features/platform/spec.md`.
4. Read the input-bridge crate's local documentation only as needed.
5. Do not read the design canvas, complete design spec, unrelated features, or PNGs.

Use branch `feat/p8-device-input-bridge` in `.worktrees/p8-input-bridge`. Inspect existing
worktrees first; create it from `origin/master` only if absent. Never work in the dirty #82 checkout.

## Ownership

For early work, own only:

- `src/input-bridge/**`;
- matching Rust tests/fixtures;
- loopback SSE and evdev reconnect logic within the bridge;
- packaging metadata that does not depend on or modify Agent C's Nix tree;
- required P8 rows/chunk in `features/platform/spec.md` and `kanban/board.md`.

Do not edit P6-N's declarative Nix/deployment files, kiosk URL, `application.ex`, device UI shell,
shared envelopes, live lanes, host service, or credentials.

## Do now

Inspect first, then complete useful independent work:

- `cargo fmt --check`, tests, and clippy;
- verify/prepare an aarch64 build without installing it on the device;
- test loopback-only SSE behavior at the existing `/v1/events` contract;
- test evdev disconnect/reconnect and bounded retry;
- test normalization remains unchanged for wheel, press, presets, hold, and back;
- fix bridge-owned defects exposed by those checks.

Use functional decomposition and immutable event transformations. Do not manufacture changes if
the independent surface already passes.

## Stop before

- editing or integrating Agent C's NixOS configuration;
- deploying/installing on `172.16.42.2`;
- changing the accepted kiosk URL or removing `bridge=0`;
- physical input acceptance;
- shared protocol, shell, or cross-lane changes;
- P8 completion or merge.

## Status, validation, and handoff

Leave #86 Backlog during inspection. Once real code/test work exists, set it In progress with
`scripts/set-card-status.sh`, then update the P8 spec/board statuses while preserving concurrent
entries. Keep the issue open.

Run the repository's Rust formatting, test, and clippy commands plus the safest available aarch64
build validation. Run `git diff --check`. Summarize logs instead of pasting them.

Append a 3–5-line P8 Next Session Context Chunk: completed work, validation, branch/draft PR,
P6-I/P6-N-blocked remainder, and resume action. Commit everything, push
`feat/p8-device-input-bridge`, and open a draft PR. Do not mark it ready or merge it.

Draft PR sections: Completed now; Validation; Blocked remainder. The blocked checklist must include
rebase after P6-I/P6-N, declarative device-service integration, deployment, removal of `bridge=0`,
physical input/reconnect acceptance, final `ci`, and Done/closeout synchronization.

Final report: branch/worktree, files changed, Rust/aarch64 results, draft PR, Project status,
blocked remainder, open-issue confirmation, and clean-worktree confirmation.

