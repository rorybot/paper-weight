/** Pure Home glance types + formatting helpers. No host snapshot channel yet —
 * v1 renders from a static per-screen "last known status" fixture (see fixture.ts).
 */

export type HomeNowPlayingTile = Readonly<{
  kind: "now-playing";
  title: string;
  artist: string;
  progressMs: number;
  durationMs: number;
  volumeLevel: number; // 0..100
}>;

export type HomeWeatherTile = Readonly<{
  kind: "weather";
  tempF: number;
  condition: string;
  walkNote: string;
  uvIndex: number;
  uvGrade: "low" | "high" | "extreme";
}>;

export type HomeEtymologyTile = Readonly<{
  kind: "etymology";
  chain: string;
  depth: number;
  maxDepth: number;
}>;

export type HomePhotoTile = Readonly<{
  kind: "photo";
  index: number;
  total: number;
  reprintRatio: number; // 0..1, how full the countdown bar is
  reprintLabel: string;
}>;

export type HomeGlanceV1 = Readonly<{
  clockLabel: string;
  nowPlaying: HomeNowPlayingTile | null;
  weather: HomeWeatherTile | null;
  etymology: HomeEtymologyTile | null;
  photo: HomePhotoTile | null;
}>;

const FILLED = "▮";
const EMPTY = "▯";

/** 1-bit-style bar glyph string, same idiom as the weather screen's UV legend. */
export const barGlyphs = (ratio: number, width = 10): string => {
  const clamped = Math.min(1, Math.max(0, ratio));
  const filled = Math.round(clamped * width);
  return FILLED.repeat(filled) + EMPTY.repeat(width - filled);
};

export const formatMs = (ms: number): string => {
  const totalSeconds = Math.max(0, Math.round(ms / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${String(seconds).padStart(2, "0")}`;
};

/** UV bar width relative to a 0..11 scale, capped like the weather screen's legend. */
export const uvRatio = (index: number): number => Math.min(1, Math.max(0, index / 11));
