import { render } from "preact-render-to-string";
import { describe, expect, it } from "vitest";

import { nowPlayingFixtureSnapshot } from "./fixture";
import { NowPlayingScreen } from "./NowPlayingScreen";

describe("NowPlayingScreen", () => {
  it("renders the 4a TUI layout with display-only queue and volume affordance", () => {
    const html = render(<NowPlayingScreen snapshot={nowPlayingFixtureSnapshot} />);

    expect(html).toContain('data-screen="now-playing"');
    expect(html).toContain('data-viewport="800x480"');
    expect(html).toContain("Galactic");
    expect(html).toContain("Tenure");
    expect(html).toContain("Sink · 2020");
    expect(html).toContain("Last'en");
    expect(html).toContain("+9 more");
    expect(html).toContain('data-queue-mode="display-only"');
    expect(html).toContain('aria-label="Volume 70%"');
    expect(html).toContain("↻ wheel = volume");
    expect(html).toContain("press</strong> lyrics");
    expect(html).toContain("transport: flagged off");
    expect(html).not.toContain("<button");
  });

  it("renders a legible disconnected state without transport controls", () => {
    const html = render(
      <NowPlayingScreen
        snapshot={{
          ...nowPlayingFixtureSnapshot,
          stale: true,
          track: null,
          queue: [],
        }}
      />,
    );

    expect(html).toContain('data-stale="true"');
    expect(html).toContain("Nothing playing");
    expect(html).toContain("spotify:stale");
    expect(html).toContain("queue ends here");
    expect(html).not.toContain("<button");
  });
});
