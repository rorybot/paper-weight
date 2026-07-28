import type { JSX } from "preact";
import { useEffect, useMemo, useRef, useState } from "preact/hooks";

import { themeClassName, type ThemeName } from "../../design";
import type { WeatherDayV1, WeatherSnapshotV1 } from "../../protocol/weather";
import {
  conditionGlyph,
  gradeUvIndex,
  hourLabel,
  initialWeatherUiState,
  reconcileWeatherUiState,
  reduceWeatherUi,
  returnWeatherToCurrent,
  WEATHER_IDLE_MS,
  weekdayShort,
  type WeatherUiCommand,
  type WeatherUiState,
} from "./model";
import { TimelineGraph } from "./TimelineGraph";
import "./weather.css";

export type WeatherScreenProps = Readonly<{
  snapshot: WeatherSnapshotV1;
  theme?: ThemeName;
  /** Controlled UI for focused rendering/tests; omit for shell-owned commands. */
  ui?: WeatherUiState;
  command?: WeatherUiCommand | null;
  onUiChange?: (state: WeatherUiState) => void;
  idleMs?: number;
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

const CurrentConditions = ({
  snapshot,
}: {
  readonly snapshot: WeatherSnapshotV1;
}): JSX.Element => {
  const hourly = useMemo(
    () => snapshot.hourly_uv.slice(0, 10),
    [snapshot.hourly_uv],
  );

  return (
    <>
      <header class="wx-topbar">
        <span>[cthing]</span>
        <nav class="wx-topbar__presets" aria-label="Presets">
          <span>1:np</span>
          <span data-active="true">2:wx*</span>
          <span>3:ph</span>
          <span>4:et</span>
        </nav>
        <span class="wx-topbar__loc">{snapshot.location_label}</span>
      </header>

      <section class="wx-uv" aria-label="Walk UV band" data-uv-grade={snapshot.uv.grade}>
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
          {(["extreme", "high", "low"] as const).map((grade) => (
            <div class="wx-uv__legend-row" key={grade}>
              <span class="wx-uv__swatch" data-grade={grade} />
              {grade}
            </div>
          ))}
        </div>
      </section>

      <section class="wx-main" aria-label="Current conditions and forecast">
        <div class="wx-current">
          <SunIcon />
          <p class="wx-current__temp">{Math.round(snapshot.current.temp_f)}°</p>
          <p class="wx-current__summary">{snapshot.current.summary}</p>
          <p class="wx-current__meta">
            uv {snapshot.uv.index} · {snapshot.uv.grade}
            {snapshot.stale ? " · stale" : ""}
          </p>
        </div>

        <div class="wx-days" data-day-count={snapshot.days5.length} aria-label="5-day forecast">
          {snapshot.days5.map((day) => (
            <DayRow key={day.date} day={day} />
          ))}
        </div>
      </section>

      <footer class="wx-footer">
        <span>◉ wheel scrub</span>
        <span>−12h ↔ now ↔ +24h</span>
        <span class="wx-footer__src">open-meteo</span>
      </footer>
    </>
  );
};

export const WeatherScreen = ({
  snapshot,
  theme = "gruvbox",
  ui: controlledUi,
  command = null,
  onUiChange,
  idleMs = WEATHER_IDLE_MS,
}: WeatherScreenProps): JSX.Element => {
  const timeline = snapshot.timeline;
  const [internal, setInternal] = useState(() => initialWeatherUiState(timeline));
  const idleTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const state = reconcileWeatherUiState(controlledUi ?? internal, timeline);

  useEffect(() => {
    if (controlledUi !== undefined) return;
    setInternal((previous) => reconcileWeatherUiState(previous, timeline));
  }, [controlledUi, timeline]);

  useEffect(() => {
    if (!command) return;

    setInternal((previous) => {
      const start = reconcileWeatherUiState(controlledUi ?? previous, timeline);
      const next = reduceWeatherUi(start, command, timeline);
      if (next !== start) onUiChange?.(next);
      return next;
    });

    if (idleTimer.current !== null) clearTimeout(idleTimer.current);
    idleTimer.current = setTimeout(() => {
      setInternal((previous) => {
        const start = reconcileWeatherUiState(controlledUi ?? previous, timeline);
        const next = returnWeatherToCurrent(start, timeline);
        if (next !== start) onUiChange?.(next);
        return next;
      });
      idleTimer.current = null;
    }, idleMs);

    return () => {
      if (idleTimer.current !== null) {
        clearTimeout(idleTimer.current);
        idleTimer.current = null;
      }
    };
  }, [command, controlledUi, idleMs, onUiChange, timeline]);

  const timelineActive = state.mode === "timeline";

  return (
    <main
      class={`${themeClassName(theme)} wx-screen`}
      data-theme={theme}
      data-stale={String(snapshot.stale)}
      data-screen="weather"
      data-mode={state.mode}
      data-scrub-index={String(state.scrubIndex)}
      style={{ width: "800px", height: "480px" }}
    >
      <div
        class="wx-view wx-view--current"
        data-active={String(!timelineActive)}
        aria-hidden={timelineActive}
      >
        <CurrentConditions snapshot={snapshot} />
      </div>

      <div
        class="wx-view wx-view--timeline"
        data-active={String(timelineActive)}
        aria-hidden={!timelineActive}
      >
        <header class="wx-timeline-topbar">
          <span>[cthing]</span>
          <strong>weather timeline</strong>
          <span>{snapshot.location_label}</span>
        </header>
        <TimelineGraph timeline={timeline} theme={theme} selectedIndex={state.scrubIndex} />
        <footer class="wx-timeline-footer">
          <span>◉ wheel · one point per detent</span>
          <span>current conditions return after 7s idle</span>
        </footer>
      </div>
    </main>
  );
};
