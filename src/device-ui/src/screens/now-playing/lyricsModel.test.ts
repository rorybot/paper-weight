import { describe, expect, it } from "vitest";

import {
  nowPlayingFixtureNoLyrics,
  nowPlayingFixtureSnapshot,
} from "./fixture";
import {
  activeLineIndex,
  formatMs,
  lyricsFromSnapshot,
  LYRICS_WINDOW,
  positionLabel,
  progressMs,
  trackLabel,
  visibleLineIndices,
} from "./lyricsModel";

const lines = nowPlayingFixtureSnapshot.lyrics!.lines;

describe("activeLineIndex", () => {
  it("picks last line at or before progress", () => {
    // progress 82s → line at 78_000 is active
    expect(activeLineIndex(lines, 82_000)).toBe(5);
    expect(lines[5]!.text).toContain("station");
  });

  it("starts at 0 before first timed beat", () => {
    expect(activeLineIndex(lines, 0)).toBe(0);
    expect(activeLineIndex(lines, 5_000)).toBe(0);
  });

  it("clamps to last line past the end", () => {
    expect(activeLineIndex(lines, 999_999)).toBe(lines.length - 1);
  });

  it("handles empty lines", () => {
    expect(activeLineIndex([], 1000)).toBe(0);
  });
});

describe("visibleLineIndices", () => {
  it("returns full list when short", () => {
    expect(visibleLineIndices(3, 1)).toEqual([0, 1, 2]);
  });

  it("keeps active visible in a LYRICS_WINDOW window", () => {
    const mid = visibleLineIndices(lines.length, 5);
    expect(mid.length).toBe(LYRICS_WINDOW);
    expect(mid).toContain(5);
    const end = visibleLineIndices(lines.length, lines.length - 1);
    expect(end).toContain(lines.length - 1);
    expect(end.length).toBe(LYRICS_WINDOW);
  });
});

describe("snapshot helpers", () => {
  it("reads lyrics / progress / track label", () => {
    expect(lyricsFromSnapshot(nowPlayingFixtureSnapshot)?.lines.length).toBe(
      10,
    );
    expect(lyricsFromSnapshot(nowPlayingFixtureNoLyrics)).toBeNull();
    expect(progressMs(nowPlayingFixtureSnapshot)).toBe(82_000);
    expect(trackLabel(nowPlayingFixtureSnapshot)).toBe("Galactic · Tenure");
    expect(formatMs(82_000)).toBe("1:22");
    expect(positionLabel(5, 10)).toBe("6/10");
  });
});
