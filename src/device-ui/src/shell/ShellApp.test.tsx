import render from "preact-render-to-string";
import { describe, expect, it } from "vitest";

import { nowPlayingFixtureSnapshot } from "../screens/now-playing";
import { commandsToIntentRequests, renderShellOverlay, ShellApp } from "./ShellApp";
import type { ScreenId } from "./model";

const REAL_SCREEN_MARKERS: Readonly<Record<Exclude<ScreenId, "etymology">, string>> = {
  home: 'data-screen="home"',
  "now-playing": 'data-screen="now-playing"',
  weather: 'data-screen="weather"',
  playlist: 'data-screen="playlist"',
  feed: 'data-screen="feed"',
  photo: 'data-screen="photo"',
  settings: 'data-screen="settings"',
};

describe("ShellApp screens", () => {
  for (const [screen, marker] of Object.entries(REAL_SCREEN_MARKERS)) {
    it(`renders the real component for "${screen}" from fixture data`, () => {
      const html = render(
        <ShellApp bridgeUrl={null} initialScreen={screen as ScreenId} />,
      );
      expect(html).toContain(marker);
    });
  }

  it("still placeholders etymology (no E2 screen yet)", () => {
    const html = render(<ShellApp bridgeUrl={null} initialScreen="etymology" />);
    expect(html).toContain('data-placeholder="etymology"');
  });
});

describe("renderShellOverlay", () => {
  it("renders the real lyrics overlay from the now-playing snapshot", () => {
    const html = render(
      <>{renderShellOverlay("lyrics", nowPlayingFixtureSnapshot)}</>,
    );
    expect(html).toContain('data-overlay="lyrics"');
    expect(html).toContain('data-screen="lyrics-overlay"');
  });

  it("renders nothing extra for feed-detail (FeedScreen owns `enlarged`)", () => {
    const html = render(
      <>{renderShellOverlay("feed-detail", nowPlayingFixtureSnapshot)}</>,
    );
    expect(html).toBe("");
  });
});

describe("commandsToIntentRequests", () => {
  it("maps adjust-volume to a set_volume request", () => {
    expect(
      commandsToIntentRequests([{ type: "adjust-volume", delta: -3 }]),
    ).toEqual([{ name: "set_volume", args: { delta: -3 } }]);
  });

  it("ignores commands with no intent mapping", () => {
    expect(
      commandsToIntentRequests([
        { type: "scroll-feed", delta: 1 },
        { type: "toggle-weather-range" },
      ]),
    ).toEqual([]);
  });
});
