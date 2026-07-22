import { describe, expect, it } from "vitest";

import { applyWeatherRangeToggles } from "./ShellApp";

describe("applyWeatherRangeToggles", () => {
  it("toggles 5d ↔ 7d for each weather command", () => {
    expect(
      applyWeatherRangeToggles("5d", [{ type: "toggle-weather-range" }]),
    ).toBe("7d");
    expect(
      applyWeatherRangeToggles("7d", [{ type: "toggle-weather-range" }]),
    ).toBe("5d");
  });

  it("ignores unrelated shell commands", () => {
    expect(
      applyWeatherRangeToggles("5d", [
        { type: "scroll-feed", delta: 1 },
        { type: "skip-photo", delta: -2 },
      ]),
    ).toBe("5d");
  });

  it("applies multiple toggles in one batch", () => {
    expect(
      applyWeatherRangeToggles("5d", [
        { type: "toggle-weather-range" },
        { type: "toggle-weather-range" },
      ]),
    ).toBe("5d");
  });
});
