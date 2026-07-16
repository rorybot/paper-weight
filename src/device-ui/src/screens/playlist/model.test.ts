import { describe, expect, it } from "vitest";

import { playlistFixtureSnapshot } from "./fixture";
import {
  initialPlaylistUiState,
  overflowCount,
  PLAYLIST_WINDOW,
  positionLabel,
  reducePlaylistUi,
  selectedPlaylist,
  totalLabel,
  visibleIndices,
} from "./model";

const snap = playlistFixtureSnapshot;

describe("reducePlaylistUi", () => {
  it("walks selection and clamps (wheel)", () => {
    let s = initialPlaylistUiState(snap, 1);
    let r = reducePlaylistUi(
      s,
      { type: "move-playlist-selection", delta: 1 },
      snap,
    );
    expect(r.play).toBeNull();
    expect(r.state.selectedIndex).toBe(2);
    s = r.state;

    r = reducePlaylistUi(
      s,
      { type: "move-playlist-selection", delta: 99 },
      snap,
    );
    expect(r.state.selectedIndex).toBe(snap.playlists.length - 1);

    r = reducePlaylistUi(
      r.state,
      { type: "move-playlist-selection", delta: -99 },
      snap,
    );
    expect(r.state.selectedIndex).toBe(0);
  });

  it("play-selected-playlist returns play args for selected id", () => {
    const s = initialPlaylistUiState(snap, 1);
    const r = reducePlaylistUi(s, { type: "play-selected-playlist" }, snap);
    expect(r.state.selectedIndex).toBe(1);
    expect(r.play).toEqual({ id: "pl-drive" });
    expect(selectedPlaylist(snap, s)?.name).toBe("drive.exe");
  });

  it("play on empty list is a no-op", () => {
    const empty = Object.freeze({
      as_of: snap.as_of,
      stale: false,
      playlists: Object.freeze([] as const),
    });
    const s = initialPlaylistUiState(empty, 0);
    const r = reducePlaylistUi(s, { type: "play-selected-playlist" }, empty);
    expect(r.play).toBeNull();
  });
});

describe("visibleIndices / overflow", () => {
  it("shows up to PLAYLIST_WINDOW with selection visible", () => {
    expect(PLAYLIST_WINDOW).toBe(6);
    expect(visibleIndices(6, 0)).toEqual([0, 1, 2, 3, 4, 5]);
    expect(visibleIndices(snap.playlists.length, 1).length).toBe(
      PLAYLIST_WINDOW,
    );
    expect(visibleIndices(snap.playlists.length, 1)).toContain(1);

    const nearEnd = visibleIndices(
      snap.playlists.length,
      snap.playlists.length - 1,
    );
    expect(nearEnd).toContain(snap.playlists.length - 1);
    expect(nearEnd.length).toBe(PLAYLIST_WINDOW);
  });

  it("overflowCount is remaining after last visible", () => {
    const atStart = visibleIndices(8, 1);
    // window [0..5] → remaining after index 5 = 2
    expect(overflowCount(8, atStart)).toBe(2);

    const atEnd = visibleIndices(8, 7);
    expect(overflowCount(8, atEnd)).toBe(0);
  });
});

describe("labels", () => {
  it("formats position and total chrome", () => {
    expect(positionLabel(1, 8)).toBe("2 / 8");
    expect(positionLabel(0, 0)).toBe("0 / 0");
    expect(totalLabel(8)).toBe("playlists · 8");
  });
});
