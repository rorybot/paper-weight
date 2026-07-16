# Feature: feed

Lane owner for **F1** (service) + **F2** (screen 4f).  
Parallel rules: `docs/architecture/parallel-lanes-v1.md`.  
Protocol envelope: `docs/architecture/host-device-protocol-v1.md`.

## Cards

| ID | Issue | Title | Status |
|----|-------|-------|--------|
| F1 | [#12](https://github.com/rorybot/paper-weight/issues/12) | X/Twitter snapshot service | **Ready** (lane wave 1) |
| F2 | [#13](https://github.com/rorybot/paper-weight/issues/13) | Screen 4f UI | Backlog (wave 2) |

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
- [ ] Fixture snapshot ≥3 posts
- [ ] Accent assignment stable for same handle set
- [ ] Atomic refresh tested (gen / full replace)
- [ ] Stale path
- [ ] No Application / mix.exs edits

### F2
- [ ] Matches feed-4f intent; ≥3 posts visible layout
- [ ] Wheel scroll + press enlarge + back collapse
- [ ] Big type readable @ 800×480
- [ ] No shell edits

## Deps request

_(lane agents append here)_

## Next Session Context Chunk

- Parallel lane ready: own only `host/lib/paper_weight/feed/` + tests + protocol feed types.
- Reuse BERG Card; leave `sample/FeedSample` as P4 acceptance artifact.
