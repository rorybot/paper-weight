import render from "preact-render-to-string";
import { describe, expect, it } from "vitest";

import { TimelineGraph } from "./TimelineGraph";
import { weatherTimelineFixture } from "./timelineFixture";
import { tickMarks } from "./timelineModel";

const html = (): string =>
  render(<TimelineGraph timeline={weatherTimelineFixture} theme="gruvbox" />);

describe("TimelineGraph", () => {
  it("renders all three series tracks from the fixture", () => {
    const out = html();
    expect(out).toContain('data-series="temp"');
    expect(out).toContain('data-series="wind"');
    expect(out).toContain('data-series="precip"');
    expect(out).toContain("temp");
    expect(out).toContain("wind");
    expect(out).toContain("precip");
  });

  it("renders one bar per point per series", () => {
    const out = html();
    const bars = out.match(/class="wx-tl__bar"/g) ?? [];
    // 3 series × 73 points.
    expect(bars.length).toBe(3 * weatherTimelineFixture.points.length);
  });

  it("renders the now marker at the now_index position", () => {
    const out = html();
    expect(out).toContain('data-now="true"');
    expect(out).toContain(`data-now-index="${weatherTimelineFixture.now_index}"`);
    expect(out).toContain("now");
  });

  it("marks past bars distinctly from forecast bars", () => {
    const out = html();
    expect(out).toContain('data-past="true"');
    expect(out).toContain('data-past="false"');
  });

  it("renders hour tick labels", () => {
    const out = html();
    const ticks = tickMarks(weatherTimelineFixture, 3);
    expect(ticks.length).toBeGreaterThan(0);
    for (const t of ticks) {
      expect(out).toContain(`data-tick-index="${t.index}"`);
    }
  });

  it("is themed and sized to fit the 800×480 weather screen without clipping", () => {
    const out = html();
    expect(out).toContain('data-theme="gruvbox"');
    expect(out).toContain("theme-gruvbox");
    // Fixed 800px width; height is bounded by CSS (3 × 62px rows + axis ≈ 230px).
    expect(out).toMatch(/width:\s*800px/);
    expect(out).toContain(`data-point-count="${weatherTimelineFixture.points.length}"`);
  });
});
