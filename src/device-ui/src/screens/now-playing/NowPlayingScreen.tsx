import type { JSX } from "preact";

import { designTokens } from "../../design";
import type { NowPlayingSnapshotV1 } from "../../protocol/now_playing";
import { buildNowPlayingViewModel } from "./model";
import "./now-playing.css";

export type NowPlayingScreenProps = Readonly<{
  snapshot: NowPlayingSnapshotV1;
}>;

const screenTheme = (): string => {
  const { colors, fonts } = designTokens.gruvbox;
  return [
    `--np-desk:${colors.desk}`,
    `--np-surface:${colors.surface}`,
    `--np-paper:${colors.paper}`,
    `--np-muted:${colors.muted}`,
    `--np-accent:${colors.accent}`,
    `--np-positive:${colors.positive}`,
    `--np-mono:${fonts.mono}`,
  ].join(";");
};

export const NowPlayingScreen = ({
  snapshot,
}: NowPlayingScreenProps): JSX.Element => {
  const view = buildNowPlayingViewModel(snapshot);

  return (
    <section
      class="np-screen"
      data-screen="now-playing"
      data-viewport="800x480"
      data-stale={String(view.stale)}
      style={screenTheme()}
    >
      <header class="np-topbar">
        <strong class="np-brand">[cthing]</strong>
        <nav class="np-presets" aria-label="Preset screens">
          <span data-active="true">1:np*</span>
          <span>2:wx</span>
          <span>3:fd</span>
          <span>4:et</span>
        </nav>
        <time dateTime={snapshot.as_of}>{view.clock}</time>
      </header>

      <main class="np-layout">
        <section class="np-art-pane" aria-label="Album artwork and Spotify status">
          {view.track.artSource ? (
            <img
              class="np-art"
              src={view.track.artSource}
              alt={`${view.track.title} album art`}
            />
          ) : (
            <div class="np-art np-art--empty" role="img" aria-label="Dithered album art unavailable" />
          )}
          <p class="np-connection" data-stale={String(view.stale)}>
            {view.connectionLabel}
          </p>
          <p class="np-device">read-only snapshot</p>
        </section>

        <section class="np-track-pane" aria-label="Current track">
          <div class="np-track-copy">
            <h1>{view.track.title}</h1>
            <p class="np-artist">{view.track.artist}</p>
            <p class="np-album">{view.track.album}</p>
          </div>

          <div class="np-progress" aria-label={`Track progress ${view.track.elapsed} of ${view.track.duration}`}>
            <div class="np-progress__times">
              <span>{view.track.elapsed}</span>
              <span>{view.track.duration}</span>
            </div>
            <div class="np-progress__rail" aria-hidden="true">
              <span style={{ width: `${view.track.progressPercent}%` }} />
            </div>
          </div>

          <div class="np-volume" aria-label={`Volume ${view.volume.level}%`}>
            <span>↻ wheel = volume</span>
            <span class="np-volume__cells" aria-hidden="true">
              {view.volume.segments.map((filled, index) => (
                <i key={index} data-filled={String(filled)} />
              ))}
            </span>
          </div>
        </section>

        <aside class="np-queue" data-queue-mode="display-only" aria-label="Up next queue, display only">
          <h2>QUEUE ↓</h2>
          <ol>
            {view.queue.map((item) => (
              <li key={`${item.title}-${item.artist}`} data-selected={String(item.selected)}>
                <span class="np-queue__title">{item.selected ? "▸ " : ""}{item.title}</span>
                <span class="np-queue__artist">{item.artist}</span>
              </li>
            ))}
          </ol>
          <p class="np-queue__more">
            {view.queueRemainder > 0 ? `+${view.queueRemainder} more` : "queue ends here"}
          </p>
        </aside>
      </main>

      <footer class="np-footer">
        <span><strong>press</strong> lyrics</span>
        <span><strong>◂ back</strong> home</span>
        <span class="np-footer__transport">transport: flagged off</span>
      </footer>
    </section>
  );
};
