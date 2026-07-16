import { describe, expect, it } from "vitest";
import { render } from "preact-render-to-string";

import { initialShellState } from "./model";
import { ScreenShell } from "./ScreenShell";

describe("ScreenShell", () => {
  it("renders screen layer and optional overlay", () => {
    const withOverlay = {
      ...initialShellState("now-playing"),
      overlay: "lyrics" as const,
    };

    const html = render(
      <ScreenShell
        state={withOverlay}
        renderScreen={(screen) => <div data-test-screen={screen} />}
        renderOverlay={(overlay) => <div data-test-overlay={overlay} />}
      />,
    );

    expect(html).toContain('data-screen="now-playing"');
    expect(html).toContain('data-shell-layer="screen"');
    expect(html).toContain('data-shell-layer="overlay"');
    expect(html).toContain('data-overlay="lyrics"');
    expect(html).toContain('data-test-screen="now-playing"');
    expect(html).toContain('data-test-overlay="lyrics"');
  });

  it("omits overlay layer when null", () => {
    const html = render(
      <ScreenShell
        state={initialShellState("weather")}
        renderScreen={() => <span>wx</span>}
        renderOverlay={() => <span>nope</span>}
      />,
    );

    expect(html).toContain("wx");
    expect(html).not.toContain("data-shell-layer=\"overlay\"");
    expect(html).not.toContain("nope");
  });
});
