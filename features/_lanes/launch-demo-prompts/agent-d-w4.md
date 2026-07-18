# Agent D handoff — W4 #87

Work exactly one card: [W4 #87 — Live Weather acceptance](https://github.com/rorybot/paper-weight/issues/87).

## Mission and concurrency

Complete as much genuinely useful, dependency-free W4 work as possible. Commit it, push an
isolated branch, and open a draft PR for resumption after P7.

Agents B/C concurrently own P6-H/P6-N. Other agents may own F3, N4, and P8. Never edit their
worktrees or files. W4 is still blocked from final acceptance by P7's EnvironmentFile/runtime
contract, so this is tested lane-local WIP, not a mergeable or completed card.

```text
P6-H + P6-N -> P6-I -> P7 -> W4/F3/N4 -> P9
```

## Mandatory startup

1. Read repository `AGENTS.md` and `PROJECT_INSTRUCTIONS.md`.
2. Run `scripts/check-gh-auth.sh`; do not reauthenticate if it passes.
3. Read only issue #87 and the W4/ownership/contract slice in `features/weather/spec.md`.
4. Do not read the design canvas, complete design spec, unrelated feature folders, or PNGs.

Use branch `lane/weather-w4-live-acceptance` in `.worktrees/w4-weather-live`. Inspect existing
worktrees first; create it from `origin/master` only if absent. Never work in the dirty #82 checkout.

## Ownership

You may edit only:

- `host/lib/paper_weight/weather/**`;
- `host/test/paper_weight/weather/**`;
- `src/device-ui/src/screens/weather/**` and matching Weather tests;
- Weather fixtures;
- `src/device-ui/src/protocol/weather.ts` only without changing the frozen payload shape;
- required W4 rows/chunk in `features/weather/spec.md` and `kanban/board.md`.

Do not edit `application.ex`, `mix.exs`, shared runtime config, shell/router, shared envelopes,
other lanes, Nix/deployment files, or credentials.

## Do now

Inspect first, then address real gaps such as mocked NWS/OpenUV success, HTTP/API failure,
malformed/partial responses, stale state, atomic snapshot replacement, recovery after a later
success, generation transitions, and existing Weather-screen stale/error behavior. Keep functions
small, pure where possible, and immutable. Do not manufacture changes if safe coverage is already
complete.

## Stop before

- P7 EnvironmentFile/shared activation;
- credentials or secret-bearing files;
- live NWS/OpenUV and physical-device acceptance;
- shared protocol or cross-lane changes;
- W4 completion or merge.

## Status, validation, and handoff

Leave #87 Backlog during inspection. Once real code/test work exists, set it In progress with
`scripts/set-card-status.sh`, then update the W4 spec/board statuses while preserving concurrent
entries. Keep the issue open.

Run focused Weather tests, normally `cd host && mix test test/paper_weight/weather`. If device
Weather code changes, run its tests and `npm --prefix src/device-ui run check`. Always run
`git diff --check`.

Append a 3–5-line W4 Next Session Context Chunk: completed work, validation, branch/draft PR,
P7-blocked remainder, and resume action. Commit everything, push
`lane/weather-w4-live-acceptance`, and open a draft PR. Do not mark it ready or merge it.

Draft PR sections: Completed now; Validation; Blocked remainder. The blocked checklist must include
rebase after P7, P7 contract integration, out-of-band credentials, live physical acceptance,
failure/reconnect acceptance, final `ci`, and Done/closeout synchronization.

Final report: branch/worktree, files changed, tests, draft PR, Project status, blocked remainder,
open-issue confirmation, and clean-worktree confirmation.

