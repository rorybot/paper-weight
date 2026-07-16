import type { JSX } from "preact";
import { useEffect, useMemo, useState } from "preact/hooks";

import { themeClassName, type ThemeName } from "../../design";
import type {
  PlaylistItemV1,
  PlaylistSnapshotV1,
} from "../../protocol/playlist";
import {
  initialPlaylistUiState,
  overflowCount,
  positionLabel,
  reducePlaylistUi,
  totalLabel,
  visibleIndices,
  type PlayPlaylistArgs,
  type PlaylistUiCommand,
  type PlaylistUiState,
} from "./model";
import "./playlist.css";

export type PlaylistScreenProps = Readonly<{
  snapshot: PlaylistSnapshotV1;
  /** Gruvbox TUI matches mockup 4c (D3 may reskin later). */
  theme?: ThemeName;
  /** Controlled UI; when set, component is controlled. */
  ui?: PlaylistUiState;
  initialSelectedIndex?: number;
  /**
   * Shell commands: `move-playlist-selection` / `play-selected-playlist`.
   * Wave 3 wires from ShellApp; tests pass one-shot commands.
   */
  command?: PlaylistUiCommand | null;
  onUiChange?: (state: PlaylistUiState) => void;
  /**
   * Press play: host intent `play_playlist` + wave-3 navigates to Now Playing.
   */
  onPlaySelected?: (
    item: PlaylistItemV1,
    args: PlayPlaylistArgs,
  ) => void;
}>;

const Tile = ({
  item,
  selected,
  showOverflow,
  overflow,
}: {
  readonly item: PlaylistItemV1;
  readonly selected: boolean;
  readonly showOverflow: boolean;
  readonly overflow: number;
}): JSX.Element => (
  <div
    class="pl-tile"
    data-selected={String(selected)}
    data-playlist-id={item.id}
    role="option"
    aria-selected={selected}
  >
    <div class="pl-tile__cover" data-selected={String(selected)}>
      {selected ? (
        <span class="pl-tile__play" aria-hidden="true">
          ▶
        </span>
      ) : null}
      {showOverflow && overflow > 0 ? (
        <span class="pl-tile__overflow" data-overflow={String(overflow)}>
          +{overflow}
        </span>
      ) : null}
    </div>
    <p class="pl-tile__label" data-selected={String(selected)}>
      {item.name}
    </p>
  </div>
);

export const PlaylistScreen = ({
  snapshot,
  theme = "gruvbox",
  ui: controlledUi,
  initialSelectedIndex = 0,
  command = null,
  onUiChange,
  onPlaySelected,
}: PlaylistScreenProps): JSX.Element => {
  const [internal, setInternal] = useState(() =>
    initialPlaylistUiState(snapshot, initialSelectedIndex),
  );

  const state = controlledUi ?? internal;

  useEffect(() => {
    if (!command) return;
    setInternal((prev) => {
      const start = controlledUi ?? prev;
      const { state: next, play } = reducePlaylistUi(start, command, snapshot);
      if (next.selectedIndex !== start.selectedIndex) {
        onUiChange?.(next);
      }
      if (play) {
        const item = snapshot.playlists[next.selectedIndex];
        if (item) onPlaySelected?.(item, play);
      }
      return next;
    });
  }, [command, snapshot, controlledUi, onUiChange, onPlaySelected]);

  const indices = useMemo(
    () => visibleIndices(snapshot.playlists.length, state.selectedIndex),
    [snapshot.playlists.length, state.selectedIndex],
  );

  const overflow = overflowCount(snapshot.playlists.length, indices);
  const pos = positionLabel(state.selectedIndex, snapshot.playlists.length);
  const count = totalLabel(snapshot.playlists.length);
  const lastIdx = indices[indices.length - 1];

  return (
    <main
      class={`${themeClassName(theme)} pl-screen`}
      data-theme={theme}
      data-screen="playlist"
      data-stale={String(snapshot.stale)}
      data-selected-index={String(state.selectedIndex)}
      data-playlist-count={String(snapshot.playlists.length)}
      style={{ width: "800px", height: "480px" }}
    >
      <header class="pl-topbar">
        <span>[cthing]</span>
        <nav class="pl-topbar__presets" aria-label="Presets">
          <span>1:np</span>
          <span data-active="true">2:pl*</span>
          <span>3:wx</span>
          <span>4:fd</span>
        </nav>
        <span class="pl-topbar__count">{count}</span>
      </header>

      <section class="pl-main" aria-label="Playlist grid">
        <div
          class="pl-grid"
          role="listbox"
          aria-label="Playlists"
          data-visible-count={String(indices.length)}
          data-cols="3"
          data-rows="2"
        >
          {indices.map((index) => {
            const item = snapshot.playlists[index];
            if (!item) return null;
            const selected = index === state.selectedIndex;
            const isLastVisible = index === lastIdx;
            return (
              <Tile
                key={item.id}
                item={item}
                selected={selected}
                showOverflow={isLastVisible}
                overflow={overflow}
              />
            );
          })}
        </div>
      </section>

      <footer class="pl-footer">
        <span data-hint="wheel">◉ wheel walk grid</span>
        <span data-hint="press">
          <strong>press</strong> play
        </span>
        <span class="pl-footer__pos" data-position="true">
          {pos}
        </span>
      </footer>
    </main>
  );
};
