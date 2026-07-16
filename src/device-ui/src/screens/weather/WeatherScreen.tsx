import type { JSX } from "preact";
import { useEffect, useMemo, useState } from "preact/hooks";

import { themeClassName, type ThemeName } from "../../design";
import type { WeatherDayV1, WeatherSnapshotV1 } from "../../protocol/weather";
import {
  conditionGlyph,
  gradeUvIndex,
  hourLabel,
  initialWeatherUiState,
  reduceWeatherUi,
  weekdayShort,
  type WeatherRange,
  type WeatherUiCommand,
} from "./model";
import "./weather.css";

export type WeatherScreenProps = Readonly<{
  snapshot: WeatherSnapshotV1;
  theme?: ThemeName;
  /** Controlled range; when set, component is controlled. */
  range?: WeatherRange;
  initialRange?: WeatherRange;
  /**
   * Optional command stream from shell (e.g. `toggle-weather-range`).
   * Wave 3 wires this from ShellApp; tests pass one-shot commands via key change.
   */
  command?: WeatherUiCommand | null;
  /** Fires when range changes (controlled or internal). */
  onRangeChange?: (range: WeatherRange) => void;
}>;

const SunIcon = (): JSX.Element => (
  <svg
    class="wx-current__icon"
    viewBox="0 0 64 64"
    aria-hidden="true"
    focusable="false"
  >
    <circle cx="32" cy="32" r="12" fill="none" stroke="currentColor" stroke-width="2.5" />
    {Array.from({ length: 8 }, (_, i) => {
      const a = (i * Math.PI) / 4;
      const x1 = 32 + Math.cos(a) * 18;
      const y1 = 32 + Math.sin(a) * 18;
      const x2 = 32 + Math.cos(a) * 26;
      const y2 = 32 + Math.sin(a) * 26;
      return (
        <line
          key={i}
          x1={x1}
          y1={y1}
          x2={x2}
          y2={y2}
          stroke="currentColor"
          stroke-width="2.5"
          stroke-linecap="round"
        />
      );
    })}
  </svg>
);

const DayRow = ({ day }: { readonly day: WeatherDayV1 }): JSX.Element => (
  <div class="wx-day" data-date={day.date}>
    <span class="wx-day__dow">{weekdayShort(day.date)}</span>
    <span class="wx-day__glyph" aria-hidden="true">
      {conditionGlyph(day.summary)}
    </span>
    <span class="wx-day__summary">{day.summary}</span>
    <span class="wx-day__temps">
      <strong>{Math.round(day.high_f)}</strong>
      <span>{Math.round(day.low_f)}</span>
    </span>
  </div>
);

const uvBarHeightPct = (index: number): number => {
  const capped = Math.min(Math.max(index, 0), 12);
  return Math.max(10, Math.round((capped / 12) * 100));
};

export const WeatherScreen = ({
  snapshot,
  theme = "gruvbox",
  range: controlledRange,
  initialRange = "5d",
  command = null,
  onRangeChange,
}: WeatherScreenProps): JSX.Element => {
  const [internal, setInternal] = useState(() =>
    initialWeatherUiState(initialRange),
  );

  const range = controlledRange ?? internal.range;

  useEffect(() => {
    if (!command) return;
    setInternal((prev) => {
      const next = reduceWeatherUi(prev, command);
      if (next.range !== prev.range) {
        onRangeChange?.(next.range);
      }
      return next;
    });
  }, [command, onRangeChange]);

  const days = range === "7d" ? snapshot.days7 : snapshot.days5;
  const hourly = useMemo(
    () => snapshot.hourly_uv.slice(0, 10),
    [snapshot.hourly_uv],
  );

  return (
    <main
      class={`${themeClassName(theme)} wx-screen`}
      data-theme={theme}
      data-range={range}
      data-stale={String(snapshot.stale)}
      data-screen="weather"
      style={{ width: "800px", height: "480px" }}
    >
      <header class="wx-topbar">
        <span>[cthing]</span>
        <nav class="wx-topbar__presets" aria-label="Presets">
          <span>1:np</span>
          <span data-active="true">2:wx*</span>
          <span>3:fd</span>
          <span>4:et</span>
        </nav>
        <span class="wx-topbar__loc">{snapshot.location_label}</span>
      </header>

      <section
        class="wx-uv"
        aria-label="Walk UV band"
        data-uv-grade={snapshot.uv.grade}
      >
        <div>
          <p class="wx-uv__label">
            WALK? <span>UV · next 5h · 30-min</span>
          </p>
          <p class="wx-uv__quote">“{snapshot.walk_verdict}”</p>
        </div>

        <div class="wx-uv__chart" role="img" aria-label="Hourly UV index">
          {hourly.map((h) => {
            const grade = gradeUvIndex(h.index);
            return (
              <div class="wx-uv__bar-wrap" key={`${h.hour_local}-${h.index}`}>
                <div
                  class="wx-uv__bar"
                  data-grade={grade}
                  data-uv-index={h.index}
                  style={{ height: `${uvBarHeightPct(h.index)}%` }}
                  title={`UV ${h.index}`}
                />
                <span class="wx-uv__hour">{hourLabel(h.hour_local)}</span>
              </div>
            );
          })}
        </div>

        <div class="wx-uv__legend" aria-label="UV legend">
          <div class="wx-uv__legend-row">
            <span class="wx-uv__swatch" data-grade="extreme" />
            extreme
          </div>
          <div class="wx-uv__legend-row">
            <span class="wx-uv__swatch" data-grade="high" />
            high
          </div>
          <div class="wx-uv__legend-row">
            <span class="wx-uv__swatch" data-grade="low" />
            low
          </div>
        </div>
      </section>

      <section class="wx-main" aria-label="Conditions and forecast">
        <div class="wx-current">
          <SunIcon />
          <p class="wx-current__temp">{Math.round(snapshot.current.temp_f)}°</p>
          <p class="wx-current__summary">{snapshot.current.summary}</p>
          <p class="wx-current__meta">
            uv {snapshot.uv.index} · {snapshot.uv.grade}
            {snapshot.stale ? " · stale" : ""}
          </p>
        </div>

        <div
          class="wx-days"
          data-day-count={days.length}
          aria-label={range === "7d" ? "7-day forecast" : "5-day forecast"}
        >
          {days.map((day) => (
            <DayRow key={day.date} day={day} />
          ))}
        </div>
      </section>

      <footer class="wx-footer">
        <span>◉ wheel</span>
        <span class="wx-footer__range" data-range={range}>
          <span data-active={String(range === "5d")}>today</span>
          {" ↔ "}
          <span data-active={String(range === "7d")}>7-day</span>
        </span>
        <span class="wx-footer__src">nws · openuv</span>
      </footer>
    </main>
  );
};
