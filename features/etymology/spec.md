# Feature: etymology

Lane owner for **E1** (word-origin data service) + **E2** (drill-down screen 2a→2b→2c).
Parallel rules: `docs/architecture/parallel-lanes-v1.md`.
Protocol envelope: `docs/architecture/host-device-protocol-v1.md`.

E1 is a **standalone, unwired** host service: no `application.ex` edit, no protocol channel yet.
`etymology` stays an ignored/omitted channel until a future wire-up card.

## Cards

| ID | Issue | Title | Status |
|----|-------|-------|--------|
| E1 | [#16](https://github.com/rorybot/paper-weight/issues/16) | Word-origin data service | **Done** (PR #60 merged; CI green) |
| E2 | [#17](https://github.com/rorybot/paper-weight/issues/17) | Drill-down screen (one state machine, 3 depths) | **Done** (PR #66 merged; CI green) |
| E2-1 | [#79](https://github.com/rorybot/paper-weight/issues/79) | Wire preset 4 to Etymology screen | **Done** (PR #80 merged; CI green) |

## Ownership (only these paths)

| Area | Path |
|------|------|
| Host service | `host/lib/paper_weight/etymology/**` |
| Host tests | `host/test/paper_weight/etymology/**` |
| Payload types | `src/device-ui/src/protocol/etymology.ts` |
| Feature spec | `features/etymology/spec.md` |

**Do not touch:** `application.ex`, `mix.exs`, `protocol/**` (envelope), shell, design tokens,
other lanes. **Do not** add `etymology` to the `ChannelV1` / channel union.

## Channel

`channel: "etymology"` — **reserved, not wired.** The envelope already lists it as an
ignored/omitted channel. Wiring is a future protocol card; E1 only freezes the payload shape.

## Domain model (recursive trace)

A word's history is a spine of **origin nodes**, newest → oldest, linked by `from`:

```
travel (now, modern english)
  └from→ travailen (c.1375, middle english)
           └from→ travailler (c.1200, old french)   ← splits_into: travel(en), travail(en/fr)
                    └from→ trepālium (c.400, late latin)   ← terminal root; from = nil
                             components: trēs("three") + pālus("stake")
```

- `from == nil` ⇒ **terminal root** (`root?/1` true) — bedrock, no earlier attested form.
- `depth` = number of `from` hops to the root. The `travel` spine is **depth 3**.
- `splits_into` — later words that branched off a stage (mockup 2b "SPLITS INTO").
- `components` — morphological pieces of a compound root (mockup 2c `trēs + pālus`).
- Mockup 2a's flat ladder = `Origin.ladder(trace)` (4 nodes for `travel`); the UI may render the
  root's `components` as one extra bottom row (the `trēs + pālus` line).

## Payload contract (E1 freezes this)

TS types: `src/device-ui/src/protocol/etymology.ts`. Host builds the string-keyed map in
`PaperWeight.Etymology.Snapshot`. **Payload types only** — no channel-union change.

```ts
type EtymologyBranchV1     = { form: string; note: string | null };          // "en", "en/fr"
type EtymologyComponentV1  = { form: string; gloss: string };                // trēs / "three"

type EtymologyOriginV1 = {
  form: string;
  language: string;
  period: string | null;        // "now", "c.1200", "latin"
  gloss: string;
  notes: string | null;         // longer prose for the drill-down view
  splits_into: EtymologyBranchV1[];
  components: EtymologyComponentV1[];
  root: boolean;                // true when terminal (from === null)
  from: EtymologyOriginV1 | null;  // recursive parent; null at root
};

type EtymologyWordV1 = {
  headword: string;             // "travel"
  language: string;             // "modern english"
  part_of_speech: string;       // "verb"
  gloss: string;                // "to make a journey"
  summary: string;              // "its root means torture…"
  cousins: string[];            // ["travail", "travolator"]
};

type EtymologySnapshotV1 = {
  as_of: string;                // ISO-8601 day, "2026-07-15"
  date_label: string;           // "wed jul 15"
  stale: boolean;
  source: string;               // "etymonline snapshot"
  word: EtymologyWordV1;
  depth: number;                // Origin.depth(trace)
  trace: EtymologyOriginV1;     // recursive spine; walk `from` to the root
};
```

`trace.form` == `word.headword`; `word` holds depth-0 display metadata (left pane of 2a), `trace`
holds the recursive ladder (right pane + drill-down). Small, intentional overlap so each view's
data is local.

## Host API (E1)

| Module | Role |
|--------|------|
| `Etymology.Origin` | pure recursive node: `new/1`, `depth/1`, `root/1`, `root?/1`, `ladder/1` |
| `Etymology.Entry` | day's-word entry struct (metadata + `trace` + `source`) |
| `Etymology.Corpus` | curated "Wiktionary-style" source; `entries/0`, `travel/0`, … |
| `Etymology.Selection` | pure deterministic daily pick: `pick/2`, `index_for/2` |
| `Etymology.Snapshot` | pure assembly → `EtymologySnapshotV1` string-keyed map; `mark_stale/1` |
| `Etymology.Service` | GenServer: build once per day, cache, rebuild on day-roll |

- **Source** is a hand-curated in-memory corpus (no live HTTP yet) — the slot a real
  Wiktionary/etymonline fetch drops into later. No new deps.
- **Daily selection** = Gregorian-day-number mod corpus size: stable per date, rotates daily.
- **Cache**: `Service` holds the day's snapshot + `gen`; `day_tree/1` serves cache and rebuilds
  only when `today_fn.()` advances past the cached date. `:entries` + `:today_fn` are injectable
  for tests.
- **Stale path**: selection/assembly is pure over in-memory data, so failure is not expected; if
  `build` ever raises, `Service` keeps the last-good tree and flags `stale: true` rather than crash.

## Supervisor child (wave 3 — do not register yourself)

```elixir
{PaperWeight.Etymology.Service, []}
```

Standalone until a future card wires the `etymology` channel into the envelope + gateway.

## Deps request

_(none — pure in-memory corpus; no `mix.exs` edit)_

## Acceptance

### E1
- [x] `travailler`-style fixture (`Corpus.travel/0`) yields a ≥3-depth tree with a terminal root
  (`corpus_test.exs`)
- [x] Recursive core pure-tested: depth / root / ladder (`origin_test.exs`)
- [x] Deterministic daily selection tested (`selection_test.exs`)
- [x] Snapshot matches `EtymologySnapshotV1`; nested `trace` + `mark_stale` (`snapshot_test.exs`)
- [x] Service caches the day's tree, rebuilds on day-roll (`service_test.exs`)
- [x] No `application.ex` / `mix.exs` / protocol / channel-union edits
- [x] `mix test` green — verified by CI (`ci` check, 121 tests) on merged PR #60

### E2 (later, gated on E1)
- [x] 2a/2b/2c as ONE screen driven by wheel (move) + press (dig) + back (up)
- [x] Uses `EtymologySnapshotV1` payload type; matches the three mockups

## Next Session Context Chunk (E2)

- **E2 built** on `feat/e2-etymology-drilldown` (PR #66): ONE state machine in
  `src/device-ui/src/screens/etymology/model.ts` — `{cursor, path}` over `ladderOf(trace)`;
  view mode `ladder`/`stage`/`root` derives from focus; wheel clamps, press digs, back pops
  (no-op at depth 0). 25 tests, `npm run check` green.
- **Seam for W3-D**: import from `screens/etymology/index.ts` (`EtymologyScreen`,
  `etymologyFixtureSnapshot`, `reduceEtymologyUi` + commands
  `scroll-etymology`/`dig-etymology`/`back-etymology`, or controlled `ui` prop). Shell owns
  back-at-depth-0 → home. Channel still NOT in `ChannelV1`; fixture-only until wired.
- **Shared-worktree hazard**: Day-2 agents share one checkout — W3-C's `git switch` moved HEAD
  mid-session and my commit briefly landed on their branch (repaired via ref moves + reset).

## Next Session Context Chunk (E1)

- **E1 built & pushed** on `claude/e1-word-origin-service-3fsz8x` (card asked for
  `feat/e1-word-origin-service`; harness pinned this branch instead). Six modules under
  `host/lib/paper_weight/etymology/`, five test files, `src/device-ui/src/protocol/etymology.ts`.
- **Payload frozen** as `EtymologySnapshotV1` (above): recursive `trace` of `EtymologyOriginV1`
  nodes (`from` = parent, null at root), `splits_into` + `components`, plus `word` metadata block.
- **Still standalone**: `Service` is NOT in `application.ex`; `etymology` NOT in `ChannelV1`.
  Wave-3 child spec `{PaperWeight.Etymology.Service, []}` recorded above.
- **E2 unblocked**: import types from `protocol/etymology.ts`; render `trace` ladder + drill-down.
- **Ops note**: no `gh`/Elixir in this env — remote Projects Status not set from here; `mix test`
  relies on CI. Corpus currently ships `travel` / `salary` / `clue`.

## Next Session Context Chunk (E2-1)

- **PR #80 merged / issue #79 closed**: preset 4 renders `EtymologyScreen`; Project status is Done.
- **Root cause**: `ShellApp` omitted the implemented E2 component and fell through to a placeholder.
- **Validation**: `npm run check` green — 32 files / 201 tests plus production build.
- **Device evidence**: 800×480 physical capture shows `data-screen="etymology"`, no placeholder.
- **Boundary**: Etymology remains fixture-backed; live host channel and persistent kiosk are separate cards.
