import render from "preact-render-to-string";
import { describe, expect, it } from "vitest";

import { playlistFixtureSnapshot } from "./fixture";
import {
  initialPlaylistUiState,
  reducePlaylistUi,
} from "./model";
import { PlaylistScreen } from "./PlaylistScreen";

describe("PlaylistScreen", () => {
  it("renders 800×480 fixture layout matching mockup intent", () => {
    const html = render(
      <PlaylistScreen
        snapshot={playlistFixtureSnapshot}
        theme="gruvbox"
        initialSelectedIndex={1}
      />,
    );

    expect(html).toContain("pl-screen");
    expect(html).toContain('data-theme="gruvbox"');
    expect(html).toContain('data-screen="playlist"');
    expect(html).toMatch(/800px/);
    expect(html).toMatch(/480px/);
    expect(html).toContain("2:pl*");
    expect(html).toContain("playlists · 8");
    expect(html).toContain("Sink");
    expect(html).toContain("drive.exe");
    expect(html).toContain("heavy rotation");
    expect(html).toContain("kentucky basement");
    expect(html).toContain("storm watching");
    expect(html).toContain("release radar");
    expect(html).toContain("wheel walk grid");
    expect(html).toContain("press");
    expect(html).toContain("play");
    expect(html).toContain("2 / 8");
    expect(html).toContain('data-selected-index="1"');
    expect(html).toContain('data-playlist-count="8"');
    expect(html).toContain('data-cols="3"');
    expect(html).toContain('data-rows="2"');
  });

  it("highlights selected tile with play glyph", () => {
    const html = render(
      <PlaylistScreen
        snapshot={playlistFixtureSnapshot}
        initialSelectedIndex={1}
      />,
    );

    expect(html).toContain('data-playlist-id="pl-drive"');
    expect(html).toContain("▶");
    expect(html).toContain('data-selected="true"');
  });

  it("shows overflow badge when more playlists exist beyond window", () => {
    const html = render(
      <PlaylistScreen
        snapshot={playlistFixtureSnapshot}
        initialSelectedIndex={1}
      />,
    );
    // 8 total, window starts at 0 → +2 remaining after last visible
    expect(html).toContain("+2");
    expect(html).toContain('data-overflow="2"');
  });

  it("marks stale snapshots", () => {
    const html = render(
      <PlaylistScreen
        snapshot={{ ...playlistFixtureSnapshot, stale: true }}
        initialSelectedIndex={0}
      />,
    );
    expect(html).toContain('data-stale="true"');
  });

  it("wheel move updates controlled selection chrome", () => {
    let ui = initialPlaylistUiState(playlistFixtureSnapshot, 1);
    const moved = reducePlaylistUi(
      ui,
      { type: "move-playlist-selection", delta: 1 },
      playlistFixtureSnapshot,
    );
    ui = moved.state;
    const html = render(
      <PlaylistScreen snapshot={playlistFixtureSnapshot} ui={ui} />,
    );
    expect(html).toContain('data-selected-index="2"');
    expect(html).toContain("heavy rotation");
    expect(html).toContain("3 / 8");
  });

  it("play reduce result uses selected playlist id (press → play_playlist)", () => {
    const state = initialPlaylistUiState(playlistFixtureSnapshot, 1);
    const { play } = reducePlaylistUi(
      state,
      { type: "play-selected-playlist" },
      playlistFixtureSnapshot,
    );
    expect(play).toEqual({ id: "pl-drive" });
    // Wave-3 maps this to IntentV1 { name: "play_playlist", args: play }
    // and navigates to Now Playing.
  });
});
