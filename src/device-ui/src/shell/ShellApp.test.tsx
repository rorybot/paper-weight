import render from "preact-render-to-string";
import { describe, expect, it } from "vitest";

import { nowPlayingFixtureSnapshot } from "../screens/now-playing";
import { commandsToIntentRequests, renderShellOverlay, ShellApp } from "./ShellApp";
import type { ScreenId } from "./model";

const REAL_SCREEN_MARKERS: Readonly<Record<ScreenId, string>> = {
  home: 'data-screen="home"',
  "now-playing": 'data-screen="now-playing"',
  weather: 'data-screen="weather"',
  playlist: 'data-screen="playlist"',
  photo: 'data-screen="photo"',
  etymology: 'data-screen="etymology"',
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
});

describe("renderShellOverlay", () => {
  it("renders the real lyrics overlay from the now-playing snapshot", () => {
    const html = render(
      <>{renderShellOverlay("lyrics", nowPlayingFixtureSnapshot)}</>,
    );
    expect(html).toContain('data-overlay="lyrics"');
    expect(html).toContain('data-screen="lyrics-overlay"');
  });
});

describe("commandsToIntentRequests", () => {
  it("ignores commands with no intent mapping", () => {
    expect(
      commandsToIntentRequests([
        { type: "skip-photo", delta: 1 },
        { type: "toggle-weather-range" },
      ]),
    ).toEqual([]);
  });
});
