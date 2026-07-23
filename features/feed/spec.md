# Feature: feed

Lane owner for **F1** (service) + **F2** (screen 4f).  
Parallel rules: `docs/architecture/parallel-lanes-v1.md`.  
Protocol envelope: `docs/architecture/host-device-protocol-v1.md`.

## Cards

| ID | Issue | Title | Status |
|----|-------|-------|--------|
| F1 | [#12](https://github.com/rorybot/paper-weight/issues/12) | X/Twitter snapshot service | **Done** |
| F2 | [#13](https://github.com/rorybot/paper-weight/issues/13) | Screen 4f UI | **Done** |
| F3 | [#88](https://github.com/rorybot/paper-weight/issues/88) | Live Feed acceptance | **Backlog** (blocked by P7) |

## Ownership (only these paths)

| Area | Path |
|------|------|
| Host service | `host/lib/paper_weight/feed/**` |
| Host tests | `host/test/paper_weight/feed/**` |
| Device screen | `src/device-ui/src/screens/feed/**` |
| Payload types | `src/device-ui/src/protocol/feed.ts` |
| Fixtures | under own test dirs |

**Do not touch:** `application.ex`, `mix.exs`, shell, design tokens, other lanes.  
**Do not** extend P4 `FeedSample` in place for production — F2 owns `screens/feed/`; sample stays a P4 fixture.

## Channel

`channel: "feed"`

## Payload contract (F1 freezes this)

```ts
type FeedSnapshotV1 = {
  as_of: string;                // ISO-8601
  stale: boolean;
  /** atomic list; device replaces entire array on gen bump */
  posts: FeedPostV1[];
};

type FeedPostV1 = {
  id: string;
  handle: string;               // "@name"
  body: string;                 // plain text, already stripped
  time_label: string;           // "3m" / "1h" display string from host
  /** CSS color or token name assigned per handle */
  accent: string;
};
```

## Host API (F1)

| Function | Role |
|----------|------|
| `fetch_snapshot(config) → {:ok, snapshot} \| {:error, _}` | impure; read-only API |
| `assign_accents(handles) → %{handle => accent}` | pure / deterministic |
| `strip_post(raw) → FeedPostV1 fields` | pure |
| Periodic refresh | snapshot semantics — no mid-view streaming |

### Constraints
- Read-only; no post/like/reply.
- Refresh swaps snapshot **atomically** (new `gen` + full `posts` array).

### Supervisor child (wave 3)

```elixir
{PaperWeight.Feed.Service, []}
```

## Screen (F2) — local only

- Shell: wheel → `scroll-feed`; press → `feed-detail` overlay; back dismisses overlay.
- Mockup: `spec/feed-4f.png` only.
- **Rejected:** "Grus Gazette" newspaper concept.
- BERG: dark desk + cream selected card (P4 `Card`).

## Acceptance

### F1
- [x] Fixture snapshot ≥3 posts
- [x] Accent assignment stable for same handle set
- [x] Atomic refresh tested (gen / full replace)
- [x] Stale path
- [x] No Application / mix.exs edits

### F2
- [x] Matches feed-4f intent; ≥3 posts visible layout
- [x] Wheel scroll + press enlarge + back collapse
- [x] Big type readable @ 800×480
- [x] No shell edits

## Deps request

_(lane agents append here)_

## FS1 Verdict — Feed lane dropped (2026-07-22)

**Decision: drop the Feed screen. Preset 3 now points at Photo (already built) instead.**

Researched during the spike (#127):
- Official X API: no free read tier since Feb 2026 — pay-per-read ($0.005/post, 2M/mo cap).
  Confirmed too expensive for a hobby device.
- Unofficial mechanisms exist but neither fits well:
  - **Public syndication widget** (`cdn.syndication.twimg.com/srv/timeline-profile/screen-name/{handle}`):
    no personal login needed, proven live (200 OK) during the spike, but only returns one
    account's own public posts — not a real personal timeline, and shares a strict 30 req/window
    rate limit per IP that a shared network can exhaust on its own.
  - **Authenticated session scrape** (X is now a pure GraphQL SPA, no server-rendered HTML
    fallback): would need Rory's own `auth_token`/`ct0` browser cookies replayed against X's
    internal GraphQL endpoints (what tools like `twscrape` do) to get an actual personal home
    timeline. Technically workable and Rory was fine with it — reads for himself, own account,
    read-only. Cookies reportedly need refreshing every few weeks; breaks whenever X rotates
    internal query IDs.
- Bigger issue was product-level, not technical: the value of a scraped feed didn't justify the
  fragility/maintenance either way. Rory chose to cut the screen rather than accept either
  compromise.

**Outcome:**
- Preset 3 repointed from `feed` → `photo` in `src/device-ui/src/shell/model.ts`.
- Feed host service (`host/lib/paper_weight/feed/**`) and device screen
  (`src/device-ui/src/screens/feed/**`, `src/device-ui/src/protocol/feed.ts`) deleted.
- Design doc (`docs/design/carthing-context.md`) updated: five locked screens, Feed section
  removed, Photo noted as owning preset 3.
- Follow-ups F3 (#88), F3a (#136), F4a (#137), F4b (#138) closed as moot — all were live-feed
  refinements on top of a mechanism that's no longer being built.
- New card: rewire shell routing/screens to drop `feed`, confirm Photo renders correctly on
  preset 3 (`src/device-ui/src/shell/**`).

## Next Session Context Chunk

- Feed lane is **closed** — do not resume F1/F2 work here. See "FS1 Verdict" above for why.
- Cleanup card **#161** (`chore/drop-feed-lane-161`): host `mix test` 226 green; device-ui
  `npm run check` 198 green. Remaining acceptance: **preset 3 → Photo on-device**, then merge.
- If a future card wants a "what's happening" screen again, treat it as new scope: re-evaluate
  data sources from scratch rather than reviving this deleted code from git history blindly —
  the syndication/session-scrape tradeoffs above still apply.
