import { describe, expect, it } from "vitest";

import { barGlyphs, formatMs, uvRatio } from "./model";

describe("barGlyphs", () => {
  it("renders a fully empty bar at ratio 0", () => {
    expect(barGlyphs(0, 4)).toBe("▯▯▯▯");
  });

  it("renders a fully filled bar at ratio 1", () => {
    expect(barGlyphs(1, 4)).toBe("▮▮▮▮");
  });

  it("rounds to the nearest filled segment", () => {
    expect(barGlyphs(0.5, 4)).toBe("▮▮▯▯");
  });

  it("clamps ratios below 0", () => {
    expect(barGlyphs(-1, 4)).toBe("▯▯▯▯");
  });

  it("clamps ratios above 1", () => {
    expect(barGlyphs(2, 4)).toBe("▮▮▮▮");
  });

  it("defaults to a width of 10", () => {
    expect(barGlyphs(1)).toBe("▮".repeat(10));
  });
});

describe("formatMs", () => {
  it("formats sub-minute durations", () => {
    expect(formatMs(45_000)).toBe("0:45");
  });

  it("formats minutes and seconds with zero-padding", () => {
    expect(formatMs(134_000)).toBe("2:14");
  });

  it("pads single-digit seconds", () => {
    expect(formatMs(65_000)).toBe("1:05");
  });

  it("clamps negative values to zero", () => {
    expect(formatMs(-500)).toBe("0:00");
  });
});

describe("uvRatio", () => {
  it("maps 0 to a ratio of 0", () => {
    expect(uvRatio(0)).toBe(0);
  });

  it("maps 11+ to a ratio of 1", () => {
    expect(uvRatio(11)).toBe(1);
    expect(uvRatio(15)).toBe(1);
  });

  it("scales linearly in between", () => {
    expect(uvRatio(5.5)).toBeCloseTo(0.5, 5);
  });
});
