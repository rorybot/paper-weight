import type { JSX } from "preact";
import { useMemo } from "preact/hooks";

import { themeClassName, type ThemeName } from "../../design";
import type { NowPlayingSnapshotV1 } from "../../protocol/now_playing";
import {
  activeLineIndex,
  formatMs,
  lyricsFromSnapshot,
  positionLabel,
  progressMs,
  trackLabel,
  visibleLineIndices,
} from "./lyricsModel";
import "./lyrics.css";

export type LyricsOverlayProps = Readonly<{
  snapshot: NowPlayingSnapshotV1;
  /**
   * BERG paper card is the locked N3 direction (card: paper over dimmed 4a).
   * Shell already supplies the dim layer via `[data-shell-layer="overlay"]`.
   */
  theme?: ThemeName;
  /** Optional progress override for tests (defaults to track.progress_ms). */
  progressMsOverride?: number;
}>;

/**
 * Presentational lyrics overlay for shell `overlay: "lyrics"`.
 * Open/close is shell-owned (wheel press / back); this view never mutates NP state.
 */
export const LyricsOverlay = ({
  snapshot,
  theme = "berg",
  progressMsOverride,
}: LyricsOverlayProps): JSX.Element => {
  const lyrics = lyricsFromSnapshot(snapshot);
  const progress = progressMsOverride ?? progressMs(snapshot);
  const lines = lyrics?.lines ?? [];
  const active = useMemo(
    () => activeLineIndex(lines, progress),
    [lines, progress],
  );
  const indices = useMemo(
    () => visibleLineIndices(lines.length, active),
    [lines.length, active],
  );

  const track = trackLabel(snapshot);
  const pos = positionLabel(active, lines.length);
  const time = formatMs(progress);
  const empty = lines.length === 0;

  return (
    <div
      class={`${themeClassName(theme)} ly-overlay`}
      data-theme={theme}
      data-overlay="lyrics"
      data-screen="lyrics-overlay"
      data-empty={String(empty)}
      data-active-index={String(empty ? -1 : active)}
      data-line-count={String(lines.length)}
      data-stale={String(snapshot.stale)}
      role="dialog"
      aria-label="Lyrics"
      aria-modal="true"
    >
      <article class="ly-card" data-tone="paper">
        <header class="ly-card__eyebrow">
          <span class="ly-card__eyebrow-label">lyrics</span>
          <span class="ly-card__track" title={track}>
            {track}
          </span>
        </header>

        <div class="ly-card__body">
          {empty ? (
            <p class="ly-empty" data-empty-copy="true">
              no lyrics for this track
            </p>
          ) : (
            <ul
              class="ly-lines"
              data-visible-count={String(indices.length)}
              role="list"
            >
              {indices.map((index) => {
                const line = lines[index];
                if (!line) return null;
                const isActive = index === active;
                const isPast = index < active;
                return (
                  <li
                    key={`${line.t_ms}-${index}`}
                    class="ly-line"
                    data-active={String(isActive)}
                    data-past={String(isPast)}
                    data-line-index={String(index)}
                    aria-current={isActive ? "true" : undefined}
                  >
                    {line.text}
                  </li>
                );
              })}
            </ul>
          )}
        </div>

        <footer class="ly-card__footer">
          <span data-hint="dismiss">
            <strong>press</strong> / back dismiss
          </span>
          {!empty ? (
            <span class="ly-card__pos" data-position="true">
              {pos}
            </span>
          ) : null}
          <span class="ly-card__time" data-progress="true">
            {time}
          </span>
        </footer>
      </article>
    </div>
  );
};
