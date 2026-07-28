import type {
  WeatherTimelinePointV1,
  WeatherTimelineV1,
} from "../../protocol/weather";

export type {
  WeatherTimelinePointV1,
  WeatherTimelineV1,
} from "../../protocol/weather";

/**
 * Pure model for the half-hourly weather timeline graph (W6b).
 *
 * DATA SHAPE — reconciled against W6a (#132)'s frozen envelope addition:
 * `timeline: { step_minutes, now_index, series: [{ time_local, temp_f,
 * wind_mph, precip_in }] }`. Numeric fields are nullable because a live
 * Open-Meteo window can have gaps; a null renders as a zero-height (absent)
 * bar without disturbing its series' min/max scaling. precip is inches.
 */

export type TimelineSeriesKey = "temp" | "wind" | "precip";

export type TimelineSeries = Readonly<{
  key: TimelineSeriesKey;
  /** Short row label. */
  label: string;
  /** Per-bar hover/title formatter for a present value. */
  format: (value: number) => string;
  /** Raw values, one per timeline point; null = no data for that sample. */
  values: readonly (number | null)[];
}>;

/** Minimum bar height (%) so a low-but-present value still shows a nub. */
const FLOOR_PCT = 12;

const isPresent = (v: number | null): v is number =>
  v !== null && Number.isFinite(v);

/**
 * Normalize a single series to bar-height percentages using that series' OWN
 * min/max over its present (non-null) values. Temp/wind/precip share no scale,
 * so each is normalized independently. A flat series (max === min) renders every
 * present bar at the floor; a null/absent sample renders at 0 (no bar).
 */
export const seriesHeights = (
  values: readonly (number | null)[],
  floorPct: number = FLOOR_PCT,
): number[] => {
  const present = values.filter(isPresent);
  if (present.length === 0) return values.map(() => 0);
  const min = Math.min(...present);
  const max = Math.max(...present);
  const span = max - min;
  return values.map((v) => {
    if (!isPresent(v)) return 0;
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

/** Clamp a cursor to the available timeline points. Empty timelines use 0. */
export const clampTimelineIndex = (index: number, length: number): number => {
  if (length <= 0) return 0;
  return Math.min(Math.max(Math.trunc(index), 0), length - 1);
};

/** Selected-point marker position as a percentage across the track. */
export const selectedMarkerPct = (
  timeline: WeatherTimelineV1,
  index: number,
): number =>
  barCenterPct(clampTimelineIndex(index, timeline.series.length), timeline.series.length);

export const selectedTimelinePoint = (
  timeline: WeatherTimelineV1,
  index: number,
): WeatherTimelinePointV1 | null =>
  timeline.series[clampTimelineIndex(index, timeline.series.length)] ?? null;

/** "now" marker position as a percentage across the track. */
export const nowMarkerPct = (timeline: WeatherTimelineV1): number =>
  barCenterPct(timeline.now_index, timeline.series.length);

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

/** Compact local date/time label without applying the browser timezone. */
export const timelinePointLabel = (iso: string): string => {
  const [date = "", clock = ""] = iso.split("T");
  const [year, month, day] = date.split("-").map(Number);
  const [hour, minute] = clock.split(":").map(Number);
  if (!year || !month || !day || !Number.isFinite(hour) || !Number.isFinite(minute)) {
    return iso;
  }
  const months = [
    "jan", "feb", "mar", "apr", "may", "jun",
    "jul", "aug", "sep", "oct", "nov", "dec",
  ] as const;
  const hour12 = ((hour + 11) % 12) + 1;
  const suffix = hour >= 12 ? "p" : "a";
  const minuteLabel = minute === 0 ? "" : `:${String(minute).padStart(2, "0")}`;
  return `${months[month - 1] ?? month} ${day} · ${hour12}${minuteLabel}${suffix}`;
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
  const n = timeline.series.length;
  const perHour = timeline.step_minutes > 0
    ? Math.round(60 / timeline.step_minutes)
    : 1;
  const stride = Math.max(1, perHour * everyHours);
  const ticks: TimelineTick[] = [];
  timeline.series.forEach((p, i) => {
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
    format: (v) => `${Math.round(v)}°`,
    values: timeline.series.map((p) => p.temp_f),
  },
  {
    key: "wind",
    label: "wind",
    format: (v) => `${Math.round(v)} mph`,
    values: timeline.series.map((p) => p.wind_mph),
  },
  {
    key: "precip",
    label: "precip",
    format: (v) => `${v.toFixed(2)} in`,
    values: timeline.series.map((p) => p.precip_in),
  },
];
