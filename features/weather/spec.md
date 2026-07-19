# Feature: weather

Lane owner for **W1** (service) + **W2** (screen 4b).  
Parallel rules: `docs/architecture/parallel-lanes-v1.md`.  
Protocol envelope: `docs/architecture/host-device-protocol-v1.md`.

## Cards

| ID | Issue | Title | Status |
|----|-------|-------|--------|
| W1 | [#9](https://github.com/rorybot/paper-weight/issues/9) | Weather data service — NWS + OpenUV | **Done** |
| W2 | [#10](https://github.com/rorybot/paper-weight/issues/10) | Screen 4b UI | **Done** |
| W4 | [#87](https://github.com/rorybot/paper-weight/issues/87) | Live Weather acceptance | **In progress** (P7 #85 Done; live acceptance pending) |
| W5 | [#109](https://github.com/rorybot/paper-weight/issues/109) | Migrate Weather from NWS/OpenUV to Open-Meteo | **Ready** (Priority P0) |

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
  location_label: string;       // display only; from NWS or WEATHER_LOCATION_LABEL
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
- [x] Renders fixture snapshot @ 800×480 matching mockup intent
- [x] Wheel toggles 5-day ↔ 7-day
- [x] UV band shows extreme / high / low correctly
- [x] No shell edits

## Deps request

_(lane agents append here; do not edit mix.exs)_

- ~~app: add `:inets` and `:ssl`~~ **done** — `mix.exs` adds them via `optional_http_apps/0` when OTP provides `:inets` (skipped on minimal installs). Tests still inject mocks.
- No new Hex packages required.

## Supervisor child (wave 3)

```elixir
{PaperWeight.Weather.Service, []}
```

## Next Session Context Chunk

- **Weather fully wired (W1+W2+shell/host)**: `PaperWeight.Weather.Service` under Application (disabled in test via `config :paper_weight_host, weather_service: :disabled`); `:inets`/`:ssl` in `mix.exs`.
- Device: `ShellApp` renders `WeatherScreen` with fixture snapshot; wheel → `toggle-weather-range` flips local `weatherRange` 5d↔7d (`data-weather-range` on root).
- Still later: host WebSocket push of live snapshots (replace fixture); no more weather kanban cards.
- Other lanes: F1 feed host, N2 now-playing UI, etc.

## Next Session Context Chunk — W4 (2026-07-18)

- W4 #87 is In progress (lane-local WIP only) but still blocked from acceptance/merge until P7
  #85 supplies the shared EnvironmentFile activation contract.
- Own only Weather paths; keep the frozen envelope and shared shell/Application files unchanged.
- Accept mocked failure/recovery plus live NWS/OpenUV rendering on the physical Car Thing.
- Completed this session: mocked coverage for OpenUV-specific failure, malformed/partial NWS +
  OpenUV responses, and post-failure recovery/generation transitions. Fixed a real bug caught by
  the new recovery test — `Service.refresh_now/1` mis-bound a `case` result and returned a
  malformed nested reply on a successful post-failure refresh instead of `{:ok, snap}`.
  `mix test test/paper_weight/weather` → 38/38 green; no device-UI files touched.
- Branch `lane/weather-w4-live-acceptance`; draft PR opened. Resume: rebase after P7 merges, wire
  live activation, then run physical-device acceptance (live NWS/OpenUV render, network loss +
  reconnect on-device, required `ci` green, Done/closeout sync).

## Next Session Context Chunk — W4 (2026-07-19)

- PR #95 rebased onto current `master`; Weather tests remain green at 38/38.
- P7 #85 is still open, so no live activation, credentials, or physical acceptance was attempted.
- PR remains draft and W4 #87 remains In progress; rebase-only blocker comment is posted.
- Resume only after P7 lands, using its EnvironmentFile/runtime contract for live acceptance.

## Next Session Context Chunk — W4 (2026-07-19, P7 landed)

- P7 #85 is Done; W4 rebased onto `origin/master` at `89e82f4` and the runtime contract is present.
- Validation remains green: Weather 38/38 and full host 184/184.
- This worktree has no untracked `.env`; live NWS/OpenUV activation has not started.
- Resume with out-of-band Weather env values and the physical Car Thing available.
