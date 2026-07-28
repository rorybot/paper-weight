import render from "preact-render-to-string";
import { describe, expect, it } from "vitest";

import { weatherFixtureSnapshot } from "./fixture";
import { gradeUvIndex } from "./model";
import { WeatherScreen } from "./WeatherScreen";

describe("WeatherScreen", () => {
  it("renders the current 800×480 fixture view", () => {
    const html = render(
      <WeatherScreen snapshot={weatherFixtureSnapshot} theme="gruvbox" />,
    );

    expect(html).toContain('data-screen="weather"');
    expect(html).toContain('data-theme="gruvbox"');
    expect(html).toContain('data-mode="current"');
    expect(html).toMatch(/800px/);
    expect(html).toMatch(/480px/);
    expect(html).toContain("exampleville, ex");
    expect(html).toContain("92°");
    expect(html).toContain("sunny");
    expect(html).toContain("WALK?");
    expect(html).toContain("good window right now");
    expect(html).toContain('data-day-count="5"');
    expect(html).toContain("wheel scrub");
    expect(html).not.toContain("7-day");
  });

  it("crossfades the whole view to a controlled scrub position", () => {
    const html = render(
      <WeatherScreen
        snapshot={weatherFixtureSnapshot}
        ui={{ mode: "timeline", scrubIndex: 25 }}
        theme="gruvbox"
      />,
    );

    expect(html).toContain('data-mode="timeline"');
    expect(html).toContain('class="wx-view wx-view--current" data-active="false"');
    expect(html).toContain('class="wx-view wx-view--timeline" data-active="true"');
    expect(html).toContain('data-screen="weather-timeline"');
    expect(html).toContain('data-scrub-index="25"');
    expect(html).toContain('data-scrub-readout="true"');
    expect(html).toContain("temp ");
    expect(html).toContain("wind ");
    expect(html).toContain("precip ");
    expect(html).toContain("return after 7s idle");
  });

  it("renders UV bars for all three grades", () => {
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
