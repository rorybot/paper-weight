/** Pure weather screen UI state — shell emits `toggle-weather-range`; we reduce locally. */

export type WeatherRange = "5d" | "7d";

export type WeatherUiState = Readonly<{
  range: WeatherRange;
}>;

export type WeatherUiCommand = Readonly<{ type: "toggle-weather-range" }>;

export const initialWeatherUiState = (
  range: WeatherRange = "5d",
): WeatherUiState => Object.freeze({ range });

export const reduceWeatherUi = (
  state: WeatherUiState,
  command: WeatherUiCommand,
): WeatherUiState => {
  if (command.type === "toggle-weather-range") {
    return Object.freeze({
      range: state.range === "5d" ? "7d" : "5d",
    });
  }
  return state;
};

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
