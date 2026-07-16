/** Pure playlist grid UI — shell emits move/play; screen reduces selection. */

import type { PlaylistItemV1, PlaylistSnapshotV1 } from "../../protocol/playlist";

/** Mockup is 2 rows × 3 cols. */
export const PLAYLIST_COLS = 3;
export const PLAYLIST_ROWS = 2;
export const PLAYLIST_WINDOW = PLAYLIST_COLS * PLAYLIST_ROWS;

export type PlaylistUiState = Readonly<{
  selectedIndex: number;
}>;

/** Match shell `ShellCommand` names for wave-3 wire-up. */
export type PlaylistUiCommand =
  | Readonly<{ type: "move-playlist-selection"; delta: number }>
  | Readonly<{ type: "play-selected-playlist" }>;

/** Device → host intent args (envelope `play_playlist`). */
export type PlayPlaylistArgs = Readonly<{ id: string }>;

export type PlaylistReduceResult = Readonly<{
  state: PlaylistUiState;
  /** Set when press should start playback. */
  play: PlayPlaylistArgs | null;
}>;

export const initialPlaylistUiState = (
  snapshot: PlaylistSnapshotV1,
  selectedIndex = 0,
): PlaylistUiState => {
  const max = Math.max(0, snapshot.playlists.length - 1);
  return Object.freeze({
    selectedIndex: clamp(selectedIndex, 0, max),
  });
};

export const reducePlaylistUi = (
  state: PlaylistUiState,
  command: PlaylistUiCommand,
  snapshot: PlaylistSnapshotV1,
): PlaylistReduceResult => {
  const count = snapshot.playlists.length;

  switch (command.type) {
    case "move-playlist-selection": {
      if (command.delta === 0 || count <= 0) {
        return Object.freeze({ state, play: null });
      }
      const next = clamp(state.selectedIndex + command.delta, 0, count - 1);
      if (next === state.selectedIndex) {
        return Object.freeze({ state, play: null });
      }
      return Object.freeze({
        state: Object.freeze({ selectedIndex: next }),
        play: null,
      });
    }
    case "play-selected-playlist": {
      const item = snapshot.playlists[state.selectedIndex];
      if (!item) {
        return Object.freeze({ state, play: null });
      }
      return Object.freeze({
        state,
        play: Object.freeze({ id: item.id }),
      });
    }
    default:
      return Object.freeze({ state, play: null });
  }
};

/**
 * Window of up to `PLAYLIST_WINDOW` indices with selection visible.
 * Prefer start aligned so selection stays in view (feed-style).
 */
export const visibleIndices = (
  playlistCount: number,
  selectedIndex: number,
  windowSize: number = PLAYLIST_WINDOW,
): readonly number[] => {
  if (playlistCount <= 0) return [];
  if (playlistCount <= windowSize) {
    return Array.from({ length: playlistCount }, (_, i) => i);
  }
  let start = selectedIndex - Math.floor(windowSize / 2);
  start = clamp(start, 0, playlistCount - windowSize);
  return Array.from({ length: windowSize }, (_, i) => start + i);
};

/** Count of playlists beyond the visible window (mockup `+K` badge). */
export const overflowCount = (
  playlistCount: number,
  indices: readonly number[],
): number => {
  if (indices.length === 0) return 0;
  const lastVisible = indices[indices.length - 1]!;
  return Math.max(0, playlistCount - 1 - lastVisible);
};

export const selectedPlaylist = (
  snapshot: PlaylistSnapshotV1,
  state: PlaylistUiState,
): PlaylistItemV1 | null => snapshot.playlists[state.selectedIndex] ?? null;

/** Footer / chrome: 1-based `i / N`. */
export const positionLabel = (
  selectedIndex: number,
  playlistCount: number,
): string => {
  if (playlistCount <= 0) return "0 / 0";
  return `${selectedIndex + 1} / ${playlistCount}`;
};

export const totalLabel = (playlistCount: number): string =>
  `playlists · ${playlistCount}`;

const clamp = (n: number, min: number, max: number): number =>
  Math.min(Math.max(n, min), max);
