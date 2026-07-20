/**
 * Local fixture for the W6b timeline graph.
 *
 * Shape reconciled against W6a (#132)'s frozen envelope: `step_minutes` /
 * `now_index` / `series` (not `interval_minutes` / `points`), with
 * `precip_in` (inches) rather than a probability percentage. Generator kept
 * isolated here, separate from the component.
 */

import type {
  WeatherTimelinePointV1,
  WeatherTimelineV1,
} from "./timelineModel";

const STEP_MINUTES = 30;
const HOURS_BACK = 12;
const HOURS_FORWARD = 24;
const STEPS_PER_HOUR = 60 / STEP_MINUTES; // 2
const NOW_INDEX = HOURS_BACK * STEPS_PER_HOUR; // 24
const TOTAL_STEPS = (HOURS_BACK + HOURS_FORWARD) * STEPS_PER_HOUR + 1; // 73

/** Anchor "now" at a fixed local wall-clock so the fixture is deterministic. */
const NOW_ANCHOR = new Date(Date.UTC(2026, 6, 19, 14, 0, 0)); // 2026-07-19 14:00

/** Local ISO-8601 "YYYY-MM-DDTHH:MM" (no zone; treated as location-local). */
const toLocalIso = (d: Date): string => {
  const p = (n: number): string => String(n).padStart(2, "0");
  return (
    `${d.getUTCFullYear()}-${p(d.getUTCMonth() + 1)}-${p(d.getUTCDate())}` +
    `T${p(d.getUTCHours())}:${p(d.getUTCMinutes())}`
  );
};

/** Smooth deterministic diurnal-ish curves; no randomness so tests are stable. */
const pointAt = (step: number): WeatherTimelinePointV1 => {
  const hoursFromNow = (step - NOW_INDEX) / STEPS_PER_HOUR;
  const t = new Date(NOW_ANCHOR.getTime() + hoursFromNow * 3600_000);
  const hourOfDay = t.getUTCHours() + t.getUTCMinutes() / 60;

  // Temperature: warm afternoon peak (~15:00), cool pre-dawn (~05:00).
  const tempPhase = ((hourOfDay - 15) / 24) * 2 * Math.PI;
  const temp_f = Math.round(78 + 14 * Math.cos(tempPhase));

  // Wind: builds through the afternoon, calmer overnight.
  const windPhase = ((hourOfDay - 17) / 24) * 2 * Math.PI;
  const wind_mph = Math.max(2, Math.round(9 + 7 * Math.cos(windPhase)));

  // Precipitation: a forecast storm window in the +3h…+9h range, in inches.
  const precipCenter = 6; // hours from now
  const precipWidth = 3;
  const bump = Math.exp(
    -((hoursFromNow - precipCenter) ** 2) / (2 * precipWidth ** 2),
  );
  const precip_in = Math.round((0.02 + 0.3 * bump) * 100) / 100;

  return Object.freeze({
    time_local: toLocalIso(t),
    temp_f,
    wind_mph,
    precip_in,
  });
};

const series: readonly WeatherTimelinePointV1[] = Object.freeze(
  Array.from({ length: TOTAL_STEPS }, (_, step) => pointAt(step)),
);

export const weatherTimelineFixture: WeatherTimelineV1 = Object.freeze({
  step_minutes: STEP_MINUTES,
  now_index: NOW_INDEX,
  series,
});
