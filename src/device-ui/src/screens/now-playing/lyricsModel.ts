/**
 * Pure lyrics overlay helpers — shell owns open/close (`lyrics` overlay).
 * N3: paper card over dimmed 4a; lines sync to track progress when timed.
 */

import type { NowPlayingSnapshotV1 } from "../../protocol/now_playing";

export type LyricsLineV1 = Readonly<{
  t_ms: number;
  text: string;
}>;

export type LyricsPayloadV1 = Readonly<{
  lines: readonly LyricsLineV1[];
}>;

/** Lines to show around the active index (mockup-scale readability). */
export const LYRICS_WINDOW = 7;

/**
 * Active line = last line with `t_ms <= progress_ms`.
 * Empty / all-future → 0; past end → last index.
 */
export const activeLineIndex = (
  lines: readonly LyricsLineV1[],
  progressMs: number,
): number => {
  if (lines.length === 0) return 0;
  let active = 0;
  for (let i = 0; i < lines.length; i += 1) {
    if (lines[i]!.t_ms <= progressMs) active = i;
    else break;
  }
  return active;
};

/**
 * Window of line indices keeping the active line visible
 * (prefer centered when list is long enough).
 */
export const visibleLineIndices = (
  lineCount: number,
  activeIndex: number,
  windowSize: number = LYRICS_WINDOW,
): readonly number[] => {
  if (lineCount <= 0) return [];
  if (lineCount <= windowSize) {
    return Array.from({ length: lineCount }, (_, i) => i);
  }
  let start = activeIndex - Math.floor(windowSize / 2);
  start = clamp(start, 0, lineCount - windowSize);
  return Array.from({ length: windowSize }, (_, i) => start + i);
};

export const lyricsFromSnapshot = (
  snapshot: NowPlayingSnapshotV1,
): LyricsPayloadV1 | null => {
  const lyrics = snapshot.lyrics;
  if (!lyrics || lyrics.lines.length === 0) return null;
  return Object.freeze({ lines: lyrics.lines });
};

export const trackLabel = (snapshot: NowPlayingSnapshotV1): string => {
  const t = snapshot.track;
  if (!t) return "no track";
  return `${t.title} · ${t.artist}`;
};

export const progressMs = (snapshot: NowPlayingSnapshotV1): number =>
  snapshot.track?.progress_ms ?? 0;

/** "1:22" style clock from milliseconds. */
export const formatMs = (ms: number): string => {
  if (!Number.isFinite(ms) || ms < 0) return "0:00";
  const totalSec = Math.floor(ms / 1000);
  const m = Math.floor(totalSec / 60);
  const s = totalSec % 60;
  return `${m}:${String(s).padStart(2, "0")}`;
};

export const positionLabel = (
  activeIndex: number,
  lineCount: number,
): string => {
  if (lineCount <= 0) return "0/0";
  return `${activeIndex + 1}/${lineCount}`;
};

const clamp = (n: number, min: number, max: number): number =>
  Math.min(Math.max(n, min), max);
