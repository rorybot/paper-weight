# Feature: weather

Lane owner for **W1** (service) + **W2** (screen 4b).  
Parallel rules: `docs/architecture/parallel-lanes-v1.md`.  
Protocol envelope: `docs/architecture/host-device-protocol-v1.md`.

## Cards

| ID | Issue | Title | Status |
|----|-------|-------|--------|
| W1 | [#9](https://github.com/rorybot/paper-weight/issues/9) | Weather data service — NWS + OpenUV | **Done** |
| W2 | [#10](https://github.com/rorybot/paper-weight/issues/10) | Screen 4b UI | Backlog (wave 2) |

## Ownership (only these paths)

| Area | Path |
|------|------|
| Host service | `host/lib/paper_weight/weather/**` |
| Host tests | `host/test/paper_weight/weather/**` |
| Device screen | `src/device-ui/src/screens/weather/**` |
| Payload types | `src/device-ui/src/protocol/weather.ts` |
| Fixtures | under own test dirs |

**Do not touch:** `application.ex`, `mix.exs`, shell, design tokens, other lanes.

## Channel

`channel: "weather"`

## Payload contract (W1 freezes this)

```ts
/** Host → device payload for channel "weather" */
type WeatherSnapshotV1 = {
  location_label: string;       // e.g. "Castle Rock, CO"
  as_of: string;                // ISO-8601
  stale: boolean;
  current: {
    temp_f: number;
    summary: string;            // short conditions text
  };
  /** plain-spoken italic walk line for topbar/quote */
  walk_verdict: string;
  uv: {
    /** 0–11+ style index for "now" or peak window used by UI */
    index: number;
    /** UI band: solid / hatch / faint */
    grade: "extreme" | "high" | "low";
  };
  /** next 5 calendar days for main pane */
  days5: WeatherDayV1[];
  /** 7-day when wheel toggles range — may equal days5 padded */
  days7: WeatherDayV1[];
  hourly_uv: { hour_local: string; index: number }[];
};

type WeatherDayV1 = {
  date: string;                 // YYYY-MM-DD
  high_f: number;
  low_f: number;
  summary: string;
};
```

### UV grade rules (UI + service agree)

| Grade | Rule (v1) |
|-------|-----------|
| `extreme` | index ≥ 8 |
| `high` | 6 ≤ index < 8 |
| `low` | index < 6 |

### Walk verdict (W1)

Pure function of temp / UV / precip windows → one plain-spoken sentence. Fixture-tested phrasing rules in host tests.

## Host API (W1)

| Function | Role |
|----------|------|
| `fetch_snapshot(config) → {:ok, snapshot} \| {:error, reason}` | impure edge |
| `grade_uv(index) → grade` | pure |
| `walk_verdict(inputs) → String.t()` | pure |
| Periodic refresh GenServer | cache last good; set `stale: true` on failure |

### Supervisor child (wave 3 — do not register yourself)

```elixir
{PaperWeight.Weather.Service, []}
```

## Screen (W2) — local only

- Shell already emits `toggle-weather-range` on wheel; screen reduces `range: "5d" | "7d"`.
- Mockup: `spec/weather-4b.png` only.
- Theme: gruvbox/TUI chrome OK until D3.

## Acceptance

### W1
- [x] Fixture tests for NWS/OpenUV adapters (mocked HTTP)
- [x] UV grade + walk_verdict pure tests
- [x] Snapshot matches `WeatherSnapshotV1`
- [x] Stale path when upstream fails
- [x] No Application / mix.exs edits

### W2
- [ ] Renders fixture snapshot @ 800×480 matching mockup intent
- [ ] Wheel toggles 5-day ↔ 7-day
- [ ] UV band shows extreme / high / low correctly
- [ ] No shell edits

## Deps request

_(lane agents append here; do not edit mix.exs)_

- app: add `:inets` and `:ssl` to `extra_applications` in `host/mix.exs` (reason: live NWS/OpenUV via `:httpc`; tests inject mocks and do not need them)
- No new Hex packages required.

## Supervisor child (wave 3)

```elixir
{PaperWeight.Weather.Service, []}
```

## Next Session Context Chunk

- W1 **Done**: host under `PaperWeight.Weather.*` — pure grade/verdict/snapshot/nws/open_uv; impure `Fetch` + `Service` GenServer; facade `PaperWeight.Weather`.
- Snapshot string-key map matches `src/device-ui/src/protocol/weather.ts`; fixtures in `host/test/paper_weight/weather/fixtures/`.
- Stale path: last good + `"stale" => true`; gen bumps only on success. Wave 3: register `{PaperWeight.Weather.Service, []}` + enable `:inets`/`:ssl`.
- W2 next: screen from fixture snapshot only; shell already emits `toggle-weather-range`.
