import render from "preact-render-to-string";
import { describe, expect, it } from "vitest";

import {
  nowPlayingFixtureNoLyrics,
  nowPlayingFixtureSnapshot,
} from "./fixture";
import { LyricsOverlay } from "./LyricsOverlay";
import { activeLineIndex } from "./lyricsModel";

describe("LyricsOverlay", () => {
  it("renders BERG paper card with track + active line from fixture progress", () => {
    const html = render(
      <LyricsOverlay snapshot={nowPlayingFixtureSnapshot} theme="berg" />,
    );

    expect(html).toContain("ly-overlay");
    expect(html).toContain('data-theme="berg"');
    expect(html).toContain('data-overlay="lyrics"');
    expect(html).toContain('data-empty="false"');
    expect(html).toContain("lyrics");
    expect(html).toContain("Galactic · Tenure");
    expect(html).toContain("your name is still a station");
    expect(html).toContain('data-active="true"');
    expect(html).toContain("press");
    expect(html).toContain("back dismiss");
    expect(html).toContain("1:22");

    const active = activeLineIndex(
      nowPlayingFixtureSnapshot.lyrics!.lines,
      82_000,
    );
    expect(html).toContain(`data-active-index="${active}"`);
    expect(html).toContain("6/10");
  });

  it("shows empty copy when lyrics payload is null", () => {
    const html = render(
      <LyricsOverlay snapshot={nowPlayingFixtureNoLyrics} />,
    );
    expect(html).toContain('data-empty="true"');
    expect(html).toContain("no lyrics for this track");
    expect(html).toContain('data-active-index="-1"');
  });

  it("re-highlights when progress override advances", () => {
    const early = render(
      <LyricsOverlay
        snapshot={nowPlayingFixtureSnapshot}
        progressMsOverride={0}
      />,
    );
    expect(early).toContain('data-active-index="0"');
    expect(early).toContain("tape hiss, then a door");

    const late = render(
      <LyricsOverlay
        snapshot={nowPlayingFixtureSnapshot}
        progressMsOverride={150_000}
      />,
    );
    expect(late).toContain('data-active-index="9"');
    expect(late).toContain("and the night says stay");
  });

  it("marks stale snapshots without changing layout contract", () => {
    const html = render(
      <LyricsOverlay
        snapshot={{ ...nowPlayingFixtureSnapshot, stale: true }}
      />,
    );
    expect(html).toContain('data-stale="true"');
    expect(html).toContain("ly-card");
  });
});
