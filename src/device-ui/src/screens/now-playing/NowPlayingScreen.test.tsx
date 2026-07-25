import { render } from "preact-render-to-string";
import { describe, expect, it } from "vitest";

import { nowPlayingFixtureSnapshot } from "./fixture";
import { NowPlayingScreen } from "./NowPlayingScreen";

describe("NowPlayingScreen", () => {
  it("renders an interactive four-row queue with selection guidance", () => {
    const html = render(<NowPlayingScreen snapshot={nowPlayingFixtureSnapshot} />);

    expect(html).toContain('data-screen="now-playing"');
    expect(html).toContain('data-viewport="800x480"');
    expect(html).toContain("3:ph");
    expect(html).toContain("Galactic");
    expect(html).toContain("Tenure");
    expect(html).toContain("Sink · 2020");
    expect(html).toContain("Last'en");
    expect(html).toContain("+9 more");
    expect(html).toContain('data-queue-mode="interactive"');
    expect(html).toContain('role="listbox"');
    expect(html).toContain('role="option"');
    expect(html).toContain('aria-selected="true"');
    expect(html).toContain('aria-activedescendant="np-queue-item-');
    expect(html).toContain("wheel: select queue");
    expect(html).toContain("press: play");
    expect(html).toContain("long press:</strong> lyrics");
    expect(html).toContain("transport: flagged off");
    expect(html).not.toContain("display-only");
    expect(html).not.toContain("wheel = volume");
    expect(html).not.toContain('aria-label="Volume 70%"');
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
    expect(html).toContain("0 / 0");
    expect(html).not.toContain("<button");
  });

  it("moves the selected row and sliding window with controlled queue state", () => {
    const html = render(
      <NowPlayingScreen
        snapshot={nowPlayingFixtureSnapshot}
        command={null}
      />,
    );
    expect(html).toContain('data-queue-index="0"');
    expect(html).toContain('data-queue-index="3"');
    expect(html).not.toContain('data-queue-index="4"');

    const movedHtml = render(
      <NowPlayingScreen
        snapshot={nowPlayingFixtureSnapshot}
        ui={{ selectedIndex: 6 }}
      />,
    );
    expect(movedHtml).toContain('data-queue-index="4"');
    expect(movedHtml).toContain('data-queue-index="7"');
    expect(movedHtml).not.toContain('data-queue-index="3"');
    expect(movedHtml).toContain(
      `id="np-queue-item-${nowPlayingFixtureSnapshot.queue[6]?.id}" role="option" aria-selected="true"`,
    );
  });
});
