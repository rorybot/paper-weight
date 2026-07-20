/**
 * Pure model for the half-hourly weather timeline graph (W6b).
 *
 * DATA SHAPE — ASSUMED, NOT YET RECONCILED.
 * W6a (#132) freezes the real envelope addition; at the time this was written
 * that PR was not yet pushed, so the types below follow the ticket description:
 * half-hourly temp/wind/precip series over −12h…+24h plus a "now" index.
 *
 * Reconcile is intended to be a ONE-FILE change (this file + `timelineFixture.ts`).
 * Highest-risk field: `precip_pct`. Open-Meteo exposes BOTH `precipitation` (mm)
 * and `precipitation_probability` (%). We chose probability (0–100) because it
 * reads cleanly on a height-encoded bar; W6a may instead ship the mm amount under
 * a different name. See PR body.
 */

export type WeatherTimelinePointV1 = Readonly<{
  /** ISO-8601 local time, spaced every `interval_minutes`. */
  time_local: string;
  temp_f: number;
  wind_mph: number;
  /** precipitation probability 0–100 (see reconcile note above). */
  precip_pct: number;
}>;

export type WeatherTimelineV1 = Readonly<{
  /** Sample spacing in minutes (30 for half-hourly). */
  interval_minutes: number;
  /** Index into `points` pointing at "now" (boundary of past vs. forecast). */
  now_index: number;
  /** Half-hourly samples across −12h…+24h. */
  points: readonly WeatherTimelinePointV1[];
}>;

export type TimelineSeriesKey = "temp" | "wind" | "precip";

export type TimelineSeries = Readonly<{
  key: TimelineSeriesKey;
  /** Short row label. */
  label: string;
  /** Unit suffix used in per-bar titles. */
  unit: string;
  /** Raw values, one per timeline point. */
  values: readonly number[];
}>;

/** Minimum bar height (%) so a low-but-present value still shows a nub. */
const FLOOR_PCT = 12;

/**
 * Normalize a single series to bar-height percentages using that series' OWN
 * min/max. Temp/wind/precip share no scale, so each is normalized independently.
 * A flat series (max === min) renders every bar at the floor.
 */
export const seriesHeights = (
  values: readonly number[],
  floorPct: number = FLOOR_PCT,
): number[] => {
  if (values.length === 0) return [];
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min;
  return values.map((v) => {
    if (span === 0) return floorPct;
    const frac = (v - min) / span;
    return Math.round(floorPct + (100 - floorPct) * frac);
  });
};

/** Horizontal center of bar `i` (of `n`) as a percentage of the track width. */
export const barCenterPct = (index: number, length: number): number => {
  if (length <= 0) return 0;
  return ((index + 0.5) / length) * 100;
};

/** "now" marker position as a percentage across the track. */
export const nowMarkerPct = (timeline: WeatherTimelineV1): number =>
  barCenterPct(timeline.now_index, timeline.points.length);

/** Extract "HH:MM" (24h) from an ISO-8601 local timestamp; "" if unparseable. */
const clockOf = (iso: string): string => {
  const t = iso.includes("T") ? iso.split("T")[1] : iso;
  const [h, m] = (t ?? "").split(":");
  if (h === undefined || m === undefined) return "";
  return `${h}:${m}`;
};

/** Whole-hour points only (minutes === "00"). */
const isWholeHour = (iso: string): boolean => clockOf(iso).endsWith(":00");

/** "13:00" → "1p", "09:30" → "9a"; passthrough if unparseable. */
export const timelineHourLabel = (iso: string): string => {
  const clock = clockOf(iso);
  const [hStr] = clock.split(":");
  const h = Number(hStr);
  if (!Number.isFinite(h)) return iso;
  const hour12 = ((h + 11) % 12) + 1;
  const suffix = h >= 12 ? "p" : "a";
  return `${hour12}${suffix}`;
};

export type TimelineTick = Readonly<{
  index: number;
  label: string;
  /** Horizontal position (%) of the tick, aligned to the bar center. */
  leftPct: number;
}>;

/**
 * Tick marks for the hour axis. Considers only whole-hour points and keeps
 * roughly one label every `everyHours` hours so 800px stays uncluttered.
 */
export const tickMarks = (
  timeline: WeatherTimelineV1,
  everyHours: number = 3,
): TimelineTick[] => {
  const n = timeline.points.length;
  const perHour = timeline.interval_minutes > 0
    ? Math.round(60 / timeline.interval_minutes)
    : 1;
  const stride = Math.max(1, perHour * everyHours);
  const ticks: TimelineTick[] = [];
  timeline.points.forEach((p, i) => {
    if (!isWholeHour(p.time_local)) return;
    if (i % stride !== 0) return;
    ticks.push({
      index: i,
      label: timelineHourLabel(p.time_local),
      leftPct: barCenterPct(i, n),
    });
  });
  return ticks;
};

/** Build the three normalized series for rendering, in row order. */
export const timelineSeries = (
  timeline: WeatherTimelineV1,
): TimelineSeries[] => [
  {
    key: "temp",
    label: "temp",
    unit: "°",
    values: timeline.points.map((p) => p.temp_f),
  },
  {
    key: "wind",
    label: "wind",
    unit: " mph",
    values: timeline.points.map((p) => p.wind_mph),
  },
  {
    key: "precip",
    label: "precip",
    unit: "%",
    values: timeline.points.map((p) => p.precip_pct),
  },
];
