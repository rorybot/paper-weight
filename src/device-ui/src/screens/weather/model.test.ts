import { describe, expect, it } from "vitest";

import type { WeatherTimelineV1 } from "../../protocol/weather";
import { weatherTimelineFixture } from "./timelineFixture";
import {
  conditionGlyph,
  gradeUvIndex,
  hourLabel,
  initialWeatherUiState,
  reconcileWeatherUiState,
  reduceWeatherUi,
  returnWeatherToCurrent,
  WEATHER_IDLE_MS,
  weatherIdleElapsed,
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

describe("weather timeline scrub state", () => {
  it("starts at now and moves one adjacent point per tick", () => {
    const current = initialWeatherUiState(weatherTimelineFixture);
    expect(current).toEqual({ mode: "current", scrubIndex: 24 });

    const first = reduceWeatherUi(
      current,
      { type: "scrub-weather-timeline", delta: 1 },
      weatherTimelineFixture,
    );
    expect(first).toEqual({ mode: "timeline", scrubIndex: 25 });

    const next = reduceWeatherUi(
      first,
      { type: "scrub-weather-timeline", delta: 2 },
      weatherTimelineFixture,
    );
    expect(next).toEqual({ mode: "timeline", scrubIndex: 27 });
  });

  it("clamps at both ends and ignores zero delta", () => {
    const current = initialWeatherUiState(weatherTimelineFixture);
    expect(
      reduceWeatherUi(
        current,
        { type: "scrub-weather-timeline", delta: -99 },
        weatherTimelineFixture,
      ).scrubIndex,
    ).toBe(0);
    expect(
      reduceWeatherUi(
        current,
        { type: "scrub-weather-timeline", delta: 99 },
        weatherTimelineFixture,
      ).scrubIndex,
    ).toBe(weatherTimelineFixture.series.length - 1);
    expect(
      reduceWeatherUi(
        current,
        { type: "scrub-weather-timeline", delta: 0 },
        weatherTimelineFixture,
      ),
    ).toBe(current);
  });

  it("reconciles partial data and returns idle state to the current sample", () => {
    const partial: WeatherTimelineV1 = {
      step_minutes: 30,
      now_index: 2,
      series: weatherTimelineFixture.series.slice(0, 4),
    };
    const reconciled = reconcileWeatherUiState(
      { mode: "timeline", scrubIndex: 72 },
      partial,
    );
    expect(reconciled).toEqual({ mode: "timeline", scrubIndex: 3 });
    expect(returnWeatherToCurrent(reconciled, partial)).toEqual({
      mode: "current",
      scrubIndex: 2,
    });
  });

  it("stays on current conditions when no timeline points exist", () => {
    const empty: WeatherTimelineV1 = { step_minutes: 30, now_index: 0, series: [] };
    const current = initialWeatherUiState(empty);
    expect(
      reduceWeatherUi(
        current,
        { type: "scrub-weather-timeline", delta: 1 },
        empty,
      ),
    ).toBe(current);
  });

  it("returns only once the full seven-second idle boundary elapses", () => {
    expect(WEATHER_IDLE_MS).toBe(7_000);
    expect(weatherIdleElapsed(6_999)).toBe(false);
    expect(weatherIdleElapsed(7_000)).toBe(true);
  });
});

describe("weekdayShort", () => {
  it("returns lowercase weekday for ISO dates", () => {
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
