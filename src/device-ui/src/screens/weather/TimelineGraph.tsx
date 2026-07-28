import type { JSX } from "preact";

import { themeClassName, type ThemeName } from "../../design";
import {
  nowMarkerPct,
  selectedMarkerPct,
  selectedTimelinePoint,
  seriesHeights,
  tickMarks,
  timelinePointLabel,
  timelineSeries,
  type WeatherTimelineV1,
} from "./timelineModel";
import "./timeline.css";

export type TimelineGraphProps = Readonly<{
  timeline: WeatherTimelineV1;
  theme?: ThemeName;
  /** Hours between hour-tick labels (default 3). */
  tickEveryHours?: number;
  /** Active scrub cursor; omitted for the W6b static graph. */
  selectedIndex?: number;
}>;

const valueLabel = (value: number | null, unit: string, digits = 0): string =>
  value === null || !Number.isFinite(value)
    ? "—"
    : `${value.toFixed(digits)}${unit}`;

/**
 * Static half-hourly bar-graph timeline: three stacked series (temp / wind /
 * precip) in the UV-bar visual language, with a "now" marker and hour ticks.
 * Pure `state → view`; scrub/fade interaction is W6c.
 */
export const TimelineGraph = ({
  timeline,
  theme = "gruvbox",
  tickEveryHours = 3,
  selectedIndex,
}: TimelineGraphProps): JSX.Element => {
  const series = timelineSeries(timeline);
  const nowPct = nowMarkerPct(timeline);
  const ticks = tickMarks(timeline, tickEveryHours);
  const count = timeline.series.length;
  const selected = selectedIndex === undefined
    ? null
    : selectedTimelinePoint(timeline, selectedIndex);
  const selectedPct = selectedIndex === undefined
    ? 0
    : selectedMarkerPct(timeline, selectedIndex);

  return (
    <section
      class={`${themeClassName(theme)} wx-tl`}
      data-theme={theme}
      data-screen="weather-timeline"
      data-point-count={count}
      data-now-index={timeline.now_index}
      aria-label="Half-hourly weather timeline"
      style={{ width: "800px" }}
    >
      {selected ? (
        <header class="wx-tl__readout" data-scrub-readout="true">
          <strong>{timelinePointLabel(selected.time_local)}</strong>
          <span>temp {valueLabel(selected.temp_f, "°")}</span>
          <span>wind {valueLabel(selected.wind_mph, " mph")}</span>
          <span>precip {valueLabel(selected.precip_in, " in", 2)}</span>
        </header>
      ) : null}

      <div class="wx-tl__grid">
        {series.map((s) => {
          const heights = seriesHeights(s.values);
          return [
            <span class="wx-tl__rowlabel" key={`${s.key}-label`}>
              {s.label}
            </span>,
            <div
              class="wx-tl__track"
              data-series={s.key}
              key={`${s.key}-track`}
            >
              {s.values.map((v, i) => (
                <div class="wx-tl__bar-wrap" key={`${s.key}-${i}`}>
                  <div
                    class="wx-tl__bar"
                    data-series={s.key}
                    data-past={String(i < timeline.now_index)}
                    style={{ height: `${heights[i]}%` }}
                    title={v === null ? "no data" : s.format(v)}
                  />
                </div>
              ))}
            </div>,
          ];
        })}

        <div class="wx-tl__nowlayer" aria-hidden="true">
          <div
            class="wx-tl__nowline"
            data-now="true"
            style={{ left: `${nowPct}%` }}
          >
            <span class="wx-tl__nowdot" />
            <span class="wx-tl__nowlabel">now</span>
          </div>
        </div>

        {selected ? (
          <div class="wx-tl__scrublayer" aria-hidden="true">
            <div
              class="wx-tl__scrubline"
              data-scrub-index={selectedIndex}
              style={{ left: `${selectedPct}%` }}
            >
              <span class="wx-tl__scrubdot" />
            </div>
          </div>
        ) : null}
      </div>

      <div class="wx-tl__axis" aria-hidden="true">
        <span class="wx-tl__axis-gutter" />
        <div class="wx-tl__ticks">
          {ticks.map((t) => (
            <span
              class="wx-tl__tick"
              key={t.index}
              data-tick-index={t.index}
              style={{ left: `${t.leftPct}%` }}
            >
              {t.label}
            </span>
          ))}
        </div>
      </div>
    </section>
  );
};
