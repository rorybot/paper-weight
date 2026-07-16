import render from "preact-render-to-string";
import { describe, expect, it } from "vitest";

import { Card, joinClassNames } from "./Card";

describe("Card", () => {
  it("renders the signature selected paper recipe", () => {
    const html = render(
      <Card eyebrow="@stoneband · 41m" footer="↪ 11" selected>
        Printed on paper
      </Card>,
    );

    expect(html).toContain("berg-card--paper");
    expect(html).toContain("berg-card--selected");
    expect(html).toContain('data-selected="true"');
    expect(html).toContain("Printed on paper");
  });

  it("composes optional class names without false values", () => {
    expect(joinClassNames("card", false, undefined, "selected")).toBe("card selected");
  });
});

