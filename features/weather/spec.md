# Feature: weather

Lane owner for **W1** (service) + **W2** (screen 4b).  
Parallel rules: `docs/architecture/parallel-lanes-v1.md`.  
Protocol envelope: `docs/architecture/host-device-protocol-v1.md`.

## Cards

| ID | Issue | Title | Status |
|----|-------|-------|--------|
| W1 | [#9](https://github.com/rorybot/paper-weight/issues/9) | Weather data service — NWS + OpenUV | **Done** |
| W2 | [#10](https://github.com/rorybot/paper-weight/issues/10) | Screen 4b UI | **Done** |
| W4 | [#87](https://github.com/rorybot/paper-weight/issues/87) | Live Weather acceptance | **Done** |
| W4-1 | [#114](https://github.com/rorybot/paper-weight/issues/114) | Wheel does not toggle 5-day/7-day on physical device | **Backlog** |
| W4-2 | [#115](https://github.com/rorybot/paper-weight/issues/115) | Verify stale/recovery on real physical-device network outage | **Backlog** |
| W5 | [#109](https://github.com/rorybot/paper-weight/issues/109) | Migrate Weather from NWS/OpenUV to Open-Meteo | ✅ Done |

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
  location_label: string;       // display only; from WEATHER_LOCATION_LABEL (Open-Meteo has no place name)
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
  /** half-hourly scrub timeline, −12h…+24h (W6a) — FROZEN, see below */
  timeline: WeatherTimelineV1;
};

type WeatherDayV1 = {
  date: string;                 // YYYY-MM-DD
  high_f: number;
  low_f: number;
  summary: string;
};
```

### Timeline envelope (W6a — FROZEN, device W6b builds against this)

Half-hourly temperature / wind / precipitation across −12h…+24h for the wheel-scrub
graph (W6c). Series is oldest → newest at a fixed 30-minute step; `now_index` points at
the sample aligned to the current observation time. The shape is deliberately
**fetch-mechanism-agnostic** — host currently derives it from Open-Meteo `minutely_15`
(sampled at 15-min, downsampled to the 30-min grid), but the envelope does not encode that.

```ts
type WeatherTimelineV1 = {
  step_minutes: 30;             // fixed 30-min grid
  now_index: number;            // index into `series` nearest "now"; 0 if unknown
  series: WeatherTimelinePointV1[];  // oldest → newest, 30-min spacing
};

type WeatherTimelinePointV1 = {
  time_local: string;           // "YYYY-MM-DDTHH:MM", Open-Meteo local time (no offset)
  temp_f: number | null;        // temperature, °F
  wind_mph: number | null;      // wind speed, mph
  precip_in: number | null;     // precipitation, inches
};
```

Notes for W6b:
- Full window = **73 points**, `now_index == 24` (12h back × 2). Partial upstream data
  yields a shorter series and a smaller `now_index` — never assume 24; read `now_index`.
- Any point value may be `null` (upstream gap) — render as a missing bar, keep the slot.
- Frozen sample snapshot: `host/test/paper_weight/weather/fixtures/weather_snapshot_with_timeline.json`.

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
| `Timeline.build(minutely_15, current_time) → timeline` | pure (W6a) |
| Periodic refresh GenServer | cache last good; set `stale: true` on failure (timeline preserved) |

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

### W5
- [x] Host service fetches Open-Meteo current/hourly/daily instead of NWS/OpenUV
- [x] `WeatherSnapshotV1` envelope unchanged; current/forecast/UV grade/walk verdict behavior preserved
- [x] `OPENUV_API_KEY` removed from P7 runtime validation, `.env.example`, and live-runtime docs
- [x] Mocked malformed-response, stale-cache, network-loss, recovery tests pass
- [x] Required `ci` green; card/issue/spec/kanban closeout synchronized

## Deps request

_(lane agents append here; do not edit mix.exs)_

- ~~app: add `:inets` and `:ssl`~~ **done** — `mix.exs` adds them via `optional_http_apps/0` when OTP provides `:inets` (skipped on minimal installs). Tests still inject mocks.
- No new Hex packages required.

## Supervisor child (wave 3)

```elixir
{PaperWeight.Weather.Service, []}
```

## Next Session Context Chunk

- **W6a done (host timeline)**: snapshot now carries `timeline` (`WeatherTimelineV1`, FROZEN above) — half-hourly temp_f/wind_mph/precip_in, −12h…+24h, `now_index`. New pure `PaperWeight.Weather.Timeline`; `Config` adds `minutely_15`+`past/forecast_minutely_15`+`wind_speed_unit=mph`+`precipitation_unit=inch`; `OpenMeteo.parse` + `Snapshot.assemble` thread it through; `mark_stale` preserves it.
- **W6b builds against**: `fixtures/weather_snapshot_with_timeline.json` (73 pts, now_index 24). Read `now_index`, don't assume 24; values may be null.
- **Known risk (physical check)**: minutely_15 carrying temp/wind at Rory's real location is unverified by mocks — confirm on-device before W6c.
- **Weather fully wired (W1+W2+shell/host)**: `PaperWeight.Weather.Service` under Application (disabled in test via `config :paper_weight_host, weather_service: :disabled`); `:inets`/`:ssl` in `mix.exs`.
- Device: `ShellApp` renders `WeatherScreen` with fixture snapshot; wheel → `toggle-weather-range` flips local `weatherRange` 5d↔7d (`data-weather-range` on root).

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

## Next Session Context Chunk — W4 (2026-07-19, closed)

- W4 #87 accepted and closed. PR #95 squash-merged after two rebases (past P8 #86, then N4
  #89) onto `master`. Local validation: Weather 38/38, full host 201/201; required `ci` green.
- Physical acceptance on the Car Thing (live NWS/OpenUV via P7's `.env` contract): kiosk loads,
  live current conditions render, 5-day forecast displays, UV + walk verdict match the live
  snapshot.
- Two items did not survive genuine on-device verification and were split into their own
  Backlog cards rather than blocking #87 or being marked passed on weak evidence:
  - **#114** — wheel input does nothing on the physical Weather screen (5d/7d toggle never
    fires), even though `WeatherScreen`/`ShellApp` unit tests for the toggle pass. Likely
    input-bridge/shell wiring, not a Weather-service regression — needs triage before assuming
    Weather-lane ownership.
  - **#115** — stale/error and recovery behavior need a real ~15-minute network outage to
    verify; the refresh interval is fixed (`@default_refresh_ms`, `config.ex`) with no env
    override, so there's no shortcut. Not attempted for real this session.
- W5 #109 (Open-Meteo migration, Ready/P0) would remove the `OPENUV_API_KEY` requirement
  entirely — worth doing before re-attempting #115, since it changes what "stale/error" even
  means for this lane.

## Next Session Context Chunk — W5 (2026-07-19)

- Replaced `PaperWeight.Weather.Nws` + `PaperWeight.Weather.OpenUv` with one pure parser,
  `PaperWeight.Weather.OpenMeteo`, plus `PaperWeight.Weather.WeatherCode` (WMO `weather_code` →
  short summary text). `Config.open_meteo_url/1` builds a single no-key request:
  `current=temperature_2m,weather_code,uv_index`, `daily=weather_code,temperature_2m_max,temperature_2m_min`,
  `hourly=uv_index`, `temperature_unit=fahrenheit`, `timezone=auto`, `forecast_days=7`.
- `Fetch.fetch_snapshot/2` is now one HTTP round-trip (was points→forecast NWS calls plus a
  separate OpenUV uv+forecast pair). `uv.index` now comes from Open-Meteo's `current.uv_index`
  (an actual "now" value) rather than OpenUV's separate `/uv` endpoint; grading/verdict logic
  (`Grade`, `Verdict`) is untouched.
- `Snapshot.assemble/1` no longer calls `Nws.finalize_days/1` — Open-Meteo's `daily` block always
  has both high and low per day, so the NWS-specific gap-fill logic was dead weight for this
  provider; `pad_days/2` (7-day padding when short) is unchanged and provider-agnostic.
- `location_label` now comes from `WEATHER_LOCATION_LABEL` only — Open-Meteo's forecast endpoint
  has no reverse-geocoded place name (NWS's `relativeLocation` is gone). `WeatherSnapshotV1` itself
  is unchanged; this is a comment-only note in the payload contract.
- Removed `OPENUV_API_KEY` from `PaperWeight.RuntimeContract` (`weather` required-var list is now
  just `WEATHER_LAT`/`WEATHER_LON`), `.env.example`, and `docs/architecture/live-runtime-contract-v1.md`
  (table + example ArgumentError message); updated `runtime_contract_test.exs` and
  `application_test.exs` to match. `application.ex` itself untouched — it only reads
  `RuntimeContract.missing_vars/2`.
- Deleted `nws.ex`/`open_uv.ex` + their tests/fixtures; added `open_meteo_test.exs` +
  `fixtures/open_meteo_forecast.json` (7 days, 6 hourly UV points); rewrote `fetch_test.exs` and
  `service_test.exs` mocks around the single Open-Meteo URL. `snapshot_test.exs`/`grade_test.exs`/
  `verdict_test.exs` needed no changes (already provider-agnostic day maps).
- Not yet run in this session: `mix test` (agent shell doesn't run mix per project convention —
  hand Rory `cd ~/repos/paper-weight/.claude/worktrees/w5-openmeteo-109/host && mix test`).
  Resume: get his test results, fix any fallout, then PR + `ci` + physical/live acceptance +
  Done closeout (project Status, issue close, this table, `kanban/board.md`).

## Next Session Context Chunk — W5 (2026-07-19, closed)

- Rory ran `scripts/verify-w5-weather.sh` in his dev env; deps/format/compile/tests all green
  (Weather suite + full host suite). One real bug caught along the way: `application_weather_test.exs`
  still referenced removed `Config` keys (`nws_points_url`/`openuv_uv_url`/`openuv_forecast_url`) —
  fixed to use `open_meteo_url`.
- PR #118 opened, then hit a merge conflict against `master` (which had moved on with the W4
  closeout + stale-branch cleanup #105 landing first) — resolved via `git rebase origin/master`,
  one conflict in `kanban/board.md`'s status table, force-pushed. Required `ci` check went green
  on the rebased commit.
- PR #118 squash-merged and branch deleted; issue #109 auto-closed by the merge; GitHub Project
  Status was already Done from the merge-linked close. No physical/live device acceptance was
  required by this card's acceptance criteria (unlike W4) — Open-Meteo activation with a real
  location is future work, not blocking this migration's Done state.
- This closes the W5 lane. No further Weather kanban work is queued from this card; remaining
  Weather backlog items (#114 wheel toggle, #115 real-outage stale/recovery verification) are
  independent cards untouched by this migration.
