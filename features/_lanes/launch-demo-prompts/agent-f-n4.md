# Agent F handoff — N4 #89

Work exactly one card: [N4 #89 — Live Spotify acceptance](https://github.com/rorybot/paper-weight/issues/89).

## Mission and concurrency

Complete as much genuinely useful, dependency-free N4 work as possible. Commit it, push an
isolated branch, and open a draft PR for resumption after P7.

Agents B/C concurrently own P6-H/P6-N. Other agents may own W4, F3, and P8. Never edit their
worktrees or files. N4 is still blocked from final acceptance by P7's EnvironmentFile/runtime
contract, so this is tested Spotify-lane WIP, not a mergeable or completed card.

```text
P6-H + P6-N -> P6-I -> P7 -> W4/F3/N4 -> P9
```

## Mandatory startup

1. Read repository `AGENTS.md` and `PROJECT_INSTRUCTIONS.md`.
2. Run `scripts/check-gh-auth.sh`; do not reauthenticate if it passes.
3. Read only issue #89 and the N4/ownership/contract slice in `features/now-playing/spec.md`.
4. Do not read the design canvas, complete design spec, unrelated feature folders, or PNGs.

Use branch `lane/spotify-n4-live-acceptance` in `.worktrees/n4-spotify-live`. Inspect existing
worktrees first; create it from `origin/master` only if absent. Never work in the dirty #82 checkout.

## Ownership

You may edit only:

- `host/lib/paper_weight/spotify/**`;
- `host/test/paper_weight/spotify/**`;
- Spotify-owned Now Playing/playlist tests when required;
- Spotify fixtures and owned protocol files without changing frozen payload shapes;
- required N4 rows/chunk in `features/now-playing/spec.md` and `kanban/board.md`.

Do not edit `application.ex`, `mix.exs`, shared runtime config, shell/router, shared envelopes,
other lanes, Nix/deployment files, or credentials. Never add play/pause.

## Do now

Inspect first, then address real gaps such as mocked authentication, token refresh success/failure,
expired-token retry, malformed/partial responses, Spotify API failure, stale state, recovery after
a later success, generation transitions, playlist refresh, and existing failure-state rendering.
Keep functions small, pure where possible, and immutable. Do not manufacture changes if safe
coverage is already complete.

## Stop before

- P7 EnvironmentFile/shared activation;
- credentials or real-account login;
- physical Now Playing, playlist, or volume acceptance;
- shared protocol or cross-lane changes;
- N4 completion or merge.

## Status, validation, and handoff

Leave #89 Backlog during inspection. Once real code/test work exists, set it In progress with
`scripts/set-card-status.sh`, then update the N4 spec/board statuses while preserving concurrent
entries. Keep the issue open.

Run focused Spotify host tests. If device-owned Spotify UI code changes, run its tests and
`npm --prefix src/device-ui run check`. Always run `git diff --check`.

Append a 3–5-line N4 Next Session Context Chunk: completed work, validation, branch/draft PR,
P7-blocked remainder, and resume action. Commit everything, push
`lane/spotify-n4-live-acceptance`, and open a draft PR. Do not mark it ready or merge it.

Draft PR sections: Completed now; Validation; Blocked remainder. The blocked checklist must include
rebase after P7, P7 contract integration, out-of-band Spotify credentials, real-account physical
acceptance, failure/reconnect acceptance, final `ci`, and Done/closeout synchronization.

Final report: branch/worktree, files changed, tests, draft PR, Project status, blocked remainder,
open-issue confirmation, and clean-worktree confirmation.

