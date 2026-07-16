import { describe, expect, it } from "vitest";

import {
  conditionGlyph,
  gradeUvIndex,
  hourLabel,
  initialWeatherUiState,
  reduceWeatherUi,
  weekdayShort,
} from "./model";

describe("gradeUvIndex", () => {
  it("maps all three locked grades", () => {
    expect(gradeUvIndex(0)).toBe("low");
    expect(gradeUvIndex(5.9)).toBe("low");
    expect(gradeUvIndex(6)).toBe("high");
    expect(gradeUvIndex(7.9)).toBe("high");
    expect(gradeUvIndex(8)).toBe("extreme");
    expect(gradeUvIndex(11)).toBe("extreme");
  });
});

describe("reduceWeatherUi", () => {
  it("toggles 5d ↔ 7d on toggle-weather-range", () => {
    const a = initialWeatherUiState("5d");
    const b = reduceWeatherUi(a, { type: "toggle-weather-range" });
    expect(b.range).toBe("7d");
    const c = reduceWeatherUi(b, { type: "toggle-weather-range" });
    expect(c.range).toBe("5d");
  });
});

describe("weekdayShort", () => {
  it("returns lowercase weekday for ISO dates", () => {
    // 2026-07-15 is a Wednesday
    expect(weekdayShort("2026-07-15")).toBe("wed");
    expect(weekdayShort("2026-07-16")).toBe("thu");
  });
});

describe("conditionGlyph / hourLabel", () => {
  it("picks glyphs from summary keywords", () => {
    expect(conditionGlyph("sunny")).toBe("☀");
    expect(conditionGlyph("pm storms")).toBe("◎");
  });

  it("formats hour labels", () => {
    expect(hourLabel("13:00")).toBe("1p");
    expect(hourLabel("09:00")).toBe("9a");
  });
});
