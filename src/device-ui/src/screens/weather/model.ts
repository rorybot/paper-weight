import type { WeatherTimelineV1 } from "../../protocol/weather";
import { clampTimelineIndex } from "./timelineModel";

export const WEATHER_IDLE_MS = 7_000;

export type WeatherUiMode = "current" | "timeline";

export type WeatherUiState = Readonly<{
  mode: WeatherUiMode;
  scrubIndex: number;
}>;

export type WeatherUiCommand = Readonly<{
  type: "scrub-weather-timeline";
  delta: number;
}>;

const nowIndex = (timeline: WeatherTimelineV1): number =>
  clampTimelineIndex(timeline.now_index, timeline.series.length);

export const initialWeatherUiState = (
  timeline: WeatherTimelineV1,
): WeatherUiState =>
  Object.freeze({ mode: "current", scrubIndex: nowIndex(timeline) });

export const reconcileWeatherUiState = (
  state: WeatherUiState,
  timeline: WeatherTimelineV1,
): WeatherUiState => {
  if (timeline.series.length === 0) {
    return state.mode === "current" && state.scrubIndex === 0
      ? state
      : Object.freeze({ mode: "current", scrubIndex: 0 });
  }

  const scrubIndex = clampTimelineIndex(
    state.mode === "current" ? timeline.now_index : state.scrubIndex,
    timeline.series.length,
  );
  return scrubIndex === state.scrubIndex
    ? state
    : Object.freeze({ ...state, scrubIndex });
};

/** One physical wheel detent moves one adjacent timeline point. */
export const reduceWeatherUi = (
  state: WeatherUiState,
  command: WeatherUiCommand,
  timeline: WeatherTimelineV1,
): WeatherUiState => {
  if (command.delta === 0 || timeline.series.length === 0) return state;

  const start = state.mode === "timeline" ? state.scrubIndex : nowIndex(timeline);
  const scrubIndex = clampTimelineIndex(
    start + Math.trunc(command.delta),
    timeline.series.length,
  );
  if (state.mode === "timeline" && scrubIndex === state.scrubIndex) return state;
  return Object.freeze({ mode: "timeline", scrubIndex });
};

export const returnWeatherToCurrent = (
  state: WeatherUiState,
  timeline: WeatherTimelineV1,
): WeatherUiState => {
  const scrubIndex = nowIndex(timeline);
  if (state.mode === "current" && state.scrubIndex === scrubIndex) return state;
  return Object.freeze({ mode: "current", scrubIndex });
};

export const weatherIdleElapsed = (
  elapsedMs: number,
  idleMs: number = WEATHER_IDLE_MS,
): boolean => elapsedMs >= idleMs;

/** Locked UV grade rules (same as host W1). */
export type UvGrade = "extreme" | "high" | "low";

export const gradeUvIndex = (index: number): UvGrade => {
  if (index >= 8) return "extreme";
  if (index >= 6) return "high";
  return "low";
};

const WEEKDAYS = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"] as const;

export const weekdayShort = (isoDate: string): string => {
  const [y, m, d] = isoDate.split("-").map(Number);
  if (!y || !m || !d) return isoDate;
  // Noon UTC avoids local DST edge cases for calendar day.
  const day = new Date(Date.UTC(y, m - 1, d, 12, 0, 0)).getUTCDay();
  return WEEKDAYS[day] ?? isoDate;
};

export const conditionGlyph = (summary: string): string => {
  const s = summary.toLowerCase();
  if (s.includes("storm") || s.includes("thunder")) return "◎";
  if (s.includes("rain") || s.includes("shower")) return "◌";
  if (s.includes("cloud") || s.includes("overcast")) return "◍";
  if (s.includes("snow")) return "❄";
  if (s.includes("clear") || s.includes("sunny") || s.includes("hot")) return "☀";
  return "·";
};

export const hourLabel = (hourLocal: string): string => {
  // "13:00" → "1p", "09:30" → "9a"
  const [hStr] = hourLocal.split(":");
  const h = Number(hStr);
  if (!Number.isFinite(h)) return hourLocal;
  const hour12 = ((h + 11) % 12) + 1;
  const suffix = h >= 12 ? "p" : "a";
  return `${hour12}${suffix}`;
};
