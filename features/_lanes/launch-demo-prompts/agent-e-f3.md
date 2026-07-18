# Agent E handoff — F3 #88

Work exactly one card: [F3 #88 — Live Feed acceptance](https://github.com/rorybot/paper-weight/issues/88).

## Mission and concurrency

Complete as much genuinely useful, dependency-free F3 work as possible. Commit it, push an
isolated branch, and open a draft PR for resumption after P7.

Agents B/C concurrently own P6-H/P6-N. Other agents may own W4, N4, and P8. Never edit their
worktrees or files. F3 is still blocked from final acceptance by P7's EnvironmentFile/runtime
contract, so this is tested lane-local WIP, not a mergeable or completed card.

```text
P6-H + P6-N -> P6-I -> P7 -> W4/F3/N4 -> P9
```

## Mandatory startup

1. Read repository `AGENTS.md` and `PROJECT_INSTRUCTIONS.md`.
2. Run `scripts/check-gh-auth.sh`; do not reauthenticate if it passes.
3. Read only issue #88 and the F3/ownership/contract slice in `features/feed/spec.md`.
4. Do not read the design canvas, complete design spec, unrelated feature folders, or PNGs.

Use branch `lane/feed-f3-live-acceptance` in `.worktrees/f3-feed-live`. Inspect existing worktrees
first; create it from `origin/master` only if absent. Never work in the dirty #82 checkout.

## Ownership

You may edit only:

- `host/lib/paper_weight/feed/**`;
- `host/test/paper_weight/feed/**`;
- `src/device-ui/src/screens/feed/**` and matching Feed tests;
- Feed fixtures;
- `src/device-ui/src/protocol/feed.ts` only without changing the frozen payload shape;
- required F3 rows/chunk in `features/feed/spec.md` and `kanban/board.md`.

Do not edit `application.ex`, `mix.exs`, shared runtime config, shell/router, shared envelopes,
other lanes, Nix/deployment files, or credentials.

## Do now

Inspect first, then address real gaps such as mocked live-source success, malformed/partial
responses, source/HTTP failure, atomic snapshot replacement, stale state, recovery after a later
success, refresh generation transitions, and existing Feed-screen stale/error/interaction tests.
Keep functions small, pure where possible, and immutable. Do not manufacture changes if safe
coverage is already complete.

## Stop before

- P7 EnvironmentFile/shared activation;
- credentials or secret-bearing source configuration;
- live-source and physical-device acceptance;
- shared protocol or cross-lane changes;
- F3 completion or merge.

## Status, validation, and handoff

Leave #88 Backlog during inspection. Once real code/test work exists, set it In progress with
`scripts/set-card-status.sh`, then update the F3 spec/board statuses while preserving concurrent
entries. Keep the issue open.

Run focused Feed host tests. If device Feed code changes, run its tests and
`npm --prefix src/device-ui run check`. Always run `git diff --check`.

Append a 3–5-line F3 Next Session Context Chunk: completed work, validation, branch/draft PR,
P7-blocked remainder, and resume action. Commit everything, push
`lane/feed-f3-live-acceptance`, and open a draft PR. Do not mark it ready or merge it.

Draft PR sections: Completed now; Validation; Blocked remainder. The blocked checklist must include
rebase after P7, P7 contract integration, out-of-band source configuration, live physical
acceptance, failure/reconnect acceptance, final `ci`, and Done/closeout synchronization.

Final report: branch/worktree, files changed, tests, draft PR, Project status, blocked remainder,
open-issue confirmation, and clean-worktree confirmation.

