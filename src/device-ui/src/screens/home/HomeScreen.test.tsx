import render from "preact-render-to-string";
import { describe, expect, it } from "vitest";

import { homeFixtureGlance } from "./fixture";
import { HomeScreen } from "./HomeScreen";

describe("HomeScreen", () => {
  it("renders the 800×480 fixture layout with all four tiles", () => {
    const html = render(<HomeScreen glance={homeFixtureGlance} theme="gruvbox" />);

    expect(html).toContain('data-screen="home"');
    expect(html).toContain('data-theme="gruvbox"');
    expect(html).toMatch(/800px/);
    expect(html).toMatch(/480px/);

    // preset badges match the shell's PRESET_SCREENS mapping (1:np 2:wx 3:ph 4:et)
    expect(html).toContain("1:np");
    expect(html).toContain("2:wx");
    expect(html).toContain("3:ph");
    expect(html).toContain("4:et");

    expect(html).toContain("now playing");
    expect(html).toContain("sundara");
    expect(html).toContain("alina baraz");

    expect(html).toContain("weather");
    expect(html).toContain("72");
    expect(html).toContain("clear");

    expect(html).toContain("etymology");
    // HTML escapes → as &#8594;
    expect(html).toContain("travailler");
    expect(html).toContain("trepālium");
    expect(html).toContain("depth 2/3");

    expect(html).toContain("photo");
    expect(html).toContain('<p class="hm-hero-num">3<small>/48</small></p>');
  });

  it("falls back gracefully when a tile has no data", () => {
    const html = render(
      <HomeScreen
        glance={{
          ...homeFixtureGlance,
          nowPlaying: null,
          photo: null,
        }}
        theme="gruvbox"
      />,
    );

    expect(html).toContain("nothing playing");
    // photo's "no data" fallback, not its normal counter
    expect(html).not.toContain("3/48");
  });

  it("no play/pause/skip/previous affordances appear anywhere on the screen", () => {
    const html = render(<HomeScreen glance={homeFixtureGlance} theme="gruvbox" />);

    expect(html.toLowerCase()).not.toContain("play/pause");
    expect(html.toLowerCase()).not.toMatch(/\bpause\b/);
    expect(html.toLowerCase()).not.toMatch(/\bskip\b/);
  });
});
