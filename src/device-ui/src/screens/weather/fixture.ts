import type { WeatherSnapshotV1 } from "../../protocol/weather";

/** Fixture snapshot shaped for `spec/weather-4b.png` (W2 UI-ahead). */
export const weatherFixtureSnapshot: WeatherSnapshotV1 = Object.freeze({
  location_label: "exampleville, ex",
  as_of: "2026-07-16T20:00:00Z",
  stale: false,
  current: Object.freeze({
    temp_f: 92,
    summary: "sunny",
  }),
  walk_verdict:
    "good window right now — but be home by 5. storms & strong sun midday.",
  uv: Object.freeze({
    index: 9.2,
    grade: "extreme" as const,
  }),
  days5: Object.freeze([
    Object.freeze({
      date: "2026-07-15",
      high_f: 92,
      low_f: 61,
      summary: "pm storms",
    }),
    Object.freeze({
      date: "2026-07-16",
      high_f: 96,
      low_f: 63,
      summary: "sunny",
    }),
    Object.freeze({
      date: "2026-07-17",
      high_f: 89,
      low_f: 60,
      summary: "pm storms",
    }),
    Object.freeze({
      date: "2026-07-18",
      high_f: 97,
      low_f: 64,
      summary: "hot, clear",
    }),
    Object.freeze({
      date: "2026-07-19",
      high_f: 85,
      low_f: 58,
      summary: "storms",
    }),
  ]),
  days7: Object.freeze([
    Object.freeze({
      date: "2026-07-15",
      high_f: 92,
      low_f: 61,
      summary: "pm storms",
    }),
    Object.freeze({
      date: "2026-07-16",
      high_f: 96,
      low_f: 63,
      summary: "sunny",
    }),
    Object.freeze({
      date: "2026-07-17",
      high_f: 89,
      low_f: 60,
      summary: "pm storms",
    }),
    Object.freeze({
      date: "2026-07-18",
      high_f: 97,
      low_f: 64,
      summary: "hot, clear",
    }),
    Object.freeze({
      date: "2026-07-19",
      high_f: 85,
      low_f: 58,
      summary: "storms",
    }),
    Object.freeze({
      date: "2026-07-20",
      high_f: 88,
      low_f: 59,
      summary: "mostly sunny",
    }),
    Object.freeze({
      date: "2026-07-21",
      high_f: 91,
      low_f: 62,
      summary: "sunny",
    }),
  ]),
  hourly_uv: Object.freeze([
    Object.freeze({ hour_local: "13:00", index: 9.5 }),
    Object.freeze({ hour_local: "14:00", index: 10.1 }),
    Object.freeze({ hour_local: "15:00", index: 7.2 }),
    Object.freeze({ hour_local: "16:00", index: 6.8 }),
    Object.freeze({ hour_local: "17:00", index: 6.1 }),
    Object.freeze({ hour_local: "18:00", index: 4.0 }),
    Object.freeze({ hour_local: "19:00", index: 2.5 }),
    Object.freeze({ hour_local: "20:00", index: 1.2 }),
    Object.freeze({ hour_local: "21:00", index: 0.4 }),
    Object.freeze({ hour_local: "22:00", index: 6.5 }),
  ]),
});
