import type { JSX } from "preact";
import { useEffect, useMemo, useRef, useState } from "preact/hooks";

import { designTokens } from "../../design";
import type { NowPlayingSnapshotV1 } from "../../protocol/now_playing";
import {
  consumeNowPlayingCommand,
  initialNowPlayingUiState,
  reconcileNowPlayingUiState,
  type NowPlayingUiCommand,
  type NowPlayingUiState,
  type PlayQueueItemArgs,
  buildNowPlayingViewModel,
} from "./model";
import "./now-playing.css";

export type NowPlayingScreenProps = Readonly<{
  snapshot: NowPlayingSnapshotV1;
  ui?: NowPlayingUiState;
  command?: NowPlayingUiCommand | null;
  onUiChange?: (state: NowPlayingUiState) => void;
  onPlaySelected?: (args: PlayQueueItemArgs) => void;
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
  ui: controlledUi,
  command = null,
  onUiChange,
  onPlaySelected,
}: NowPlayingScreenProps): JSX.Element => {
  const [internal, setInternal] = useState(() =>
    initialNowPlayingUiState(snapshot),
  );
  const consumedCommand = useRef<NowPlayingUiCommand | null>(null);
  const state = reconcileNowPlayingUiState(controlledUi ?? internal, snapshot);

  useEffect(() => {
    if (
      controlledUi === undefined &&
      state.selectedIndex !== internal.selectedIndex
    ) {
      setInternal(state);
    }
  }, [controlledUi, state, internal]);

  useEffect(() => {
    const consumption = consumeNowPlayingCommand(
      consumedCommand.current,
      command,
      state,
      snapshot,
    );
    consumedCommand.current = consumption.consumedCommand;
    const { state: next, play } = consumption.result;
    if (next.selectedIndex !== state.selectedIndex) {
      if (controlledUi === undefined) setInternal(next);
      onUiChange?.(next);
    }
    if (play) onPlaySelected?.(play);
  }, [command, snapshot, state, controlledUi, onUiChange, onPlaySelected]);

  const view = useMemo(
    () => buildNowPlayingViewModel(snapshot, state.selectedIndex),
    [snapshot, state.selectedIndex],
  );
  const activeQueueItem = view.queue.find((item) => item.selected);

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
          <span>3:ph</span>
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

          <div class="np-queue-controls" aria-label="Queue controls">
            <span>wheel: select queue</span>
            <span>press: play</span>
          </div>
        </section>

        <aside class="np-queue" data-queue-mode="interactive" aria-label="Up next queue">
          <h2>QUEUE ↓</h2>
          <ol
            role="listbox"
            aria-label="Up next"
            aria-activedescendant={
              activeQueueItem ? `np-queue-item-${activeQueueItem.id}` : undefined
            }
          >
            {view.queue.map((item) => (
              <li
                id={`np-queue-item-${item.id}`}
                key={item.id}
                role="option"
                aria-selected={item.selected}
                data-queue-id={item.id}
                data-queue-index={String(item.index)}
                data-selected={String(item.selected)}
              >
                <span class="np-queue__title">{item.selected ? "▸ " : ""}{item.title}</span>
                <span class="np-queue__artist">{item.artist}</span>
              </li>
            ))}
          </ol>
          <p class="np-queue__more">
            {view.queueRemainder > 0
              ? `${view.queuePosition} · +${view.queueRemainder} more`
              : view.queuePosition}
          </p>
        </aside>
      </main>

      <footer class="np-footer">
        <span><strong>press:</strong> play</span>
        <span><strong>long press:</strong> lyrics</span>
        <span><strong>◂ back</strong> home</span>
        <span class="np-footer__transport">transport: flagged off</span>
      </footer>
    </section>
  );
};
