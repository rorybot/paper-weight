import render from "preact-render-to-string";
import { describe, expect, it } from "vitest";

import { FeedSample } from "./FeedSample";

describe("FeedSample", () => {
  it("renders an 800x480 BERG sample with a selected paper card", () => {
    const html = render(<FeedSample />);

    expect(html).toContain("theme-berg sample-screen");
    expect(html).toContain('data-theme="berg"');
    expect(html).toContain("berg-card--selected");
    expect(html).toContain("read-only snapshot");
  });

  it("switches the same component tree to the gruvbox fallback", () => {
    const html = render(<FeedSample theme="gruvbox" />);

    expect(html).toContain("theme-gruvbox sample-screen");
    expect(html).toContain('data-theme="gruvbox"');
  });
});

