import render from "preact-render-to-string";
import { describe, expect, it } from "vitest";

import { weatherFixtureSnapshot } from "./fixture";
import {
  gradeUvIndex,
  initialWeatherUiState,
  reduceWeatherUi,
} from "./model";
import { WeatherScreen } from "./WeatherScreen";

describe("WeatherScreen", () => {
  it("renders 800×480 fixture layout matching mockup intent", () => {
    const html = render(
      <WeatherScreen snapshot={weatherFixtureSnapshot} theme="gruvbox" />,
    );

    expect(html).toContain("wx-screen");
    expect(html).toContain('data-theme="gruvbox"');
    expect(html).toContain('data-range="5d"');
    expect(html).toMatch(/800px/);
    expect(html).toMatch(/480px/);
    expect(html).toContain("exampleville, ex");
    expect(html).toContain("92°");
    expect(html).toContain("sunny");
    expect(html).toContain("WALK?");
    // HTML escapes & → &amp;
    expect(html).toContain("good window right now");
    expect(html).toContain("home by 5");
    expect(html).toContain("nws · openuv");
    expect(html).toContain("today");
    expect(html).toContain("7-day");
    expect(html).toContain('data-day-count="5"');
  });

  it("shows 7-day rows when range is 7d (wheel toggle target)", () => {
    const toggled = reduceWeatherUi(initialWeatherUiState("5d"), {
      type: "toggle-weather-range",
    });
    expect(toggled.range).toBe("7d");

    const html = render(
      <WeatherScreen
        snapshot={weatherFixtureSnapshot}
        range={toggled.range}
        theme="gruvbox"
      />,
    );

    expect(html).toContain('data-range="7d"');
    expect(html).toContain('data-day-count="7"');
    expect(html).toContain("7-day forecast");
  });

  it("renders UV bars for all three grades from hourly fixture", () => {
    const html = render(
      <WeatherScreen snapshot={weatherFixtureSnapshot} theme="gruvbox" />,
    );

    const grades = weatherFixtureSnapshot.hourly_uv.map((h) =>
      gradeUvIndex(h.index),
    );
    expect(grades).toContain("extreme");
    expect(grades).toContain("high");
    expect(grades).toContain("low");

    expect(html).toContain('data-grade="extreme"');
    expect(html).toContain('data-grade="high"');
    expect(html).toContain('data-grade="low"');
  });

  it("marks stale snapshots", () => {
    const html = render(
      <WeatherScreen
        snapshot={{ ...weatherFixtureSnapshot, stale: true }}
        theme="gruvbox"
      />,
    );
    expect(html).toContain('data-stale="true"');
    expect(html).toContain("stale");
  });
});
