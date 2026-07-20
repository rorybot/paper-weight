import { describe, expect, it } from "vitest";

import { weatherTimelineFixture } from "./timelineFixture";
import {
  barCenterPct,
  nowMarkerPct,
  seriesHeights,
  tickMarks,
  timelineHourLabel,
  timelineSeries,
} from "./timelineModel";

describe("seriesHeights", () => {
  it("normalizes per-series min/max to floor..100", () => {
    const h = seriesHeights([10, 20, 30]);
    expect(h[0]).toBe(12); // min → floor
    expect(h[2]).toBe(100); // max → full
    expect(h[1]).toBeGreaterThan(h[0]);
    expect(h[1]).toBeLessThan(h[2]);
  });

  it("returns floor for a flat series (no shared scale, no divide-by-zero)", () => {
    expect(seriesHeights([7, 7, 7])).toEqual([12, 12, 12]);
  });

  it("respects a custom floor and handles empty input", () => {
    expect(seriesHeights([1, 2], 20)[0]).toBe(20);
    expect(seriesHeights([])).toEqual([]);
  });

  it("scales each series independently (temp vs precip do not share a scale)", () => {
    const [temp, wind, precip] = timelineSeries(weatherTimelineFixture);
    // Every series pins its own max at 100 regardless of raw magnitude.
    expect(Math.max(...seriesHeights(temp.values))).toBe(100);
    expect(Math.max(...seriesHeights(wind.values))).toBe(100);
    expect(Math.max(...seriesHeights(precip.values))).toBe(100);
  });
});

describe("barCenterPct", () => {
  it("centers bars within the track width", () => {
    expect(barCenterPct(0, 4)).toBeCloseTo(12.5);
    expect(barCenterPct(3, 4)).toBeCloseTo(87.5);
    expect(barCenterPct(0, 0)).toBe(0);
  });
});

describe("timelineHourLabel", () => {
  it("formats 12h am/pm from ISO local time", () => {
    expect(timelineHourLabel("2026-07-19T13:00")).toBe("1p");
    expect(timelineHourLabel("2026-07-19T09:30")).toBe("9a");
    expect(timelineHourLabel("2026-07-19T00:00")).toBe("12a");
    expect(timelineHourLabel("2026-07-19T12:00")).toBe("12p");
  });
});

describe("nowMarkerPct / fixture", () => {
  it("places the now marker at the now_index bar center", () => {
    const pct = nowMarkerPct(weatherTimelineFixture);
    expect(pct).toBeCloseTo(
      barCenterPct(
        weatherTimelineFixture.now_index,
        weatherTimelineFixture.series.length,
      ),
    );
  });

  it("covers −12h…+24h half-hourly (73 points, now at index 24)", () => {
    expect(weatherTimelineFixture.step_minutes).toBe(30);
    expect(weatherTimelineFixture.series.length).toBe(73);
    expect(weatherTimelineFixture.now_index).toBe(24);
  });
});

describe("tickMarks", () => {
  it("emits whole-hour labels spaced by everyHours, positioned in-track", () => {
    const ticks = tickMarks(weatherTimelineFixture, 3);
    expect(ticks.length).toBeGreaterThan(0);
    // 36h span / 3h ≈ 13 ticks (inclusive of endpoints).
    expect(ticks.length).toBeLessThanOrEqual(13);
    for (const t of ticks) {
      expect(t.leftPct).toBeGreaterThanOrEqual(0);
      expect(t.leftPct).toBeLessThanOrEqual(100);
      expect(t.label).toMatch(/^\d{1,2}[ap]$/);
    }
  });
});
